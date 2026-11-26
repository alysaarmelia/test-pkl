import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../admin_dashboard/widgets/glass.dart';
import '../../../repositories/admin_material_requests_repository.dart';
import '../../../view_models/admin_material_requests_view_model.dart';
import '../../../shared/models/material_request.dart';
import '../../../shared/utils/file_downloader.dart';
import '../../widgets/glass_snack_bar.dart';

class AdminMaterialRequestsPage extends StatefulWidget {
  const AdminMaterialRequestsPage({super.key});

  @override
  State<AdminMaterialRequestsPage> createState() =>
      _AdminMaterialRequestsPageState();
}

class _AdminMaterialRequestsPageState extends State<AdminMaterialRequestsPage> {
  late final String _viewModelTag;
  late final AdminMaterialRequestsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModelTag = 'admin-material-requests-${identityHashCode(this)}';
    _viewModel = Get.put(
      AdminMaterialRequestsViewModel(
        repository: AdminMaterialRequestsRepositoryImpl(),
      ),
      tag: _viewModelTag,
    );
  }

  @override
  void dispose() {
    if (Get.isRegistered<AdminMaterialRequestsViewModel>(tag: _viewModelTag)) {
      Get.delete<AdminMaterialRequestsViewModel>(
        tag: _viewModelTag,
        force: true,
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final theme = Theme.of(context);
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Manajemen Permintaan Material',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Kelola persetujuan dan distribusi material proyek secara terpusat.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.72),
                  ),
                ),
                const SizedBox(height: 12),
                _buildFilters(theme),
                const SizedBox(height: 16),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(38),
                    child: GlassContainer(
                      borderRadius: 38,
                      blur: 30,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 15,
                      ),
                      gradientColors: const [
                        Color.fromARGB(110, 23, 29, 60),
                        Color.fromARGB(78, 16, 22, 50),
                      ],
                      borderColor: Colors.white.withOpacity(0.22),
                      child: _buildContent(theme),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildContent(ThemeData theme) {
    return StreamBuilder<List<MaterialRequest>>(
      stream: _viewModel.watchRequests(limit: 200),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Gagal memuat data: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          );
        }
        final requests = snapshot.data ?? const <MaterialRequest>[];
        if (requests.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Belum ada permintaan material.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final sections = _viewModel.buildSections(requests);
        final filteredRequests = sections.filteredRequests;
        final pendingRequests = sections.pendingRequests;
        final approvedRequests = sections.approvedRequests;
        final deliveredRequests = sections.deliveredRequests;
        final activeRequests = sections.activeRequests;
        final historyRequests = sections.historyRequests;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SummaryHeader(
              activeTotal: pendingRequests.length + approvedRequests.length,
              pending: pendingRequests.length,
              approved: approvedRequests.length,
              delivered: deliveredRequests.length,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filteredRequests.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Tidak ada permintaan untuk ${_viewModel.activeFilterLabel()}.',
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 12),
                      children: [
                        if (activeRequests.isNotEmpty)
                          ...activeRequests.map((request) {
                            final isProcessing = _viewModel.isProcessing(
                              request.id,
                            );
                            final requesterDisplay = _viewModel.resolveUserName(
                              uid: request.requesterUid,
                              primary: request.requesterName,
                            );
                            final approverDisplay = _viewModel.resolveUserName(
                              uid: request.approvedByUid,
                              primary: request.approverName,
                              secondary: request.approvedBy,
                            );
                            final receiverDisplay = _viewModel.resolveUserName(
                              uid: request.receivedByUid,
                              primary: request.receivedBy,
                            );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _AdminMaterialRequestTile(
                                request: request,
                                isProcessing: isProcessing,
                                requesterDisplayName: requesterDisplay,
                                approverDisplayName: approverDisplay,
                                receiverDisplayName: receiverDisplay,
                                processingItemNos: _viewModel.processingItemNos(
                                  request.id,
                                ),
                                onOpenPdf:
                                    !isProcessing &&
                                        (request.pdfUrl?.isNotEmpty ?? false)
                                    ? () => _openPdf(context, request)
                                    : null,
                                onDownloadPdf:
                                    !isProcessing &&
                                        (request.pdfUrl?.isNotEmpty ?? false)
                                    ? () => _downloadPdf(context, request)
                                    : null,
                                onApprove:
                                    request.status ==
                                            MaterialRequestStatus.pending &&
                                        !isProcessing
                                    ? () => _approveRequest(context, request)
                                    : null,
                                onMarkDelivered:
                                    request.status ==
                                            MaterialRequestStatus.approved &&
                                        !isProcessing
                                    ? () => _markDelivered(context, request)
                                    : null,
                                onUpdateItemStatus:
                                    !isProcessing &&
                                        request.status !=
                                            MaterialRequestStatus.delivered
                                    ? (item, status) => _updateItemStatus(
                                        context,
                                        request,
                                        item,
                                        status,
                                      )
                                    : null,
                              ),
                            );
                          }),
                        if (historyRequests.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Riwayat permintaan',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...historyRequests.map((request) {
                            final requesterDisplay = _viewModel.resolveUserName(
                              uid: request.requesterUid,
                              primary: request.requesterName,
                            );
                            final approverDisplay = _viewModel.resolveUserName(
                              uid: request.approvedByUid,
                              primary: request.approverName,
                              secondary: request.approvedBy,
                            );
                            final receiverDisplay = _viewModel.resolveUserName(
                              uid: request.receivedByUid,
                              primary: request.receivedBy,
                            );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Opacity(
                                opacity: 0.85,
                                child: _AdminMaterialRequestTile(
                                  request: request,
                                  isProcessing: _viewModel.isProcessing(
                                    request.id,
                                  ),
                                  requesterDisplayName: requesterDisplay,
                                  approverDisplayName: approverDisplay,
                                  receiverDisplayName: receiverDisplay,
                                  processingItemNos: _viewModel
                                      .processingItemNos(request.id),
                                  onOpenPdf:
                                      (request.pdfUrl?.isNotEmpty ?? false)
                                      ? () => _openPdf(context, request)
                                      : null,
                                  onDownloadPdf:
                                      (request.pdfUrl?.isNotEmpty ?? false)
                                      ? () => _downloadPdf(context, request)
                                      : null,
                                  onUpdateItemStatus: null,
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilters(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildCompanyFilterField(theme)),
        const SizedBox(width: 12),
        Expanded(child: _buildDateFilterField(theme)),
      ],
    );
  }

  Widget _buildCompanyFilterField(ThemeData theme) {
    final selectedCompanyFilter = _viewModel.selectedCompanyFilter.value;
    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Filter perusahaan', style: labelStyle),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: PopupMenuButton<String>(
            initialValue: selectedCompanyFilter,
            padding: EdgeInsets.zero,
            position: PopupMenuPosition.under,
            offset: const Offset(0, 6),
            color: Colors.black.withOpacity(0.82),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: (value) {
              _viewModel.setCompanyFilter(value);
            },
            itemBuilder: (context) => AdminMaterialRequestsViewModel
                .companyFilters
                .map(
                  (option) => PopupMenuItem<String>(
                    value: option.label,
                    child: Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                )
                .toList(),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Pilih perusahaan',
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.20)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                labelStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.85),
                  fontWeight: FontWeight.w500,
                ),
                suffixIcon: const Icon(
                  Icons.arrow_drop_down_rounded,
                  color: Colors.white,
                ),
              ),
              isEmpty: selectedCompanyFilter.isEmpty,
              child: Text(
                selectedCompanyFilter,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateFilterField(ThemeData theme) {
    final selectedDateFilter = _viewModel.selectedDateFilter.value;
    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final selectedLabel = selectedDateFilter == null
        ? 'Semua tanggal'
        : _viewModel.formatFilterDate(selectedDateFilter);
    final isToday =
        selectedDateFilter != null &&
        _viewModel.isSameDay(selectedDateFilter, _viewModel.today());
    final displayLabel = isToday ? 'Hari ini ($selectedLabel)' : selectedLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Filter tanggal', style: labelStyle),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDate,
          behavior: HitTestBehavior.opaque,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Pilih tanggal',
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.20)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              labelStyle: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.85),
                fontWeight: FontWeight.w500,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selectedDateFilter != null)
                    IconButton(
                      tooltip: 'Reset tanggal',
                      icon: const Icon(Icons.close),
                      color: Colors.white,
                      onPressed: _viewModel.clearDateFilter,
                    ),
                  IconButton(
                    tooltip: 'Pilih tanggal',
                    icon: const Icon(Icons.calendar_today_outlined),
                    color: Colors.white,
                    onPressed: _pickDate,
                  ),
                ],
              ),
            ),
            isEmpty: false,
            child: Text(
              displayLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final initial = _viewModel.selectedDateFilter.value ?? _viewModel.today();
    final initialNormalized = _viewModel.normalizeDate(initial);
    final today = _viewModel.today();
    final firstDate = DateTime(today.year - 5, 1, 1);
    final lastDate = DateTime(today.year + 5, 12, 31);
    final initialDate = initialNormalized.isBefore(firstDate)
        ? firstDate
        : (initialNormalized.isAfter(lastDate) ? lastDate : initialNormalized);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) {
      _viewModel.setDateFilter(_viewModel.normalizeDate(picked));
    }
  }

  Future<void> _openPdf(BuildContext context, MaterialRequest request) {
    return _launchExternalUrl(
      context,
      request.pdfUrl,
      emptyMessage: 'File PDF belum tersedia.',
      invalidMessage: 'Tautan PDF tidak valid.',
      failureMessage: 'Tidak dapat membuka file PDF.',
    );
  }

  Future<void> _launchExternalUrl(
    BuildContext context,
    String? url, {
    required String emptyMessage,
    required String invalidMessage,
    required String failureMessage,
  }) async {
    if (url == null || url.isEmpty) {
      showGlassSnackBar(
        context,
        message: emptyMessage,
        tone: GlassSnackTone.warning,
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      showGlassSnackBar(
        context,
        message: invalidMessage,
        tone: GlassSnackTone.error,
      );
      return;
    }
    final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!success) {
      showGlassSnackBar(
        context,
        message: failureMessage,
        tone: GlassSnackTone.error,
      );
    }
  }

  Future<void> _approveRequest(
    BuildContext context,
    MaterialRequest request,
  ) async {
    final feedback = await _viewModel.approveRequest(request);
    if (!mounted) return;
    _showActionFeedback(context, feedback);
  }

  Future<void> _updateItemStatus(
    BuildContext context,
    MaterialRequest request,
    MaterialRequestItem item,
    String status,
  ) async {
    final feedback = await _viewModel.updateItemStatus(request, item, status);
    if (!mounted) return;
    _showActionFeedback(context, feedback);
  }

  Future<void> _markDelivered(
    BuildContext context,
    MaterialRequest request,
  ) async {
    final feedback = await _viewModel.markDelivered(request);
    if (!mounted) return;
    _showActionFeedback(context, feedback);
  }

  Future<void> _downloadPdf(BuildContext context, MaterialRequest request) {
    final suggestedName = request.pdfFileName?.isNotEmpty == true
        ? request.pdfFileName!
        : 'material_request_${request.id}.pdf';
    return _downloadFile(
      context,
      url: request.pdfUrl,
      fileName: suggestedName,
      emptyMessage: 'File PDF belum tersedia.',
    );
  }

  Future<void> _downloadFile(
    BuildContext context, {
    required String? url,
    required String fileName,
    required String emptyMessage,
  }) async {
    if (url == null || url.isEmpty) {
      showGlassSnackBar(
        context,
        message: emptyMessage,
        tone: GlassSnackTone.warning,
      );
      return;
    }

    try {
      final savedPath = await downloadFile(url: url, fileName: fileName);
      if (!mounted) return;
      final message = savedPath == null
          ? 'Unduhan dimulai di browser Anda.'
          : 'File tersimpan di $savedPath';
      showGlassSnackBar(
        context,
        message: message,
        tone: GlassSnackTone.success,
      );
    } catch (e) {
      if (!mounted) return;
      showGlassSnackBar(
        context,
        message: 'Gagal mengunduh file: $e',
        tone: GlassSnackTone.error,
      );
    }
  }

  void _showActionFeedback(
    BuildContext context,
    AdminMaterialFeedback feedback,
  ) {
    if (feedback.type == AdminMaterialFeedbackType.none ||
        feedback.message.isEmpty) {
      return;
    }
    final tone = switch (feedback.type) {
      AdminMaterialFeedbackType.success => GlassSnackTone.success,
      AdminMaterialFeedbackType.warning => GlassSnackTone.warning,
      AdminMaterialFeedbackType.error => GlassSnackTone.error,
      AdminMaterialFeedbackType.none => GlassSnackTone.info,
    };
    showGlassSnackBar(context, message: feedback.message, tone: tone);
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

String _firstNonEmpty(Iterable<String?> values) {
  for (final value in values) {
    final normalized = _normalizeName(value);
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return '';
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.activeTotal,
    required this.pending,
    required this.approved,
    required this.delivered,
  });

  final int activeTotal;
  final int pending;
  final int approved;
  final int delivered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseText = theme.colorScheme.brightness == Brightness.dark
        ? Colors.white
        : theme.colorScheme.onSurface;
    final subtle = baseText.withOpacity(0.72);

    return GlassContainer(
      borderRadius: 28,
      blur: 24,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      gradientColors: const [
        Color.fromARGB(124, 27, 32, 68),
        Color.fromARGB(82, 20, 26, 54),
      ],
      borderColor: Colors.white.withOpacity(0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ringkasan Permintaan',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: baseText,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Pantau status permintaan material secara real-time.',
            style: theme.textTheme.bodySmall?.copyWith(color: subtle),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              const desiredColumns = 4;
              const spacing = 18.0;
              const minTileWidth = 160.0;

              final availableWidth = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : desiredColumns * (minTileWidth + spacing) - spacing;

              int computedColumns =
                  ((availableWidth + spacing) / (minTileWidth + spacing))
                      .floor();
              if (computedColumns < 1) {
                computedColumns = 1;
              } else if (computedColumns > desiredColumns) {
                computedColumns = desiredColumns;
              }

              final tileWidth = computedColumns > 0
                  ? (availableWidth - spacing * (computedColumns - 1)) /
                        computedColumns
                  : availableWidth;

              final stats = [
                _SummaryStat(
                  title: 'Total aktif',
                  value: activeTotal.toString(),
                  chipColor: Colors.blueAccent,
                ),
                _SummaryStat(
                  title: 'Pending',
                  value: pending.toString(),
                  chipColor: Colors.orange,
                ),
                _SummaryStat(
                  title: 'Menunggu barang',
                  value: approved.toString(),
                  chipColor: Colors.amber,
                ),
                _SummaryStat(
                  title: 'Barang diterima',
                  value: delivered.toString(),
                  chipColor: Colors.green,
                ),
              ];

              return Wrap(
                spacing: spacing,
                runSpacing: 18,
                children: stats
                    .map((stat) => SizedBox(width: tileWidth, child: stat))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.title,
    required this.value,
    required this.chipColor,
  });

  final String title;
  final String value;
  final Color chipColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseText = theme.colorScheme.brightness == Brightness.dark
        ? Colors.white
        : theme.colorScheme.onSurface;
    return GlassContainer(
      borderRadius: 22,
      blur: 22,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      gradientColors: [
        chipColor.withOpacity(0.14),
        chipColor.withOpacity(0.06),
      ],
      borderColor: chipColor.withOpacity(0.24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: baseText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: baseText.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminMaterialRequestTile extends StatelessWidget {
  const _AdminMaterialRequestTile({
    required this.request,
    required this.isProcessing,
    required this.requesterDisplayName,
    this.approverDisplayName,
    this.receiverDisplayName,
    this.processingItemNos = const <int>{},
    this.onOpenPdf,
    this.onDownloadPdf,
    this.onApprove,
    this.onMarkDelivered,
    this.onUpdateItemStatus,
  });

  final MaterialRequest request;
  final bool isProcessing;
  final String requesterDisplayName;
  final String? approverDisplayName;
  final String? receiverDisplayName;
  final Set<int> processingItemNos;
  final VoidCallback? onOpenPdf;
  final VoidCallback? onDownloadPdf;
  final VoidCallback? onApprove;
  final VoidCallback? onMarkDelivered;
  final void Function(MaterialRequestItem item, String status)?
  onUpdateItemStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = [
      'Proyek: ${request.projectName}',
      'Tanggal: ${_formatDate(request.requestDate)}',
      'Pengorder: $requesterDisplayName',
    ].join(' • ');
    final statusLabel = _statusLabel(request.status);
    final statusColor = _statusColor(request.status, theme);
    final statusChip = Chip(
      label: Text(
        statusLabel,
        style: theme.textTheme.labelMedium?.copyWith(
          color: statusColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: statusColor.withOpacity(0.12),
      side: BorderSide(color: statusColor.withOpacity(0.4)),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: GlassContainer(
        borderRadius: 18,
        blur: 18,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        gradientColors: const [
          Color.fromARGB(178, 8, 10, 22),
          Color.fromARGB(140, 12, 14, 24),
        ],
        borderColor: Colors.white.withOpacity(0.1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.companyName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    statusChip,
                    if (isProcessing) ...[
                      const SizedBox(height: 8),
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            ..._buildMetadata(theme),
            const SizedBox(height: 10),
            _buildItems(theme),
            const SizedBox(height: 12),
            _buildActions(theme),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMetadata(ThemeData theme) {
    final items = <Widget>[];
    final approverDisplay = _normalizeName(
      _firstNonEmpty([
        approverDisplayName,
        request.approverName,
        request.approvedBy,
      ]),
    );
    if (approverDisplay.isNotEmpty) {
      items.add(
        Text(
          'Mengetahui (kantor): $approverDisplay',
          style: theme.textTheme.bodySmall,
        ),
      );
    }
    if (request.approvedAt != null) {
      items.add(
        Text(
          'Disetujui pada ${_formatDateTime(request.approvedAt!)}',
          style: theme.textTheme.bodySmall,
        ),
      );
    }
    final receiverDisplay = _normalizeName(
      _firstNonEmpty([receiverDisplayName, request.receivedBy]),
    );
    if (request.status == MaterialRequestStatus.delivered &&
        receiverDisplay.isNotEmpty) {
      items.add(
        Text(
          'Barang diterima oleh: $receiverDisplay',
          style: theme.textTheme.bodySmall,
        ),
      );
    }
    if (request.receivedAt != null) {
      items.add(
        Text(
          'Diterima pada ${_formatDateTime(request.receivedAt!)}',
          style: theme.textTheme.bodySmall,
        ),
      );
    }
    return items;
  }

  Widget _buildItems(ThemeData theme) {
    if (request.items.isEmpty) {
      return Text(
        'Belum ada daftar material.',
        style: theme.textTheme.bodySmall,
      );
    }

    return Column(
      children: request.items
          .map((item) {
            final statusLabel = _itemStatusLabel(item.status);
            final statusColor = _itemStatusColor(item.status, theme);
            final isItemProcessing = processingItemNos.contains(item.no);
            final canEditStatus =
                onUpdateItemStatus != null &&
                !isProcessing &&
                request.status != MaterialRequestStatus.delivered;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.no}. ${item.name}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Jumlah: ${item.quantity}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(
                              0.72,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildItemStatusPill(statusLabel, statusColor, theme),
                      const SizedBox(height: 6),
                      if (isItemProcessing)
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (canEditStatus)
                        _buildStatusMenu(theme, item, statusColor),
                    ],
                  ),
                ],
              ),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _buildActions(ThemeData theme) {
    final buttons = <Widget>[];
    if (onOpenPdf != null) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: onOpenPdf,
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('PDF'),
        ),
      );
    }
    if (onDownloadPdf != null) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: onDownloadPdf,
          icon: const Icon(Icons.download),
          label: const Text('Unduh PDF'),
        ),
      );
    }
    if (onApprove != null) {
      buttons.add(
        FilledButton.icon(
          onPressed: onApprove,
          icon: const Icon(Icons.verified_outlined),
          label: const Text('Setujui'),
        ),
      );
    }
    if (onMarkDelivered != null) {
      buttons.add(
        FilledButton.icon(
          onPressed: onMarkDelivered,
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Barang diterima'),
        ),
      );
    }
    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(spacing: 12, runSpacing: 12, children: buttons);
  }

  Widget _buildItemStatusPill(String label, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 9, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusMenu(
    ThemeData theme,
    MaterialRequestItem item,
    Color accent,
  ) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == item.status) return;
        onUpdateItemStatus?.call(item, value);
      },
      tooltip: 'Ubah status item',
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: MaterialRequestItemStatus.pending,
          child: _statusOption(
            theme,
            label: 'Pending',
            color: _itemStatusColor(MaterialRequestItemStatus.pending, theme),
            active: item.status == MaterialRequestItemStatus.pending,
          ),
        ),
        PopupMenuItem(
          value: MaterialRequestItemStatus.approved,
          child: _statusOption(
            theme,
            label: 'Disetujui',
            color: _itemStatusColor(MaterialRequestItemStatus.approved, theme),
            active: item.status == MaterialRequestItemStatus.approved,
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Ubah status',
            style: theme.textTheme.labelSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Icon(Icons.arrow_drop_down, size: 18, color: Colors.white70),
        ],
      ),
    );
  }

  Widget _statusOption(
    ThemeData theme, {
    required String label,
    required Color color,
    required bool active,
  }) {
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: active ? color : theme.colorScheme.onSurface,
      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
    );
    return Row(
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 8),
        Text(label, style: style),
      ],
    );
  }

  Color _itemStatusColor(String status, ThemeData theme) {
    switch (status) {
      case MaterialRequestItemStatus.approved:
        return Colors.greenAccent.shade400;
      case MaterialRequestItemStatus.pending:
      default:
        return Colors.orangeAccent;
    }
  }

  String _itemStatusLabel(String status) {
    switch (status) {
      case MaterialRequestItemStatus.approved:
        return 'Disetujui';
      case MaterialRequestItemStatus.pending:
      default:
        return 'Pending';
    }
  }

  String _formatDate(DateTime date) {
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

  String _formatDateTime(DateTime date) {
    final local = date.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${_formatDate(local)} $hour:$minute';
  }

  String _statusLabel(String status) {
    switch (status) {
      case MaterialRequestStatus.approved:
        return 'Disetujui';
      case MaterialRequestStatus.delivered:
        return 'Barang diterima';
      case MaterialRequestStatus.pending:
      default:
        return 'Menunggu persetujuan';
    }
  }

  Color _statusColor(String status, ThemeData theme) {
    switch (status) {
      case MaterialRequestStatus.approved:
        return Colors.blueAccent;
      case MaterialRequestStatus.delivered:
        return Colors.green;
      case MaterialRequestStatus.pending:
      default:
        return Colors.orange;
    }
  }
}
