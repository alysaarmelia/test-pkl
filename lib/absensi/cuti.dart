import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:cipta_vera_mandiri_digital/app/modules/home/homeview/home_theme.dart';
import 'package:cipta_vera_mandiri_digital/app/widgets/glass_snack_bar.dart';
import 'package:cipta_vera_mandiri_digital/view_models/leave_page_view_model.dart';

class LeavePage extends StatefulWidget {
  const LeavePage({super.key});
  static const routeName = '/leave';

  @override
  State<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage> {
  final _formKey = GlobalKey<FormState>();
  DateTime? startDate;
  DateTime? endDate;
  final reasonCtrl = TextEditingController();
  final List<PlatformFile> _attachments = <PlatformFile>[];
  bool _saving = false;
  late final LeavePageViewModel _leaveViewModel;
  late final String _viewModelTag;

  @override
  void initState() {
    super.initState();
    _viewModelTag = 'leave-page-${identityHashCode(this)}';
    _leaveViewModel = Get.put(LeavePageViewModel(), tag: _viewModelTag);
  }

  @override
  void dispose() {
    if (Get.isRegistered<LeavePageViewModel>(tag: _viewModelTag)) {
      Get.delete<LeavePageViewModel>(tag: _viewModelTag, force: true);
    }
    reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
        } else {
          endDate = picked;
        }
      });
    }
  }

  Future<void> _pickAttachments() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: kIsWeb,
      type: FileType.any,
    );
    if (res == null || res.files.isEmpty) return;
    setState(() => _attachments.addAll(res.files));
  }

  void _removeAttachment(int index) {
    if (index < 0 || index >= _attachments.length) return;
    setState(() {
      _attachments.removeAt(index);
    });
  }

  String _formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '-';
    const kb = 1024;
    const mb = kb * 1024;
    if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(2)} MB';
    }
    return '${(bytes / kb).toStringAsFixed(1)} KB';
  }

  Widget _glassCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1,
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
    final btn = ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.45),
              width: 1.2,
            ),
          ),
          child: TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onPressed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return btn;
  }

  Future<void> _submitCuti() async {
    if (!_formKey.currentState!.validate()) {
      showGlassSnackBar(
        context,
        message: 'Lengkapi data cuti terlebih dahulu',
        tone: GlassSnackTone.warning,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final feedback = await _leaveViewModel.submitLeaveRequest(
        startDate: startDate,
        endDate: endDate,
        reason: reasonCtrl.text.trim(),
        attachments: List<PlatformFile>.from(_attachments),
      );

      if (!mounted) return;
      FocusScope.of(context).unfocus();
      switch (feedback.type) {
        case LeavePageFeedbackType.success:
          showGlassSnackBar(
            context,
            message: feedback.message,
            tone: GlassSnackTone.success,
          );
          if (feedback.shouldResetForm) {
            setState(() {
              startDate = null;
              endDate = null;
              reasonCtrl.clear();
              _attachments.clear();
            });
          }
          break;
        case LeavePageFeedbackType.warning:
          showGlassSnackBar(
            context,
            message: feedback.message,
            tone: GlassSnackTone.warning,
          );
          break;
        case LeavePageFeedbackType.error:
          showGlassSnackBar(
            context,
            message: feedback.message,
            tone: GlassSnackTone.error,
          );
          break;
        case LeavePageFeedbackType.none:
          break;
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w600,
    );

    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Pengajuan Cuti',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: HomeGlassTheme.background(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + keyboardInset),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 32,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          Text(
                            'Lengkapi Data Cuti',
                            style: titleStyle.copyWith(fontSize: 18),
                          ),
                          const SizedBox(height: 10),
                          _glassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tanggal',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _glassCard(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: ListTile(
                                    leading: const Icon(
                                      Icons.date_range,
                                      color: Colors.white,
                                    ),
                                    title: Text(
                                      startDate == null
                                          ? 'Tanggal mulai'
                                          : 'Mulai: ${startDate!.toLocal().toString().split(' ').first}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    onTap: () => _pickDate(isStart: true),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _glassCard(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: ListTile(
                                    leading: const Icon(
                                      Icons.event,
                                      color: Colors.white,
                                    ),
                                    title: Text(
                                      endDate == null
                                          ? 'Tanggal selesai'
                                          : 'Selesai: ${endDate!.toLocal().toString().split(' ').first}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    onTap: () => _pickDate(isStart: false),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _glassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Alasan Cuti',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: reasonCtrl,
                                  maxLines: 4,
                                  keyboardType: TextInputType.multiline,
                                  keyboardAppearance: Brightness.light,
                                  onTapOutside: (_) =>
                                      FocusScope.of(context).unfocus(),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'Tuliskan alasan cuti Anda',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withValues(
                                      alpha: 0.2,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 14,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                      ? 'Wajib diisi'
                                      : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _glassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Lampiran Pendukung',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Unggah surat sakit atau dokumen pendukung cuti lainnya (opsional).',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.78),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (_attachments.isEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.18,
                                        ),
                                      ),
                                    ),
                                    child: const Text(
                                      'Belum ada lampiran dipilih.',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  )
                                else
                                  Column(
                                    children: _attachments
                                        .asMap()
                                        .entries
                                        .map(
                                          (entry) => Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(
                                                alpha: 0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: Colors.white.withValues(
                                                  alpha: 0.2,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.attach_file,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        entry.value.name,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        _formatSize(
                                                          entry.value.size,
                                                        ),
                                                        style: TextStyle(
                                                          color: Colors.white
                                                              .withValues(
                                                                alpha: 0.78,
                                                              ),
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  tooltip: 'Hapus lampiran',
                                                  onPressed: _saving
                                                      ? null
                                                      : () => _removeAttachment(
                                                          entry.key,
                                                        ),
                                                  icon: const Icon(
                                                    Icons.close,
                                                    color: Colors.white70,
                                                    size: 18,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.center,
                                  child: TextButton.icon(
                                    onPressed: _saving
                                        ? null
                                        : _pickAttachments,
                                    icon: const Icon(
                                      Icons.upload_file,
                                      color: Colors.white,
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: Colors.white.withValues(
                                            alpha: 0.28,
                                          ),
                                        ),
                                      ),
                                    ),
                                    label: const Text('Tambah Lampiran'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 120),
                          _glassButton(
                            onPressed: _saving ? null : _submitCuti,
                            label: _saving ? 'Mengirim…' : 'Ajukan Cuti',
                            icon: Icons.send,
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  'Powered by',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      'lib/app/assets/images/cvm.png',
                                      height: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Cipta Vera Mandiri Digital',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
