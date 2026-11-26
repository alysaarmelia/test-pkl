import 'dart:async';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:cipta_vera_mandiri_digital/app/modules/home/homeview/home_theme.dart';
import 'package:cipta_vera_mandiri_digital/repositories/pemberkasan_repository.dart';
import 'package:cipta_vera_mandiri_digital/view_models/pemberkasan_view_model.dart';

import '../../../shared/models/document_record.dart';

class PemberkasanPage extends StatefulWidget {
  const PemberkasanPage({
    super.key,
    this.repository,
    this.viewModel,
    this.enableReminders = true,
  });

  final PemberkasanRepository? repository;
  final PemberkasanViewModel? viewModel;
  final bool enableReminders;

  @override
  State<PemberkasanPage> createState() => _PemberkasanPageState();
}

class _PemberkasanPageState extends State<PemberkasanPage> {
  late final PemberkasanViewModel _viewModel;
  late final String _viewModelTag;

  @override
  void initState() {
    super.initState();
    _viewModelTag = 'pemberkasan-${identityHashCode(this)}';
    _viewModel = Get.put(
        widget.viewModel ??
            PemberkasanViewModel(
              repository: widget.repository,
              enableReminders: widget.enableReminders,
            ),
        tag: _viewModelTag,
    );
  }

  @override
  void dispose() {
    if (Get.isRegistered<PemberkasanViewModel>(tag: _viewModelTag)) {
      Get.delete<PemberkasanViewModel>(tag: _viewModelTag, force: true);
    }
    super.dispose();
  }

