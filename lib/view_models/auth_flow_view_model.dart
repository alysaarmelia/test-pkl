import 'package:get/get.dart';

import '../repositories/auth_flow_repository.dart';

class AuthFlowViewModel extends GetxController {
  AuthFlowViewModel({AuthFlowRepository? repository})
    : _repository = repository ?? AuthFlowRepositoryImpl();

  final AuthFlowRepository _repository;

  bool get hasCurrentUser => _repository.hasCurrentUser;

  Future<bool> shouldAutoLogin() {
    return _repository.shouldAutoLogin();
  }

  Future<String> resolveFriendlyName() {
    return _repository.resolveFriendlyName();
  }
}
