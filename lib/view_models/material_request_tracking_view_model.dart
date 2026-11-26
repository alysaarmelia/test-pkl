import 'package:get/get.dart';

import '../shared/models/material_request.dart';
import '../repositories/material_request_tracking_repository.dart';

enum MaterialRequestTrackingFeedbackType { success, warning, error, none }

class MaterialRequestTrackingFeedback {
  const MaterialRequestTrackingFeedback({
    required this.type,
    this.message = '',
  });

  final MaterialRequestTrackingFeedbackType type;
  final String message;

  static const none = MaterialRequestTrackingFeedback(
    type: MaterialRequestTrackingFeedbackType.none,
  );
}

class MaterialRequestTrackingSections {
  const MaterialRequestTrackingSections({
    required this.activeRequests,
    required this.historyRequests,
  });

  final List<MaterialRequest> activeRequests;
  final List<MaterialRequest> historyRequests;
}

class MaterialRequestTrackingViewModel extends GetxController {
  MaterialRequestTrackingViewModel({
    MaterialRequestTrackingRepository? repository,
  }) : _repository = repository ?? MaterialRequestTrackingRepositoryImpl();

  final MaterialRequestTrackingRepository _repository;

  final RxMap<String, bool> _processingByRequest = <String, bool>{}.obs;
  final RxMap<String, String> _userNames = <String, String>{}.obs;
  final Set<String> _nameLookupsInProgress = <String>{};

  String? get currentUserUid => _repository.currentUserUid;
  int get reactiveSignal => _processingByRequest.length + _userNames.length;

  Stream<List<MaterialRequest>> watchRequestsByRequester(String requesterUid) {
    return _repository.watchRequestsByRequester(requesterUid: requesterUid);
  }

  bool isProcessing(String requestId) {
    return _processingByRequest[requestId] == true;
  }

  MaterialRequestTrackingSections buildSections(
    List<MaterialRequest> requests,
  ) {
    final sorted = [...requests]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final activeRequests = sorted
        .where((r) => r.status != MaterialRequestStatus.delivered)
        .toList(growable: false);
    final historyRequests = sorted
        .where((r) => r.status == MaterialRequestStatus.delivered)
        .toList(growable: false);

    return MaterialRequestTrackingSections(
      activeRequests: activeRequests,
      historyRequests: historyRequests,
    );
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

  Future<MaterialRequestTrackingFeedback> markDelivered(
    MaterialRequest request,
  ) async {
    if (isProcessing(request.id)) {
      return MaterialRequestTrackingFeedback.none;
    }

    final currentUid = _repository.currentUserUid;
    if (currentUid == null || currentUid.isEmpty) {
      return const MaterialRequestTrackingFeedback(
        type: MaterialRequestTrackingFeedbackType.error,
        message: 'Sesi berakhir, silakan masuk kembali.',
      );
    }

    _setProcessing(request.id, true);
    final receiverName = _repository.currentUserDisplayName;
    try {
      await _repository.markDelivered(
        requestId: request.id,
        receiverName: receiverName,
        receiverUid: currentUid,
      );
      return const MaterialRequestTrackingFeedback(
        type: MaterialRequestTrackingFeedbackType.success,
        message: 'Terima kasih! Barang ditandai sudah diterima.',
      );
    } catch (error) {
      return MaterialRequestTrackingFeedback(
        type: MaterialRequestTrackingFeedbackType.error,
        message: 'Gagal memperbarui status: $error',
      );
    } finally {
      _setProcessing(request.id, false);
    }
  }

  void _setProcessing(String requestId, bool value) {
    if (value) {
      _processingByRequest[requestId] = true;
      return;
    }
    _processingByRequest.remove(requestId);
  }

  void _scheduleNameFetch(String uid) {
    if (_userNames.containsKey(uid) || _nameLookupsInProgress.contains(uid)) {
      return;
    }

    _nameLookupsInProgress.add(uid);
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
          _nameLookupsInProgress.remove(uid);
        });
  }
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
