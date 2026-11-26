import 'dart:async';

import 'package:get/get.dart';

import '../repositories/menu_grid_repository.dart';

class MenuGridAccessState {
  const MenuGridAccessState({
    required this.role,
    required this.isSuperAdmin,
    required this.canAccessMaterial,
    required this.canAccessPemberkasan,
  });

  const MenuGridAccessState.initial()
    : role = '',
      isSuperAdmin = false,
      canAccessMaterial = false,
      canAccessPemberkasan = false;

  final String role;
  final bool isSuperAdmin;
  final bool canAccessMaterial;
  final bool canAccessPemberkasan;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MenuGridAccessState &&
        other.role == role &&
        other.isSuperAdmin == isSuperAdmin &&
        other.canAccessMaterial == canAccessMaterial &&
        other.canAccessPemberkasan == canAccessPemberkasan;
  }

  @override
  int get hashCode {
    return Object.hash(
      role,
      isSuperAdmin,
      canAccessMaterial,
      canAccessPemberkasan,
    );
  }
}

class MenuGridViewModel extends GetxController {
  MenuGridViewModel({MenuGridRepository? repository})
    : _repository = repository ?? MenuGridRepositoryImpl();

  static const Set<String> materialRoles = <String>{
    'purchasing and logistik',
    'project officer',
    'head officer',
  };

  static const Set<String> pemberkasanRoles = <String>{
    'administrations',
    'finance',
    'heavy equipment',
  };

  static const String allowedMaterialLabel =
      'Super Admin, Purchasing and Logistik, Project Officer, Head Officer';
  static const String allowedPemberkasanLabel =
      'Super Admin, Administrations, Finance, atau Heavy Equipment';

  final MenuGridRepository _repository;
  final StreamController<MenuGridAccessState> _stateController =
      StreamController<MenuGridAccessState>.broadcast();

  StreamSubscription<String?>? _authSubscription;
  StreamSubscription<Map<String, dynamic>?>? _profileSubscription;
  MenuGridAccessState _state = const MenuGridAccessState.initial();

  Stream<MenuGridAccessState> get stateStream => _stateController.stream;
  MenuGridAccessState get state => _state;

  @override
  void onInit() {
    super.onInit();
    _bindAuthState(_repository.currentUserUid);
    _authSubscription = _repository.watchAuthUserIds().listen(_bindAuthState);
  }

  @override
  void onClose() {
    unawaited(_profileSubscription?.cancel() ?? Future<void>.value());
    unawaited(_authSubscription?.cancel() ?? Future<void>.value());
    _profileSubscription = null;
    _authSubscription = null;
    if (!_stateController.isClosed) {
      unawaited(_stateController.close());
    }
    super.onClose();
  }

  void _bindAuthState(String? uid) {
    _profileSubscription?.cancel();
    final normalizedUid = uid?.trim() ?? '';
    if (normalizedUid.isEmpty) {
      _emit(const MenuGridAccessState.initial());
      return;
    }

    _profileSubscription = _repository
        .watchUserProfile(normalizedUid)
        .listen(
          (data) {
            _emit(_toState(data));
          },
          onError: (_) {
            _emit(const MenuGridAccessState.initial());
          },
        );
  }

  MenuGridAccessState _toState(Map<String, dynamic>? data) {
    final role = _extractRole(data);
    final isSuperAdmin = _isSuperAdmin(data);
    final normalizedRole = role.toLowerCase();
    return MenuGridAccessState(
      role: role,
      isSuperAdmin: isSuperAdmin,
      canAccessMaterial: isSuperAdmin || materialRoles.contains(normalizedRole),
      canAccessPemberkasan:
          isSuperAdmin || pemberkasanRoles.contains(normalizedRole),
    );
  }

  void _emit(MenuGridAccessState next) {
    if (_state == next) return;
    _state = next;
    if (_stateController.isClosed) return;
    _stateController.add(_state);
  }

  String _extractRole(Map<String, dynamic>? data) {
    if (data == null) return '';
    for (final key in const ['role', 'team', 'department', 'division']) {
      final value = data[key];
      if (value is String) {
        final normalized = value.trim();
        if (normalized.isNotEmpty) return normalized;
      }
    }
    return '';
  }

  bool _isSuperAdmin(Map<String, dynamic>? data) {
    if (data == null) return false;
    final roles = data['roles'];
    if (roles is Map<String, dynamic>) {
      if (roles['superAdmin'] == true || roles['admin'] == true) {
        return true;
      }
    }
    final roleValue = data['role'];
    if (roleValue is String &&
        roleValue.trim().toLowerCase() == 'super admin') {
      return true;
    }
    return false;
  }
}
