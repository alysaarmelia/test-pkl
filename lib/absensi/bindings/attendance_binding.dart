import 'package:cipta_vera_mandiri_digital/absensi/controllers/attendance_controller.dart';
import 'package:cipta_vera_mandiri_digital/absensi/services/attendance_camera_service.dart';
import 'package:cipta_vera_mandiri_digital/absensi/services/attendance_face_verification_service.dart';
import 'package:cipta_vera_mandiri_digital/view_models/attendance_view_model.dart';
import 'package:get/get.dart';

class AttendanceBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AttendanceViewModel>(() => AttendanceViewModel());
    Get.lazyPut<AttendanceController>(
      () => AttendanceController(viewModel: Get.find<AttendanceViewModel>()),
    );
    Get.lazyPut<AttendanceCameraService>(() => AttendanceCameraService());
    Get.lazyPut<AttendanceFaceVerificationService>(
      () => AttendanceFaceVerificationService(),
    );
  }
}
