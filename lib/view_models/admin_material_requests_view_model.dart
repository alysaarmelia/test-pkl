import 'package:get/get.dart';

import '../shared/models/material_request.dart';
import '../repositories/admin_material_requests_repository.dart';

enum AdminMaterialFeedbackType { success, warning, error, none }

class AdminMaterialFeedback {
  const AdminMaterialFeedback({required this.type, this.message = ''});

  final AdminMaterialFeedbackType type;
  final String message;

  static const none = AdminMaterialFeedback(
    type: AdminMaterialFeedbackType.none,
  );
}

class AdminMaterialCompanyFilterOption {
  const AdminMaterialCompanyFilterOption({
    required this.label,
    this.aliases = const <String>[],
    this.matchesAll = false,
  });

  final String label;
  final List<String> aliases;
  final bool matchesAll;

  bool matches(String companyName) {
    if (matchesAll) return true;
    final normalizedCompany = _normalizeCompanyKey(companyName);
    final candidates = <String>{
      _normalizeCompanyKey(label),
      ...aliases.map(_normalizeCompanyKey),
    }..removeWhere((value) => value.isEmpty);
    return candidates.contains(normalizedCompany);
  }
}

class AdminMaterialRequestSections {
  const AdminMaterialRequestSections({
    required this.filteredRequests,
    required this.pendingRequests,
    required this.approvedRequests,
    required this.deliveredRequests,
    required this.activeRequests,
    required this.historyRequests,
  });

  final List<MaterialRequest> filteredRequests;
  final List<MaterialRequest> pendingRequests;
  final List<MaterialRequest> approvedRequests;
  final List<MaterialRequest> deliveredRequests;
  final List<MaterialRequest> activeRequests;
  final List<MaterialRequest> historyRequests;
}

class AdminMaterialRequestsViewModel extends GetxController {
  AdminMaterialRequestsViewModel({AdminMaterialRequestsRepository? repository})
    : _repository = repository ?? AdminMaterialRequestsRepositoryImpl();

  static const String allCompaniesLabel = 'Semua perusahaan';
  static const String anotherCompanyLabel = 'Another company';
  static const List<AdminMaterialCompanyFilterOption> companyFilters = [
    AdminMaterialCompanyFilterOption(
      label: allCompaniesLabel,
      matchesAll: true,
    ),
    AdminMaterialCompanyFilterOption(label: 'Pt. Cipta vera mandiri'),
    AdminMaterialCompanyFilterOption(
      label: 'Pt. Luthfiatama jaya mandiri kontruksi',
      aliases: ['Pt. Luthfiatama jaya mandiri'],
    ),
    AdminMaterialCompanyFilterOption(label: 'Pt. Jaya Mandiri adikarya'),
    AdminMaterialCompanyFilterOption(label: 'CV. Kindai Artha jaya'),
    AdminMaterialCompanyFilterOption(label: 'Cv. Indaru jaya mandiri'),
    AdminMaterialCompanyFilterOption(label: anotherCompanyLabel),
  ];

  final AdminMaterialRequestsRepository _repository;

  final RxString selectedCompanyFilter = allCompaniesLabel.obs;
  final Rxn<DateTime> selectedDateFilter = Rxn<DateTime>();

  final RxMap<String, bool> _processingByRequest = <String, bool>{}.obs;
  final RxMap<String, bool> _processingByItemKey = <String, bool>{}.obs;
  final RxMap<String, String> _userNames = <String, String>{}.obs;
  final Set<String> _lookupInFlight = <String>{};

  @override
  void onInit() {
    super.onInit();
    selectedDateFilter.value = today();
  }

  Stream<List<MaterialRequest>> watchRequests({int limit = 200}) {
    return _repository.watchRequests(limit: limit);
  }

  void setCompanyFilter(String value) {
    if (value == selectedCompanyFilter.value) return;
    selectedCompanyFilter.value = value;
  }

  void clearDateFilter() {
    selectedDateFilter.value = null;
  }

  void setDateFilter(DateTime value) {
    selectedDateFilter.value = normalizeDate(value);
  }

  DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String formatFilterDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final monthLabel = months[(local.month - 1).clamp(0, months.length - 1)];
    final year = local.year.toString();
    return '$day $monthLabel $year';
  }

  String activeFilterLabel() {
    final labels = <String>[];
    if (selectedCompanyFilter.value != allCompaniesLabel) {
      labels.add(selectedCompanyFilter.value);
    }
    final date = selectedDateFilter.value;
    if (date != null) {
      labels.add(formatFilterDate(date));
    }
    if (labels.isEmpty) {
      return 'filter ini';
    }
    return labels.join(' • ');
  }

  AdminMaterialRequestSections buildSections(List<MaterialRequest> requests) {
    final filteredRequests = _applyDateFilter(_applyCompanyFilter(requests));

    final pendingRequests = filteredRequests
        .where((r) => r.status == MaterialRequestStatus.pending)
        .toList(growable: false);
    final approvedRequests = filteredRequests
        .where((r) => r.status == MaterialRequestStatus.approved)
        .toList(growable: false);
    final deliveredRequests = filteredRequests
        .where((r) => r.status == MaterialRequestStatus.delivered)
        .toList(growable: false);

    final activeRequests = [...pendingRequests, ...approvedRequests];
    activeRequests.sort((a, b) {
      const rank = {
        MaterialRequestStatus.pending: 0,
        MaterialRequestStatus.approved: 1,
      };
      final diff = (rank[a.status] ?? 99) - (rank[b.status] ?? 99);
      if (diff != 0) return diff;
      return b.createdAt.compareTo(a.createdAt);
    });

    final historyRequests = [...deliveredRequests]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return AdminMaterialRequestSections(
      filteredRequests: filteredRequests,
      pendingRequests: pendingRequests,
      approvedRequests: approvedRequests,
      deliveredRequests: deliveredRequests,
      activeRequests: activeRequests,
      historyRequests: historyRequests,
    );
  }

  bool isProcessing(String requestId) {
    return _processingByRequest[requestId] == true;
  }

  Set<int> processingItemNos(String requestId) {
    return _processingByItemKey.entries
        .where((entry) => entry.value && entry.key.startsWith('$requestId|'))
        .map((entry) => int.tryParse(entry.key.split('|').last))
        .whereType<int>()
        .toSet();
  }

  String resolveUserName({String? uid, String? primary, String? secondary}) {
    final trimmedUid = uid?.trim();
    if (trimmedUid != null && trimmedUid.isNotEmpty) {
      final cached = _userNames[trimmedUid];
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
      _scheduleNameFetch(trimmedUid);
    }

    final primaryPretty = _normalizeName(primary);
    if (primaryPretty.isNotEmpty) {
      return primaryPretty;
    }

    final secondaryPretty = _normalizeName(secondary);
    if (secondaryPretty.isNotEmpty) {
      return secondaryPretty;
    }

    if (trimmedUid != null && trimmedUid.isNotEmpty) {
      return trimmedUid;
    }
    return '';
  }

  Future<AdminMaterialFeedback> approveRequest(MaterialRequest request) async {
    if (isProcessing(request.id)) return AdminMaterialFeedback.none;

    _setRequestProcessing(request.id, true);
    try {
      final adminUid = _repository.currentUserUid;
      final adminName = await _resolveAdminName();
      final updatedItems = request.items
          .map(
            (item) => item.copyWith(status: MaterialRequestItemStatus.approved),
          )
          .toList(growable: false);
      final draft = MaterialRequestDraft.fromRequest(
        request,
      ).copyWith(approverName: adminName, items: updatedItems);
      final documents = await _repository.generateDocuments(
        draft,
        baseFileName: _existingBaseFileName(request),
      );
      await _repository.approveRequest(
        request: request,
        approverName: adminName,
        approverUid: adminUid,
        documents: documents,
      );

      return const AdminMaterialFeedback(
        type: AdminMaterialFeedbackType.success,
        message: 'Permintaan material disetujui.',
      );
    } catch (error) {
      return AdminMaterialFeedback(
        type: AdminMaterialFeedbackType.error,
        message: 'Gagal menyetujui permintaan: $error',
      );
    } finally {
      _setRequestProcessing(request.id, false);
    }
  }

  Future<AdminMaterialFeedback> updateItemStatus(
    MaterialRequest request,
    MaterialRequestItem item,
    String status,
  ) async {
    if (status == item.status) return AdminMaterialFeedback.none;

    final key = '${request.id}|${item.no}';
    if (_processingByItemKey[key] == true) return AdminMaterialFeedback.none;

    _setRequestProcessing(request.id, true);
    _setItemProcessing(key, true);

    try {
      final adminUid = _repository.currentUserUid;
      final adminName = await _resolveAdminName();
      final updatedItems = request.items
          .map(
            (entry) =>
                entry.no == item.no ? entry.copyWith(status: status) : entry,
          )
          .toList(growable: false);

      final anyApproved = updatedItems.any(
        (entry) => entry.status == MaterialRequestItemStatus.approved,
      );
      final existingApprover = request.approverName.trim();
      final resolvedApproverName = anyApproved
          ? (existingApprover.isNotEmpty ? existingApprover : adminName)
          : existingApprover;
      final resolvedApproverUid = anyApproved
          ? (request.approvedByUid ?? adminUid)
          : request.approvedByUid;

      final draft = MaterialRequestDraft.fromRequest(
        request,
      ).copyWith(items: updatedItems, approverName: resolvedApproverName);
      final documents = await _repository.generateDocuments(
        draft,
        baseFileName: _existingBaseFileName(request),
      );

      await _repository.updateItemsWithDocuments(
        request: request,
        items: updatedItems,
        approverName: resolvedApproverName.isNotEmpty
            ? resolvedApproverName
            : (anyApproved ? adminName : null),
        approverUid: resolvedApproverUid,
        documents: documents,
      );

      final statusLabel = status == MaterialRequestItemStatus.approved
          ? 'disetujui'
          : 'dipending';
      return AdminMaterialFeedback(
        type: AdminMaterialFeedbackType.success,
        message: 'Item ${item.no} berhasil $statusLabel.',
      );
    } catch (error) {
      return AdminMaterialFeedback(
        type: AdminMaterialFeedbackType.error,
        message: 'Gagal memperbarui status item: $error',
      );
    } finally {
      _setItemProcessing(key, false);
      _setRequestProcessing(request.id, false);
    }
  }

  Future<AdminMaterialFeedback> markDelivered(MaterialRequest request) async {
    if (isProcessing(request.id)) return AdminMaterialFeedback.none;

    _setRequestProcessing(request.id, true);
    try {
      final adminUid = _repository.currentUserUid;
      final receiverName = await _resolveAdminName();
      await _repository.markDelivered(
        requestId: request.id,
        receiverName: receiverName,
        receiverUid: adminUid,
      );
      return const AdminMaterialFeedback(
        type: AdminMaterialFeedbackType.success,
        message: 'Status diperbarui menjadi barang diterima.',
      );
    } catch (error) {
      return AdminMaterialFeedback(
        type: AdminMaterialFeedbackType.error,
        message: 'Gagal memperbarui status: $error',
      );
    } finally {
      _setRequestProcessing(request.id, false);
    }
  }

  List<MaterialRequest> _applyCompanyFilter(List<MaterialRequest> requests) {
    final selectedFilter = companyFilters.firstWhere(
      (option) => option.label == selectedCompanyFilter.value,
      orElse: () => companyFilters.first,
    );
    if (selectedFilter.matchesAll) {
      return requests;
    }
    if (selectedCompanyFilter.value == anotherCompanyLabel) {
      final specificFilters = companyFilters.where(
        (filter) => !filter.matchesAll && filter.label != anotherCompanyLabel,
      );
      return requests
          .where(
            (request) => !specificFilters.any(
              (filter) => filter.matches(request.companyName),
            ),
          )
          .toList(growable: false);
    }
    return requests
        .where((request) => selectedFilter.matches(request.companyName))
        .toList(growable: false);
  }

  List<MaterialRequest> _applyDateFilter(List<MaterialRequest> requests) {
    final target = selectedDateFilter.value;
    if (target == null) {
      return requests;
    }
    return requests
        .where((request) => isSameDay(request.requestDate.toLocal(), target))
        .toList(growable: false);
  }

  Future<String> _resolveAdminName() async {
    final displayName = _normalizeName(_repository.currentUserDisplayName);
    if (displayName.isNotEmpty) {
      return displayName;
    }

    final uid = (_repository.currentUserUid ?? '').trim();
    if (uid.isNotEmpty) {
      final cached = _userNames[uid];
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
      try {
        final fetched = await _repository.fetchUserDisplayName(uid);
        final normalized = _normalizeName(fetched);
        if (normalized.isNotEmpty) {
          _userNames[uid] = normalized;
          return normalized;
        }
      } catch (_) {
        // Ignore lookup failures and fallback to email/local part.
      }
    }

    final email = _normalizeName(_repository.currentUserEmail);
    if (email.isNotEmpty) {
      return email;
    }

    return 'Admin';
  }

  void _scheduleNameFetch(String uid) {
    if (_userNames.containsKey(uid) || _lookupInFlight.contains(uid)) {
      return;
    }

    _lookupInFlight.add(uid);
    _repository
        .fetchUserDisplayName(uid)
        .then((resolved) {
          final normalized = _normalizeName(resolved);
          if (normalized.isNotEmpty) {
            _userNames[uid] = normalized;
          }
        })
        .catchError((_) {})
        .whenComplete(() {
          _lookupInFlight.remove(uid);
        });
  }

  void _setRequestProcessing(String requestId, bool value) {
    if (value) {
      _processingByRequest[requestId] = true;
      return;
    }
    _processingByRequest.remove(requestId);
  }

  void _setItemProcessing(String key, bool value) {
    if (value) {
      _processingByItemKey[key] = true;
      return;
    }
    _processingByItemKey.remove(key);
  }

  String? _existingBaseFileName(MaterialRequest request) {
    final fileName = request.documentFileName;
    if (fileName == null || fileName.isEmpty) return null;
    if (fileName.toLowerCase().endsWith('.docx')) {
      return fileName.substring(0, fileName.length - 5);
    }
    return fileName;
  }
}

String _normalizeCompanyKey(String raw) {
  return raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

String _normalizeName(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return '';

  final localPart = value.contains('@') ? value.split('@').first : value;
  final sanitized = localPart.replaceAll(RegExp(r'[_\.\-]+'), ' ').trim();
  final words = sanitized
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) {
    return localPart;
  }

  final cased = words
      .map(
        (word) => word.length == 1
            ? word.toUpperCase()
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');

  return cased.isEmpty ? localPart : cased;
}
