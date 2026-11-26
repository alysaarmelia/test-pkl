import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cipta_vera_mandiri_digital/admin_dashboard/widgets/glass.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/homeview/home_theme.dart';

import '../../../repositories/material_request_tracking_repository.dart';
import '../../../view_models/material_request_tracking_view_model.dart';
import '../../../shared/models/material_request.dart';
import '../../../shared/utils/file_downloader.dart';
import '../../widgets/glass_snack_bar.dart';

class MaterialRequestTrackingPage extends StatefulWidget {
  const MaterialRequestTrackingPage({super.key, this.repository});

  final MaterialRequestTrackingRepository? repository;

  @override
  State<MaterialRequestTrackingPage> createState() =>
      _MaterialRequestTrackingPageState();
}

class _MaterialRequestTrackingPageState
    extends State<MaterialRequestTrackingPage> {
  late final String _viewModelTag;
  late final MaterialRequestTrackingViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModelTag = 'material-request-tracking-${identityHashCode(this)}';
    _viewModel = Get.put(
      MaterialRequestTrackingViewModel(
        repository:
            widget.repository ?? MaterialRequestTrackingRepositoryImpl(),
      ),
      tag: _viewModelTag,
    );
  }

  @override
  void dispose() {
    if (Get.isRegistered<MaterialRequestTrackingViewModel>(
      tag: _viewModelTag,
    )) {
      Get.delete<MaterialRequestTrackingViewModel>(
        tag: _viewModelTag,
        force: true,
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      _viewModel.reactiveSignal;
      final theme = Theme.of(context);
      final requesterUid = _viewModel.currentUserUid;
      if (requesterUid == null || requesterUid.isEmpty) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.transparent,
          appBar: _buildAppBar(),
          body: HomeGlassTheme.background(
            child: const SafeArea(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Sesi Anda telah berakhir. Silakan masuk kembali untuk melihat permintaan material.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      return Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(),
        body: HomeGlassTheme.background(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: StreamBuilder<List<MaterialRequest>>(
                stream: _viewModel.watchRequestsByRequester(requesterUid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return _buildError(theme, snapshot.error);
                  }
                  final requests = snapshot.data ?? const <MaterialRequest>[];
                  if (requests.isEmpty) {
                    return _buildEmpty(theme);
                  }
                  final sections = _viewModel.buildSections(requests);
                  final activeRequests = sections.activeRequests;
                  final historyRequests = sections.historyRequests;

                  final cards = <Widget>[];
                  if (activeRequests.isNotEmpty) {
                    cards.add(
                      Text(
                        'Permintaan aktif',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                    cards.add(const SizedBox(height: 12));
                    cards.addAll(
                      activeRequests.map((request) {
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
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _RequestCard(
                            request: request,
                            isProcessing: _viewModel.isProcessing(request.id),
                            onOpenPdf: request.pdfUrl?.isNotEmpty == true
                                ? () => _openExternal(
                                    context,
                                    request.pdfUrl!,
                                    'Gagal membuka file PDF.',
                                  )
                                : null,
                            onDownloadPdf: request.pdfUrl?.isNotEmpty == true
                                ? () => _downloadPdf(context, request)
                                : null,
                            onMarkDelivered:
                                request.status == MaterialRequestStatus.approved
                                ? () => _markDelivered(context, request)
                                : null,
                            isGlass: true,
                            approverDisplayName: approverDisplay,
                            receiverDisplayName: receiverDisplay,
                          ),
                        );
                      }),
                    );
                  }

                  if (historyRequests.isNotEmpty) {
                    if (cards.isNotEmpty) {
                      cards.add(const SizedBox(height: 20));
                    }
                    cards.add(
                      Text(
                        'Riwayat permintaan',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                    cards.add(const SizedBox(height: 12));
                    cards.addAll(
                      historyRequests.map((request) {
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
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _RequestCard(
                            request: request,
                            isProcessing: _viewModel.isProcessing(request.id),
                            onOpenPdf: request.pdfUrl?.isNotEmpty == true
                                ? () => _openExternal(
                                    context,
                                    request.pdfUrl!,
                                    'Gagal membuka file PDF.',
                                  )
                                : null,
                            onDownloadPdf: request.pdfUrl?.isNotEmpty == true
                                ? () => _downloadPdf(context, request)
                                : null,
                            onMarkDelivered: null,
                            isGlass: true,
                            approverDisplayName: approverDisplay,
                            receiverDisplayName: receiverDisplay,
                          ),
                        );
                      }),
                    );
                  }

                  return ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    children: cards,
                  );
                },
              ),
            ),
          ),
        ),
      );
    });
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: Colors.white),
      title: const Text(
        'Permintaan Material Saya',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.25),
                  width: 2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(ThemeData theme, Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Gagal memuat data: $error',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Belum ada permintaan material yang tercatat.',
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Future<void> _openExternal(
    BuildContext context,
    String url,
    String failureMessage,
  ) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      showGlassSnackBar(
        context,
        message: 'Tautan tidak valid.',
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

  Future<void> _markDelivered(
    BuildContext context,
    MaterialRequest request,
  ) async {
    final feedback = await _viewModel.markDelivered(request);
    if (!mounted ||
        feedback.type == MaterialRequestTrackingFeedbackType.none ||
        feedback.message.isEmpty) {
      return;
    }
    final tone = switch (feedback.type) {
      MaterialRequestTrackingFeedbackType.success => GlassSnackTone.success,
      MaterialRequestTrackingFeedbackType.warning => GlassSnackTone.warning,
      MaterialRequestTrackingFeedbackType.error => GlassSnackTone.error,
      MaterialRequestTrackingFeedbackType.none => GlassSnackTone.info,
    };
    showGlassSnackBar(context, message: feedback.message, tone: tone);
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.isProcessing,
    this.onOpenPdf,
    this.onDownloadPdf,
    this.onMarkDelivered,
    this.isGlass = false,
    this.approverDisplayName,
    this.receiverDisplayName,
  });

  final MaterialRequest request;
  final bool isProcessing;
  final VoidCallback? onOpenPdf;
  final VoidCallback? onDownloadPdf;
  final VoidCallback? onMarkDelivered;
  final bool isGlass;
  final String? approverDisplayName;
  final String? receiverDisplayName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glass = isGlass;
    final baseText = glass
        ? Colors.white.withOpacity(0.95)
        : Colors.black.withOpacity(0.85);
    final subtle = glass
        ? Colors.white.withOpacity(0.78)
        : Colors.black.withOpacity(0.6);
    final statusLabel = _statusLabel(request.status);
    final statusColor = _statusColor(request.status, theme);
    final chipLabelColor = glass
        ? Color.lerp(statusColor, Colors.white, 0.6) ?? Colors.white
        : statusColor;
    final displayApprover = _firstNonEmpty([
      approverDisplayName,
      request.approverName,
      request.approvedBy,
    ]);
    final displayReceiver = _firstNonEmpty([
      receiverDisplayName,
      request.receivedBy,
    ]);

    final Widget statusBadge = glass
        ? GlassContainer(
            borderRadius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            blur: 18,
            gradientColors: [
              Colors.white.withOpacity(0.26),
              statusColor.withOpacity(0.18),
            ],
            borderColor: Colors.white.withOpacity(0.45),
            boxShadow: const [],
            child: Text(
              statusLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          )
        : Chip(
            backgroundColor: statusColor.withOpacity(0.15),
            side: BorderSide(color: statusColor.withOpacity(0.4)),
            label: Text(
              statusLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: chipLabelColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    final chipBackgroundColor = glass
        ? Colors.white.withOpacity(0.14)
        : Colors.blueGrey.withOpacity(0.08);
    final outlinedButtonStyle = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      shape: buttonShape,
      foregroundColor: glass ? Colors.white : theme.colorScheme.primary,
      side: BorderSide(
        color: glass
            ? Colors.white.withOpacity(0.6)
            : theme.colorScheme.primary.withOpacity(0.6),
      ),
      backgroundColor: glass
          ? Colors.white.withOpacity(0.08)
          : Colors.transparent,
    );

    Widget buildDeliveredButton() {
      final callback = onMarkDelivered!;
      final accent = glass ? Colors.white : theme.colorScheme.primary;
      final enabled = !isProcessing;
      final gradient = [
        accent.withOpacity(enabled ? 0.42 : 0.22),
        accent.withOpacity(enabled ? 0.24 : 0.12),
      ];
      final borderColor = Colors.white.withOpacity(enabled ? 0.38 : 0.22);
      final textStyle = theme.textTheme.labelLarge?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      );

      final button = Opacity(
        opacity: enabled ? 1 : 0.7,
        child: GlassContainer(
          borderRadius: 18,
          padding: EdgeInsets.zero,
          blur: 18,
          gradientColors: gradient,
          borderColor: borderColor,
          boxShadow: const [],
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: enabled ? callback : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isProcessing)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    else
                      const Icon(
                        Icons.inventory_2_outlined,
                        color: Colors.white,
                      ),
                    const SizedBox(width: 12),
                    Text(
                      isProcessing ? 'Memproses...' : 'Barang diterima',
                      style: textStyle,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      return SizedBox(width: double.infinity, child: button);
    }

    final content = Column(
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
                    request.projectName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: baseText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    request.companyName,
                    style: theme.textTheme.bodySmall?.copyWith(color: subtle),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                statusBadge,
                if (isProcessing) ...[
                  const SizedBox(height: 10),
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Tanggal permintaan: ${_formatDate(request.requestDate)}',
          style: theme.textTheme.bodySmall?.copyWith(color: subtle),
        ),
        Text(
          'Pengorder: ${request.requesterName}',
          style: theme.textTheme.bodySmall?.copyWith(color: subtle),
        ),
        if (displayApprover.isNotEmpty)
          Text(
            'Disetujui oleh: $displayApprover',
            style: theme.textTheme.bodySmall?.copyWith(color: subtle),
          ),
        if (displayReceiver.isNotEmpty)
          Text(
            'Barang diterima oleh: $displayReceiver',
            style: theme.textTheme.bodySmall?.copyWith(color: subtle),
          ),
        if (request.receivedAt != null)
          Text(
            'Diterima pada ${_formatDate(request.receivedAt!)}',
            style: theme.textTheme.bodySmall?.copyWith(color: subtle),
          ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final double availableWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 0.0;
            final bool isNarrow = availableWidth < 420 && availableWidth > 0;
            final double computedWidth = isNarrow || availableWidth <= 0
                ? availableWidth
                : ((availableWidth - 12.0) / 2.0).clamp(0.0, availableWidth);

            return Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: request.items
                  .map((item) {
                    final tag = _buildItemTag(
                      theme: theme,
                      glass: glass,
                      chipBackgroundColor: chipBackgroundColor,
                      baseText: baseText,
                      item: item,
                    );
                    if (computedWidth <= 0) {
                      return tag;
                    }
                    return SizedBox(width: computedWidth, child: tag);
                  })
                  .toList(growable: false),
            );
          },
        ),
        const SizedBox(height: 16),
        if (onOpenPdf != null || onDownloadPdf != null)
          Builder(
            builder: (_) {
              final buttons = <Widget>[];
              if (onOpenPdf != null) {
                buttons.add(
                  OutlinedButton.icon(
                    onPressed: onOpenPdf,
                    style: outlinedButtonStyle,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Lihat PDF'),
                  ),
                );
              }
              if (onDownloadPdf != null) {
                buttons.add(
                  OutlinedButton.icon(
                    onPressed: onDownloadPdf,
                    style: outlinedButtonStyle,
                    icon: const Icon(Icons.download),
                    label: const Text('Unduh PDF'),
                  ),
                );
              }
              if (buttons.length == 1) {
                return SizedBox(width: double.infinity, child: buttons.first);
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(child: buttons[0]),
                  const SizedBox(width: 12),
                  Expanded(child: buttons[1]),
                ],
              );
            },
          ),
        if (onMarkDelivered != null) ...[
          const SizedBox(height: 14),
          buildDeliveredButton(),
        ],
      ],
    );

    const padding = EdgeInsets.fromLTRB(18, 18, 18, 16);

    if (glass) {
      return GlassContainer(
        borderRadius: 18,
        padding: padding,
        blur: 20,
        gradientColors: [
          Colors.white.withOpacity(0.18),
          Colors.white.withOpacity(0.06),
        ],
        borderColor: Colors.white.withOpacity(0.24),
        boxShadow: const [
          BoxShadow(
            color: Color.fromARGB(20, 15, 23, 42),
            offset: Offset(0, 20),
            blurRadius: 40,
            spreadRadius: -18,
          ),
        ],
        child: content,
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 3,
      color: Colors.white,
      child: Padding(padding: padding, child: content),
    );
  }

  Widget _buildItemTag({
    required ThemeData theme,
    required bool glass,
    required Color chipBackgroundColor,
    required Color baseText,
    required MaterialRequestItem item,
  }) {
    final text = '${item.no}. ${item.name}';
    final subtitle = 'Jumlah: ${item.quantity}';
    final statusLabel = _itemStatusLabel(item.status);
    final statusColor = _itemStatusColor(item.status, glass);

    if (glass) {
      return GlassContainer(
        borderRadius: 28,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        blur: 16,
        gradientColors: [
          Colors.white.withOpacity(0.24),
          Colors.white.withOpacity(0.08),
        ],
        borderColor: Colors.white.withOpacity(0.32),
        boxShadow: const [],
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    textAlign: TextAlign.start,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _ItemStatusPill(
              label: statusLabel,
              color: statusColor,
              dense: true,
              glass: true,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: chipBackgroundColor,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      alignment: Alignment.center,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: baseText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: baseText.withOpacity(0.78),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ItemStatusPill(
            label: statusLabel,
            color: statusColor,
            dense: true,
            glass: false,
          ),
        ],
      ),
    );
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

  Color _itemStatusColor(String status, bool glass) {
    switch (status) {
      case MaterialRequestItemStatus.approved:
        return glass ? Colors.greenAccent : Colors.green;
      case MaterialRequestItemStatus.pending:
      default:
        return glass ? Colors.orangeAccent : Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case MaterialRequestStatus.approved:
        return 'Menunggu barang';
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
        return Colors.amber;
      case MaterialRequestStatus.delivered:
        return Colors.green;
      case MaterialRequestStatus.pending:
      default:
        return theme.colorScheme.primary;
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
    final d = date.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = months[(d.month - 1).clamp(0, 11)];
    final year = d.year.toString().padLeft(4, '0').substring(2);
    return '$day $month $year';
  }
}

class _ItemStatusPill extends StatelessWidget {
  const _ItemStatusPill({
    required this.label,
    required this.color,
    this.dense = false,
    this.glass = false,
  });

  final String label;
  final Color color;
  final bool dense;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final padding = dense
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    final background = glass
        ? color.withOpacity(0.26)
        : color.withOpacity(0.14);
    final borderColor = glass
        ? Colors.white.withOpacity(0.55)
        : color.withOpacity(0.55);
    final textColor = glass ? Colors.white : color;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: dense ? 9 : 10, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
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
