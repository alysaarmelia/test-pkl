import '../shared/models/attendance_window.dart';
import '../shared/services/attendance_window_repository.dart';

abstract class AttendanceWindowPageRepository {
  Stream<AttendanceWindow?> watchWindow(DateTime date);
}

class AttendanceWindowPageRepositoryImpl
    implements AttendanceWindowPageRepository {
  AttendanceWindowPageRepositoryImpl({AttendanceWindowRepository? repository})
    : _repository = repository ?? AttendanceWindowRepository();

  final AttendanceWindowRepository _repository;

  @override
  Stream<AttendanceWindow?> watchWindow(DateTime date) {
    return _repository.watchWindow(date);
  }
}
