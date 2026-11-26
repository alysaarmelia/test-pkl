import 'package:get/get.dart';
import 'package:cipta_vera_mandiri_digital/repositories/auth_credentials_repository.dart';
import 'package:cipta_vera_mandiri_digital/view_models/auth_credentials_view_model.dart';

import '../controllers/login_controller.dart';

class LoginBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AuthCredentialsRepository>(
      () => AuthCredentialsRepositoryImpl(),
      fenix: true,
    );
    Get.lazyPut<AuthCredentialsViewModel>(
      () => AuthCredentialsViewModel(
        repository: Get.find<AuthCredentialsRepository>(),
      ),
      fenix: true,
    );
    Get.lazyPut<LoginController>(
      () => LoginController(viewModel: Get.find<AuthCredentialsViewModel>()),
    );
  }
}
