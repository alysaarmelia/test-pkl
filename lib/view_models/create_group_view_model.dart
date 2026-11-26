import 'dart:async';

import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../repositories/create_group_repository.dart';

enum CreateGroupFeedbackType { success, info, warning, error, none }

class CreateGroupFeedback {
  const CreateGroupFeedback({required this.type, this.message = ''});

  final CreateGroupFeedbackType type;
  final String message;

  static const none = CreateGroupFeedback(type: CreateGroupFeedbackType.none);
}

class CreateGroupSubmitResult {
  const CreateGroupSubmitResult({
    required this.feedback,
    this.chatId,
    this.groupName,
  });

  final CreateGroupFeedback feedback;
  final String? chatId;
  final String? groupName;

  bool get shouldOpenChat => chatId != null && chatId!.isNotEmpty;

  static const none = CreateGroupSubmitResult(
    feedback: CreateGroupFeedback.none,
  );
}

class CreateGroupViewModel extends GetxController {
  CreateGroupViewModel({
    CreateGroupRepository? repository,
    ImagePicker? imagePicker,
  }) : _repository = repository ?? CreateGroupRepositoryImpl(),
       _imagePicker = imagePicker ?? ImagePicker();

  final CreateGroupRepository _repository;
  final ImagePicker _imagePicker;

  StreamSubscription<String?>? _authSubscription;

  Stream<List<CreateGroupContact>>? _contactsStream;
  bool _creating = false;
  String _searchQuery = '';
  String? _pickedImagePath;
  Map<String, CreateGroupSelectedMember> _selectedMembers =
      <String, CreateGroupSelectedMember>{};
  CreateGroupMyProfile? _myProfile;

  Stream<List<CreateGroupContact>>? get contactsStream => _contactsStream;
  bool get creating => _creating;
  String get searchQuery => _searchQuery;
  String? get pickedImagePath => _pickedImagePath;
  String? get currentUserUid => _repository.currentUserUid;
  CreateGroupMyProfile? get myProfile => _myProfile;
  Map<String, CreateGroupSelectedMember> get selectedMembers =>
      _selectedMembers;

  @override
  void onInit() {
    super.onInit();
    _handleAuthChanged(_repository.currentUserUid);
    _authSubscription = _repository.watchAuthUserIds().listen(
      _handleAuthChanged,
    );
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    super.onClose();
  }

  void setSearchQuery(String value) {
    if (_searchQuery == value) return;
    _searchQuery = value;
    _notify();
  }

  List<CreateGroupContact> buildFilteredContacts(
    List<CreateGroupContact> contacts,
  ) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return contacts;
    return contacts.where((contact) => contact.matches(query)).toList();
  }

  bool isSelected(String uid) {
    return _selectedMembers.containsKey(uid);
  }

  void removeSelectedMember(String uid) {
    if (_selectedMembers.containsKey(uid)) {
      _selectedMembers = Map<String, CreateGroupSelectedMember>.from(
        _selectedMembers,
      )..remove(uid);
      _notify();
    }
  }

  Future<CreateGroupFeedback> pickImageFromGallery() async {
    if (_creating) return CreateGroupFeedback.none;
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file == null) return CreateGroupFeedback.none;
      _pickedImagePath = file.path;
      _notify();
      return CreateGroupFeedback.none;
    } catch (error) {
      return CreateGroupFeedback(
        type: CreateGroupFeedbackType.error,
        message: 'Gagal mengambil foto: $error',
      );
    }
  }

  Future<CreateGroupFeedback> toggleMember(CreateGroupContact contact) async {
    if (_creating) return CreateGroupFeedback.none;
    final uid = contact.uid;
    if (uid.isEmpty) return CreateGroupFeedback.none;
    final myUid = _repository.currentUserUid;
    if (myUid == null || myUid.isEmpty || uid == myUid) {
      return CreateGroupFeedback.none;
    }

    if (_selectedMembers.containsKey(uid)) {
      _selectedMembers = Map<String, CreateGroupSelectedMember>.from(
        _selectedMembers,
      )..remove(uid);
      _notify();
      return CreateGroupFeedback.none;
    }

    try {
      final member = await _repository.resolveSelectedMember(contact);
      if (member == null) {
        return const CreateGroupFeedback(
          type: CreateGroupFeedbackType.error,
          message: 'Gagal mengambil data anggota',
        );
      }

      final updated = Map<String, CreateGroupSelectedMember>.from(
        _selectedMembers,
      );
      updated[uid] = member;
      _selectedMembers = updated;
      _notify();
      return CreateGroupFeedback.none;
    } catch (error) {
      return CreateGroupFeedback(
        type: CreateGroupFeedbackType.error,
        message: 'Gagal mengambil data anggota: $error',
      );
    }
  }

  Future<CreateGroupSubmitResult> createGroup({
    required String groupName,
    required String groupDescription,
  }) async {
    if (_creating) return CreateGroupSubmitResult.none;

    final name = groupName.trim();
    final description = groupDescription.trim();
    if (name.length < 3) {
      return const CreateGroupSubmitResult(
        feedback: CreateGroupFeedback(
          type: CreateGroupFeedbackType.warning,
          message: 'Nama grup minimal 3 karakter',
        ),
      );
    }

    if (_selectedMembers.isEmpty) {
      return const CreateGroupSubmitResult(
        feedback: CreateGroupFeedback(
          type: CreateGroupFeedbackType.warning,
          message: 'Pilih minimal 1 anggota, akan digabung dengan PIN Anda',
        ),
      );
    }

    final uid = _repository.currentUserUid;
    if (uid == null || uid.isEmpty) {
      return const CreateGroupSubmitResult(
        feedback: CreateGroupFeedback(
          type: CreateGroupFeedbackType.warning,
          message: 'Harus login untuk membuat grup',
        ),
      );
    }

    _creating = true;
    _notify();
    try {
      final response = await _repository.createGroup(
        groupName: name,
        groupDescription: description,
        selectedMembers: _selectedMembers,
        imagePath: _pickedImagePath,
      );

      final warning = response.avatarUploadWarning;
      final feedback = warning == null || warning.trim().isEmpty
          ? CreateGroupFeedback.none
          : CreateGroupFeedback(
              type: CreateGroupFeedbackType.warning,
              message: warning,
            );

      return CreateGroupSubmitResult(
        feedback: feedback,
        chatId: response.chatId,
        groupName: response.groupName,
      );
    } catch (error) {
      return CreateGroupSubmitResult(
        feedback: CreateGroupFeedback(
          type: CreateGroupFeedbackType.error,
          message: 'Gagal membuat grup: $error',
        ),
      );
    } finally {
      _creating = false;
      _notify();
    }
  }

  void _handleAuthChanged(String? uid) {
    if (uid == null || uid.isEmpty) {
      _contactsStream = null;
      _myProfile = null;
      _selectedMembers = <String, CreateGroupSelectedMember>{};
      _pickedImagePath = null;
      _notify();
      return;
    }

    _contactsStream = _repository.watchContacts(uid);
    _myProfile = null;
    _selectedMembers = <String, CreateGroupSelectedMember>{};
    _notify();
    unawaited(_loadMyProfile(uid));
  }

  Future<void> _loadMyProfile(String uid) async {
    try {
      final profile = await _repository.fetchMyProfile(uid);
      if (profile == null) return;
      _myProfile = profile;
      _notify();
    } catch (_) {
      // Keep UI functional when profile fails to load.
    }
  }

  void _notify() {
    if (isClosed) return;
    update();
  }
}
