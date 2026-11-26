// ================= Izin Page =================
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:cipta_vera_mandiri_digital/app/modules/home/homeview/home_theme.dart';
import 'package:cipta_vera_mandiri_digital/app/widgets/glass_snack_bar.dart';
import 'package:cipta_vera_mandiri_digital/view_models/permission_page_view_model.dart';

class PermissionPage extends StatefulWidget {
  const PermissionPage({super.key});
  static const routeName = '/permission';

  @override
  State<PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends State<PermissionPage> {
  final _formKey = GlobalKey<FormState>();
  final reasonCtrl = TextEditingController();
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  late final PermissionPageViewModel _permissionViewModel;
  late final String _viewModelTag;
  DateTime? requestDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _viewModelTag = 'permission-page-${identityHashCode(this)}';
    _permissionViewModel = Get.put(
      PermissionPageViewModel(),
      tag: _viewModelTag,
    );
    requestDate = DateTime.now();
  }

  Future<void> _submitIzin() async {
    if (!_formKey.currentState!.validate()) {
      showGlassSnackBar(
        context,
        message: 'Lengkapi data izin terlebih dahulu',
        tone: GlassSnackTone.warning,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final feedback = await _permissionViewModel.submitPermissionRequest(
        requestDate: requestDate,
        startTime: startTime,
        endTime: endTime,
        reason: reasonCtrl.text.trim(),
        formatTimeText: (time) => time.format(context),
        formatDateText: _formatDate,
      );

      if (!mounted) return;
      FocusScope.of(context).unfocus();
      switch (feedback.type) {
        case PermissionPageFeedbackType.success:
          showGlassSnackBar(
            context,
            message: feedback.message,
            tone: GlassSnackTone.success,
          );
          if (feedback.shouldResetForm) {
            setState(() {
              requestDate = null;
              startTime = null;
              endTime = null;
              reasonCtrl.clear();
            });
          }
          break;
        case PermissionPageFeedbackType.warning:
          showGlassSnackBar(
            context,
            message: feedback.message,
            tone: GlassSnackTone.warning,
          );
          break;
        case PermissionPageFeedbackType.error:
          showGlassSnackBar(
            context,
            message: feedback.message,
            tone: GlassSnackTone.error,
          );
          break;
        case PermissionPageFeedbackType.none:
          break;
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    if (Get.isRegistered<PermissionPageViewModel>(tag: _viewModelTag)) {
      Get.delete<PermissionPageViewModel>(tag: _viewModelTag, force: true);
    }
    reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: requestDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() => requestDate = picked);
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startTime = picked;
        } else {
          endTime = picked;
        }
      });
    }
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year.toString().padLeft(4, '0')}';
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
    return ClipRRect(
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
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Form Izin',
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
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      16 + keyboardInset,
                    ),
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
                            const Text(
                              'Lengkapi Data Izin',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
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
                                        Icons.event,
                                        color: Colors.white,
                                      ),
                                      title: Text(
                                        requestDate == null
                                            ? 'Pilih tanggal'
                                            : 'Tanggal: ${_formatDate(requestDate!)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                      onTap: _pickDate,
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
                                    'Jam',
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
                                        Icons.access_time,
                                        color: Colors.white,
                                      ),
                                      title: Text(
                                        startTime == null
                                            ? 'Jam mulai'
                                            : 'Mulai: ${startTime!.format(context)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                      onTap: () => _pickTime(isStart: true),
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
                                        Icons.timer_off,
                                        color: Colors.white,
                                      ),
                                      title: Text(
                                        endTime == null
                                            ? 'Jam selesai'
                                            : 'Selesai: ${endTime!.format(context)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                      onTap: () => _pickTime(isStart: false),
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
                                    'Alasan Izin',
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
                                      hintText: 'Tuliskan alasan izin Anda',
                                      hintStyle: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
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
                            const SizedBox(height: 20),
                            _glassButton(
                              onPressed: _saving ? null : _submitIzin,
                              label: _saving ? 'Mengirim…' : 'Ajukan Izin',
                              icon: Icons.send,
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    'Powered by',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
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
      ),
    );
  }
}
