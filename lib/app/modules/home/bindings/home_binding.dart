import 'package:get/get.dart';
import 'package:cipta_vera_mandiri_digital/repositories/home_calendar_repository.dart';
import 'package:cipta_vera_mandiri_digital/repositories/home_controller_repository.dart';

import '../controllers/home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeCalendarRepository>(
      () => HomeCalendarRepositoryImpl(),
      fenix: true,
    );
    Get.lazyPut<HomeControllerRepository>(
      () => HomeControllerRepositoryImpl(),
      fenix: true,
    );
    Get.put(
      HomeController(
        homeCalendarRepository: Get.find<HomeCalendarRepository>(),
        homeControllerRepository: Get.find<HomeControllerRepository>(),
      ),
      permanent: true,
    );
  }
}
