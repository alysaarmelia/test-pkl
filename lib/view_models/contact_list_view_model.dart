import 'package:get/get.dart';

import '../repositories/contact_list_repository.dart';

enum ContactListFeedbackType { success, info, warning, error, none }

class ContactListFeedback {
  const ContactListFeedback({required this.type, this.message = ''});

  final ContactListFeedbackType type;
  final String message;

  static const none = ContactListFeedback(type: ContactListFeedbackType.none);
}

class ContactListDmResult {
  const ContactListDmResult({
    this.chatId,
    this.feedback = ContactListFeedback.none,
  });

  final String? chatId;
  final ContactListFeedback feedback;
}

class ContactListViewModel extends GetxController {
  ContactListViewModel({ContactListRepository? repository})
    : _repository = repository ?? ContactListRepositoryImpl();

  final ContactListRepository _repository;

  String get currentUserUid => _repository.currentUserUid;
  String? get currentUserDisplayName => _repository.currentUserDisplayName;
  String? get currentUserPhotoUrl => _repository.currentUserPhotoUrl;

  Stream<ContactListUserProfile?> watchCurrentUserProfile({
    required String uid,
  }) {
    return _repository.watchCurrentUserProfile(uid: uid);
  }

  Stream<List<ContactListContact>> watchContacts({required String uid}) {
    return _repository.watchContacts(uid: uid);
  }

  Future<ContactListUserProfile> fetchUserProfile(
    String uid, {
    String collection = 'users',
  }) {
    return _repository.fetchUserProfile(uid, collection: collection);
  }

  String normalizePin(String input) {
    return input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  List<ContactListContact> filterContacts({
    required List<ContactListContact> contacts,
    required String query,
  }) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return contacts;
    return contacts
        .where((contact) {
          final name = contact.displayName.toLowerCase();
          final pin = contact.pin.toLowerCase();
          return name.contains(normalized) || pin.contains(normalized);
        })
        .toList(growable: false);
  }

  Future<ContactListFeedback> addContactByPin({
    required String pin,
    String alias = '',
  }) async {
    final myUid = currentUserUid;
    if (myUid.isEmpty) {
      return const ContactListFeedback(
        type: ContactListFeedbackType.warning,
        message: 'Harus login terlebih dahulu',
      );
    }

    final result = await _repository.addContactByPin(
      myUid: myUid,
      pin: pin,
      alias: alias,
    );
    switch (result.status) {
      case ContactListAddContactStatus.success:
        return ContactListFeedback(
          type: ContactListFeedbackType.success,
          message: result.message ?? 'Kontak ditambahkan',
        );
      case ContactListAddContactStatus.invalidPin:
      case ContactListAddContactStatus.notFound:
      case ContactListAddContactStatus.self:
      case ContactListAddContactStatus.invalidPeerData:
        return ContactListFeedback(
          type: ContactListFeedbackType.warning,
          message: result.message ?? 'Kontak tidak dapat ditambahkan',
        );
      case ContactListAddContactStatus.failure:
        return ContactListFeedback(
          type: ContactListFeedbackType.error,
          message: result.message ?? 'Gagal menambah kontak',
        );
    }
  }

  Future<ContactListFeedback> updateContactAlias({
    required String peerUid,
    required String alias,
  }) async {
    final myUid = currentUserUid;
    if (myUid.isEmpty) {
      return const ContactListFeedback(
        type: ContactListFeedbackType.warning,
        message: 'Harus login terlebih dahulu',
      );
    }
    try {
      await _repository.updateContactAlias(
        myUid: myUid,
        peerUid: peerUid,
        alias: alias,
      );
      return const ContactListFeedback(
        type: ContactListFeedbackType.success,
        message: 'Nama disimpan',
      );
    } catch (e) {
      return ContactListFeedback(
        type: ContactListFeedbackType.error,
        message: 'Gagal menyimpan: $e',
      );
    }
  }

  Future<ContactListFeedback> deleteContact({required String peerUid}) async {
    final myUid = currentUserUid;
    if (myUid.isEmpty) {
      return const ContactListFeedback(
        type: ContactListFeedbackType.warning,
        message: 'Harus login terlebih dahulu',
      );
    }
    try {
      await _repository.deleteContact(myUid: myUid, peerUid: peerUid);
      return const ContactListFeedback(
        type: ContactListFeedbackType.success,
        message: 'Kontak dihapus',
      );
    } catch (e) {
      return ContactListFeedback(
        type: ContactListFeedbackType.error,
        message: 'Gagal menghapus: $e',
      );
    }
  }

  Future<ContactListFeedback> addMemberToGroup({
    required String chatId,
    required String peerUid,
    required String displayName,
    required String alias,
    required String pin,
    required String avatarUrl,
  }) async {
    final myUid = currentUserUid;
    if (myUid.isEmpty) {
      return const ContactListFeedback(
        type: ContactListFeedbackType.warning,
        message: 'Harus login terlebih dahulu',
      );
    }
    final result = await _repository.addMemberToGroup(
      chatId: chatId,
      myUid: myUid,
      peerUid: peerUid,
      displayName: displayName,
      alias: alias,
      pin: pin,
      avatarUrl: avatarUrl,
    );
    switch (result.status) {
      case ContactListAddMemberStatus.added:
        return ContactListFeedback(
          type: ContactListFeedbackType.success,
          message: '${result.resolvedName ?? displayName} ditambahkan ke grup',
        );
      case ContactListAddMemberStatus.alreadyMember:
        return ContactListFeedback(
          type: ContactListFeedbackType.info,
          message: result.message ?? 'Pengguna sudah tergabung dalam grup',
        );
      case ContactListAddMemberStatus.groupNotFound:
        return ContactListFeedback(
          type: ContactListFeedbackType.warning,
          message: result.message ?? 'Grup tidak ditemukan',
        );
      case ContactListAddMemberStatus.failure:
        return ContactListFeedback(
          type: ContactListFeedbackType.error,
          message: result.message ?? 'Gagal menambah anggota',
        );
    }
  }

  Future<ContactListDmResult> ensureDmChat({
    required String peerUid,
    String? peerName,
    String? peerAvatarUrl,
    String? peerPin,
    String? myName,
    String? myAvatarUrl,
    String? myPin,
  }) async {
    final myUid = currentUserUid;
    if (myUid.isEmpty || peerUid.isEmpty) {
      return const ContactListDmResult(
        feedback: ContactListFeedback(
          type: ContactListFeedbackType.warning,
          message: 'Pengguna tidak valid untuk memulai chat',
        ),
      );
    }
    try {
      final chatId = await _repository.ensureDmChat(
        myUid: myUid,
        peerUid: peerUid,
        peerName: peerName,
        peerAvatarUrl: peerAvatarUrl,
        peerPin: peerPin,
        myName: myName,
        myAvatarUrl: myAvatarUrl,
        myPin: myPin,
      );
      if (chatId == null || chatId.isEmpty) {
        return const ContactListDmResult(
          feedback: ContactListFeedback(
            type: ContactListFeedbackType.error,
            message: 'Gagal membuat chat',
          ),
        );
      }
      return ContactListDmResult(chatId: chatId);
    } catch (e) {
      return ContactListDmResult(
        feedback: ContactListFeedback(
          type: ContactListFeedbackType.error,
          message: 'Gagal membuat chat: $e',
        ),
      );
    }
  }
}
