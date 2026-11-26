import 'package:get/get.dart';

import '../shared/models/material_request.dart';
import '../repositories/material_request_page_repository.dart';

enum MaterialRequestFeedbackType { success, warning, error, none }

class MaterialRequestFeedback {
  const MaterialRequestFeedback({
    required this.type,
    this.message = '',
    this.shouldClosePage = false,
  });

  final MaterialRequestFeedbackType type;
  final String message;
  final bool shouldClosePage;

  static const none = MaterialRequestFeedback(
    type: MaterialRequestFeedbackType.none,
  );
}

class MaterialRequestItemInput {
  const MaterialRequestItemInput({required this.name, required this.quantity});

  final String name;
  final String quantity;
}

class MaterialRequestPageViewModel extends GetxController {
  MaterialRequestPageViewModel({MaterialRequestPageRepository? repository})
    : _repository = repository ?? MaterialRequestPageRepositoryImpl();

  static const String manualCompanyLabel = 'another company';
  static const List<String> companyOptions = [
    'Pt. Cipta vera mandiri',
    'Pt. Luthfiatama jaya mandiri kontruksi',
    'Pt. Jaya Mandiri adikarya',
    'CV. Kindai Artha jaya',
    'Cv. Indaru jaya mandiri',
  ];

  final MaterialRequestPageRepository _repository;

  final Rxn<DateTime> requestDate = Rxn<DateTime>();
  final RxBool isSubmitting = false.obs;
  final RxString requesterName = ''.obs;
  final RxString selectedCompany = ''.obs;

  List<String> get companyOptionsWithManual =>
      List<String>.from(companyOptions)..add(manualCompanyLabel);

  bool get isManualCompany => selectedCompany.value == manualCompanyLabel;

  @override
  void onInit() {
    super.onInit();
    requestDate.value = DateTime.now();
    selectedCompany.value = companyOptions.first;
    _loadRequesterName();
  }

  void selectCompany(String value) {
    selectedCompany.value = value;
  }

  void resetCompanyToDefault() {
    selectedCompany.value = companyOptions.first;
  }

  void setRequestDate(DateTime value) {
    requestDate.value = value;
  }

  Future<MaterialRequestFeedback> submit({
    required String companyName,
    required String projectName,
    required String requester,
    required DateTime? date,
    required List<MaterialRequestItemInput> inputs,
  }) async {
    if (isSubmitting.value) return MaterialRequestFeedback.none;

    final selectedDate = date;
    if (selectedDate == null) {
      return const MaterialRequestFeedback(
        type: MaterialRequestFeedbackType.warning,
        message: 'Silakan pilih tanggal permintaan.',
      );
    }

    final requesterUid = _repository.currentUserUid;
    if (requesterUid == null || requesterUid.isEmpty) {
      return const MaterialRequestFeedback(
        type: MaterialRequestFeedbackType.error,
        message: 'Sesi berakhir, silakan masuk kembali.',
      );
    }

    final items = <MaterialRequestItem>[];
    for (final input in inputs) {
      final name = input.name.trim();
      final quantity = input.quantity.trim();
      if (name.isEmpty && quantity.isEmpty) {
        continue;
      }
      if (name.isEmpty || quantity.isEmpty) {
        return const MaterialRequestFeedback(
          type: MaterialRequestFeedbackType.warning,
          message: 'Lengkapi nama dan jumlah untuk setiap material.',
        );
      }

      items.add(
        MaterialRequestItem(
          no: items.length + 1,
          name: name,
          quantity: quantity,
          status: MaterialRequestItemStatus.pending,
        ),
      );
    }

    if (items.isEmpty) {
      return const MaterialRequestFeedback(
        type: MaterialRequestFeedbackType.warning,
        message: 'Tambah minimal satu item material.',
      );
    }

    final draft = MaterialRequestDraft(
      companyName: companyName.trim(),
      projectName: projectName.trim(),
      requestDate: selectedDate,
      requesterName: requester.trim(),
      requesterUid: requesterUid,
      approverName: null,
      items: items,
    );

    isSubmitting.value = true;
    try {
      await _repository.submitDraft(draft);
      return const MaterialRequestFeedback(
        type: MaterialRequestFeedbackType.success,
        message: 'Permintaan material berhasil dikirim.',
        shouldClosePage: true,
      );
    } catch (error) {
      return MaterialRequestFeedback(
        type: MaterialRequestFeedbackType.error,
        message: 'Gagal mengirim permintaan: $error',
      );
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> _loadRequesterName() async {
    final resolved = await _repository.resolveRequesterName();
    requesterName.value = resolved;
  }
}