  Widget _glassCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withOpacity(0.32),
              width: 1.2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _glassButton({
    required VoidCallback? onPressed,
    required String label,
    IconData? icon,
  }) {
    final isDisabled = onPressed == null;
    return SizedBox(
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: Colors.white.withOpacity(isDisabled ? 0.18 : 0.32),
              border: Border.all(
                color: Colors.white.withOpacity(0.45),
                width: 1.2,
              ),
            ),
            child: TextButton(
              onPressed: onPressed,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 18,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<PemberkasanViewModel>(
      tag: _viewModelTag,
      builder: (viewModel) {
        final userUid = viewModel.currentUserUid;
        final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        );
        final subtitleStyle = Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.85));

        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text(
              'Pemberkasan',
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
          ),
          body: HomeGlassTheme.background(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: SafeArea(
                child: userUid == null || userUid.isEmpty
                    ? const _SignInNotice()
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Kelola Dokumen', style: titleStyle),
                            const SizedBox(height: 6),
                            Text(
                              'Unggah berkas penting dan dapatkan pengingat sebelum kedaluwarsa.',
                              style: subtitleStyle,
                            ),
                            const SizedBox(height: 18),
                            Expanded(
                              child: StreamBuilder<List<DocumentRecord>>(
                                stream: viewModel.documentsStream,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    );
                                  }
                                  if (snapshot.hasError) {
                                    return Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 420,
                                        ),
                                        child: _glassCard(
                                          child: _ErrorState(
                                            message:
                                                'Tidak dapat memuat pemberkasan: ${snapshot.error}',
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  final documents =
                                      snapshot.data ?? const <DocumentRecord>[];
                                  unawaited(viewModel.syncDocuments(documents));
                                  if (documents.isEmpty) {
                                    return Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 420,
                                        ),
                                        child: _glassCard(
                                          child: const _EmptyState(),
                                        ),
                                      ),
                                    );
                                  }

                                  return ListView.separated(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: documents.length,
                                    separatorBuilder: (_, index) =>
                                        const SizedBox(height: 14),
                                    itemBuilder: (context, index) {
                                      final doc = documents[index];
                                      return _DocumentTile(
                                        record: doc,
                                        onTap: () =>
                                            _openDocumentUrl(doc.downloadUrl),
                                        onDelete: () =>
                                            _confirmDeleteDocument(doc),
                                        isDeleting: viewModel.isDeleting(doc.id),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            _glassButton(
                              onPressed: viewModel.isUploading
                                  ? null
                                  : _showAddDocumentDialog,
                              label: viewModel.isUploading
                                  ? 'Mengunggah…'
                                  : 'Tambah Dokumen',
                              icon: Icons.upload_file,
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFeedback(PemberkasanFeedback feedback) {
    if (feedback.type == PemberkasanFeedbackType.none ||
        feedback.message.isEmpty) {
      return;
    }
    switch (feedback.type) {
      case PemberkasanFeedbackType.success:
        _showGlassSnackBar(
          context,
          feedback.message,
          icon: Icons.check_circle_outline,
          tintColor: Colors.lightGreenAccent,
        );
        break;
      case PemberkasanFeedbackType.info:
        _showGlassSnackBar(
          context,
          feedback.message,
          icon: Icons.info_outline,
          tintColor: Colors.lightBlueAccent,
        );
        break;
      case PemberkasanFeedbackType.warning:
        _showGlassSnackBar(
          context,
          feedback.message,
          icon: Icons.warning_amber_rounded,
          tintColor: Colors.amberAccent,
        );
        break;
      case PemberkasanFeedbackType.error:
        _showGlassSnackBar(
          context,
          feedback.message,
          icon: Icons.error_outline,
          tintColor: Colors.redAccent,
        );
        break;
      case PemberkasanFeedbackType.none:
        break;
    }
  }

  Future<void> _showAddDocumentDialog() async {
    final result = await showDialog<_DocumentFormResult>(
      context: context,
      barrierDismissible: !_viewModel.isUploading,
      builder: (context) => const _AddDocumentDialog(),
    );
    if (result == null) return;
    final feedback = await _viewModel.uploadDocument(
      PemberkasanUploadInput(
        title: result.title,
        file: result.file,
        notes: result.notes,
        expiresAt: result.expiresAt,
        reminderInterval: result.reminderInterval,
      ),
    );
    if (!mounted) return;
    _showFeedback(feedback);
  }

  Future<void> _confirmDeleteDocument(DocumentRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: !_viewModel.isDeleting(record.id),
      builder: (context) => _GlassConfirmDialog(
        title: 'Hapus dokumen?',
        message:
            'Dokumen "${record.title}" akan dihapus dan tidak dapat dikembalikan.',
        confirmLabel: 'Hapus',
        cancelLabel: 'Batal',
      ),
    );
    if (confirmed != true) return;
    await _deleteDocument(record);
  }

  Future<void> _deleteDocument(DocumentRecord record) async {
    final feedback = await _viewModel.deleteDocument(record);
    if (!mounted) return;
    _showFeedback(feedback);
  }

  Future<void> _openDocumentUrl(String url) async {
    if (url.isEmpty) {
      if (!mounted) return;
      _showGlassSnackBar(
        context,
        'Tautan dokumen tidak tersedia.',
        icon: Icons.link_off,
        tintColor: Colors.amberAccent,
      );
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      _showGlassSnackBar(
        context,
        'Tautan dokumen tidak valid.',
        icon: Icons.link_off,
        tintColor: Colors.amberAccent,
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      _showGlassSnackBar(
        context,
        'Gagal membuka dokumen.',
        icon: Icons.error_outline,
        tintColor: Colors.redAccent,
      );
    }
  }
}

class _AddDocumentDialog extends StatefulWidget {
  const _AddDocumentDialog();

  @override
  State<_AddDocumentDialog> createState() => _AddDocumentDialogState();
}

class _AddDocumentDialogState extends State<_AddDocumentDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime? _expiresAt;
  Duration? _reminderInterval;
  PlatformFile? _file;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  InputDecoration _dialogInputDecoration({
    required String label,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: Colors.white.withOpacity(0.12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white70, width: 1.1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                color: Colors.white.withOpacity(0.12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.28),
                  width: 1.2,
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tambah Dokumen',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _titleController,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: Colors.white,
                        decoration: _dialogInputDecoration(
                          label: 'Nama Dokumen',
                          hint: 'mis. KTP, Kontrak Kerja',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nama dokumen wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesController,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: Colors.white,
                        decoration: _dialogInputDecoration(
                          label: 'Catatan (opsional)',
                          hint: 'Keterangan tambahan',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      _DateField(
                        label: 'Tanggal Kedaluwarsa',
                        value: _expiresAt,
                        onTap: _pickExpiryDate,
                      ),
                      if (_expiresAt != null) ...[
                        const SizedBox(height: 12),
                        _ReminderDropdown(
                          value: _reminderInterval,
                          enabled: _expiresAt != null,
                          onChanged: (value) {
                            setState(() => _reminderInterval = value);
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      _FilePickerRow(fileName: _file?.name, onPick: _pickFile),
                      const SizedBox(height: 22),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 12,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text(
                                'Batal',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _submit,
                              icon: const Icon(Icons.cloud_upload_outlined),
                              label: const Text('Simpan'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      withData: kIsWeb,
      type: FileType.any,
    );
    if (res == null || res.files.isEmpty) return;
    setState(() => _file = res.files.first);
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final initial = _expiresAt ?? now.add(const Duration(days: 30));
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: DateTime(now.year + 10),
    );
    if (selected != null) {
      setState(() {
        _expiresAt = selected;
        _reminderInterval ??= const Duration(days: 90);
      });
    }
  }

  void _submit() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;
    if (_file == null) {
      _showGlassSnackBar(
        context,
        'Silakan pilih file dokumen.',
        icon: Icons.attach_file,
        tintColor: Colors.amberAccent,
      );
      return;
    }
    Navigator.of(context).pop(
      _DocumentFormResult(
        title: _titleController.text,
        notes: _notesController.text,
        file: _file!,
        expiresAt: _expiresAt,
        reminderInterval: _expiresAt != null ? _reminderInterval : null,
      ),
    );
  }
}

class _DocumentFormResult {
  _DocumentFormResult({
    required this.title,
    required this.file,
    this.notes,
    this.expiresAt,
    this.reminderInterval,
  });

  final String title;
  final PlatformFile file;
  final String? notes;
  final DateTime? expiresAt;
  final Duration? reminderInterval;
}

class _ReminderDropdown extends StatelessWidget {
  const _ReminderDropdown({
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final Duration? value;
  final ValueChanged<Duration?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    const options = <Duration?>[
      null,
      Duration(days: 30),
      Duration(days: 60),
      Duration(days: 90),
      Duration(days: 180),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pengingat sebelum kedaluwarsa',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Pengingat akan dikirim secara berkala sebelum tanggal akhir',
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.24)),
          ),
          child: DropdownButton<Duration?>(
            isExpanded: true,
            value: value,
            dropdownColor: const Color(0xFF1B2645),
            iconEnabledColor: Colors.white,
            style: const TextStyle(color: Colors.white),
            underline: const SizedBox.shrink(),
            items: options
                .map(
                  (option) => DropdownMenuItem<Duration?>(
                    value: option,
                    enabled: enabled,
                    child: Text(_labelFor(option)),
                  ),
                )
                .toList(growable: false),
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ],
    );
  }

  static String _labelFor(Duration? value) {
    if (value == null) return 'Tidak ada pengingat';
    final months = (value.inDays / 30).round();
    if (months >= 12) return 'Setiap 12 bulan';
    if (months == 6) return 'Setiap 6 bulan';
    if (months == 3) return 'Setiap 3 bulan';
    if (months == 2) return 'Setiap 2 bulan';
    if (months == 1) return 'Setiap 1 bulan';
    final weeks = (value.inDays / 7).round();
    if (weeks >= 1) return 'Setiap $weeks minggu';
    return 'Setiap ${value.inDays} hari';
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final display = value == null ? 'Belum dipilih' : _formatDate(value!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(display, style: const TextStyle(color: Colors.white)),
                const Icon(Icons.event, color: Colors.white70),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final local = date.toLocal();
    final month = months[(local.month - 1).clamp(0, months.length - 1)];
    return '${local.day} $month ${local.year}';
  }
}

class _FilePickerRow extends StatelessWidget {
  const _FilePickerRow({required this.fileName, required this.onPick});

  final String? fileName;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'File Dokumen',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.24)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  fileName ?? 'Belum ada file dipilih',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              TextButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.attach_file, color: Colors.white),
                label: const Text(
                  'Pilih',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlassConfirmDialog extends StatelessWidget {
  const _GlassConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white.withOpacity(0.14),
              border: Border.all(
                color: Colors.white.withOpacity(0.28),
                width: 1.2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withOpacity(0.85),
                        backgroundColor: Colors.white.withOpacity(0.08),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.24),
                          ),
                        ),
                      ),
                      child: Text(cancelLabel),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.redAccent.withOpacity(0.4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: Colors.redAccent.withOpacity(0.6),
                          ),
                        ),
                      ),
                      child: Text(confirmLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.record,
    required this.onTap,
    required this.onDelete,
    required this.isDeleting,
  });

  final DocumentRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    final reminder = record.reminderIntervalDays != null
        ? _ReminderDropdown._labelFor(
            Duration(days: record.reminderIntervalDays!),
          )
        : null;
    final notes = record.raw['notes']?.toString();
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDeleting ? null : onTap,
        borderRadius: BorderRadius.circular(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.22)),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.18),
                    Colors.white.withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF38BDF8), Color(0xFF6366F1)],
                          ),
                        ),
                        child: const Icon(
                          Icons.insert_drive_file_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (record.originalFileName != null &&
                                record.originalFileName!.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  record.originalFileName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 32,
                            width: 32,
                            child: Icon(
                              Icons.open_in_new,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(width: 2),
                          isDeleting
                              ? const SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white70,
                                            ),
                                      ),
                                    ),
                                  ),
                                )
                              : IconButton(
                                  onPressed: onDelete,
                                  tooltip: 'Hapus dokumen',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  splashRadius: 20,
                                  visualDensity: VisualDensity.compact,
                                  alignment: Alignment.center,
                                  iconSize: 20,
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (record.expiresAt != null)
                        _InfoBadge(
                          icon: Icons.event,
                          label:
                              'Kedaluwarsa ${_formatDate(record.expiresAt!)}',
                        ),
                      if (reminder != null)
                        _InfoBadge(icon: Icons.alarm, label: reminder),
                      _InfoBadge(
                        icon: Icons.upload,
                        label: 'Diunggah ${_formatDate(record.createdAt)}',
                      ),
                    ],
                  ),
                  if (notes != null && notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      notes.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final local = date.toLocal();
    final month = months[(local.month - 1).clamp(0, months.length - 1)];
    return '${local.day} $month ${local.year}';
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.12),
        border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white.withOpacity(0.75)),
          const SizedBox(width: 6),
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignInNotice extends StatelessWidget {
  const _SignInNotice();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.lock, color: Colors.white70, size: 52),
            SizedBox(height: 12),
            Text(
              'Silakan masuk untuk mengakses fitur pemberkasan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.folder_off, size: 52, color: Colors.white.withOpacity(0.75)),
        const SizedBox(height: 12),
        Text(
          'Belum ada dokumen pemberkasan.',
          style: textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tambahkan berkas untuk mulai mengelola pengingat.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: Colors.white.withOpacity(0.85),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.warning_amber_rounded,
          size: 48,
          color: Colors.white.withOpacity(0.85),
        ),
        const SizedBox(height: 12),
        Text(
          'Terjadi kesalahan',
          style: textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: Colors.white.withOpacity(0.85),
          ),
        ),
      ],
    );
  }
}

void _showGlassSnackBar(
  BuildContext context,
  String message, {
  IconData? icon,
  Color? tintColor,
  Duration duration = const Duration(seconds: 4),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();

  final baseColor = tintColor ?? const Color(0xFF1565C0);
  const borderRadius = BorderRadius.all(Radius.circular(20));

  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: duration,
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      content: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 16),
            child: child,
          ),
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    baseColor.withOpacity(0.55),
                    baseColor.withOpacity(0.28),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.45),
                  width: 1.0,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 22),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
