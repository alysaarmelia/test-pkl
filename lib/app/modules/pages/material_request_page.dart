import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:cipta_vera_mandiri_digital/app/modules/home/homeview/home_theme.dart';

import '../../../repositories/material_request_page_repository.dart';
import '../../../view_models/material_request_page_view_model.dart';
import '../../widgets/glass_snack_bar.dart';

class MaterialRequestPage extends StatefulWidget {
  const MaterialRequestPage({super.key});

  @override
  State<MaterialRequestPage> createState() => _MaterialRequestPageState();
}

class _MaterialRequestPageState extends State<MaterialRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _projectController = TextEditingController();
  final _requesterController = TextEditingController();
  final List<_MaterialItemField> _items = <_MaterialItemField>[];

  late final String _materialRequestViewModelTag;
  late final MaterialRequestPageViewModel _viewModel;
  late final Worker _requesterSyncWorker;
  late final Worker _companySyncWorker;

  @override
  void initState() {
    super.initState();
    _materialRequestViewModelTag = 'material-request-${identityHashCode(this)}';
    _viewModel = Get.put(
      MaterialRequestPageViewModel(
        repository: MaterialRequestPageRepositoryImpl(),
      ),
      tag: _materialRequestViewModelTag,
    );
    _requesterSyncWorker = ever<String>(_viewModel.requesterName, (value) {
      if (_requesterController.text == value) return;
      _requesterController.text = value;
    });
    _companySyncWorker = ever<String>(_viewModel.selectedCompany, (value) {
      if (value == MaterialRequestPageViewModel.manualCompanyLabel) return;
      if (_companyController.text == value) return;
      _companyController.text = value;
    });
    if (!_viewModel.isManualCompany) {
      _companyController.text = _viewModel.selectedCompany.value;
    }
    _addItem();
  }

  @override
  void dispose() {
    _requesterSyncWorker.dispose();
    _companySyncWorker.dispose();
    if (Get.isRegistered<MaterialRequestPageViewModel>(
      tag: _materialRequestViewModelTag,
    )) {
      Get.delete<MaterialRequestPageViewModel>(
        tag: _materialRequestViewModelTag,
        force: true,
      );
    }
    _companyController.dispose();
    _projectController.dispose();
    _requesterController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem({String name = '', String quantity = ''}) {
    setState(() {
      _items.add(
        _MaterialItemField(
          nameController: TextEditingController(text: name),
          quantityController: TextEditingController(text: quantity),
        ),
      );
    });
  }

  void _removeItem(int index) {
    if (_items.length <= 1) {
      showGlassSnackBar(
        context,
        message: 'Minimal satu item material diperlukan.',
        tone: GlassSnackTone.warning,
      );
      return;
    }
    final removed = _items.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDate: _viewModel.requestDate.value ?? now,
    );
    if (selected != null) {
      _viewModel.setRequestDate(selected);
    }
  }

  Future<void> _submit() async {
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) return;

    final inputs = _items
        .map(
          (entry) => MaterialRequestItemInput(
            name: entry.nameController.text,
            quantity: entry.quantityController.text,
          ),
        )
        .toList(growable: false);

    FocusScope.of(context).unfocus();
    final feedback = await _viewModel.submit(
      companyName: _companyController.text.trim(),
      projectName: _projectController.text.trim(),
      requester: _requesterController.text.trim(),
      date: _viewModel.requestDate.value,
      inputs: inputs,
    );

    if (!mounted || feedback.type == MaterialRequestFeedbackType.none) return;

    final tone = switch (feedback.type) {
      MaterialRequestFeedbackType.success => GlassSnackTone.success,
      MaterialRequestFeedbackType.warning => GlassSnackTone.warning,
      MaterialRequestFeedbackType.error => GlassSnackTone.error,
      MaterialRequestFeedbackType.none => GlassSnackTone.info,
    };

    if (feedback.message.isNotEmpty) {
      showGlassSnackBar(context, message: feedback.message, tone: tone);
    }

    if (feedback.shouldClosePage) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSubmitting = _viewModel.isSubmitting.value;
      return Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Permintaan Material',
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
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    const Text(
                      'Lengkapi Permintaan Material',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _glassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Informasi Umum',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _buildCompanyField(),
                                const SizedBox(height: 14),
                                _buildTextField(
                                  label: 'Nama Proyek',
                                  hint: 'Tuliskan nama proyek',
                                  controller: _projectController,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Isi nama proyek.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                _buildDateField(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _glassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Daftar Material',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ..._items.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final item = entry.value;
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: index == _items.length - 1
                                          ? 0
                                          : 12,
                                    ),
                                    child: _MaterialItemCard(
                                      index: index,
                                      field: item,
                                      onRemove: () => _removeItem(index),
                                    ),
                                  );
                                }),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: TextButton.icon(
                                    onPressed: () => _addItem(),
                                    icon: const Icon(
                                      Icons.add,
                                      color: Colors.white,
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      backgroundColor: Colors.white.withOpacity(
                                        0.12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: Colors.white.withOpacity(0.35),
                                        ),
                                      ),
                                    ),
                                    label: const Text('Tambah Material'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _glassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tanda Tangan',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _buildTextField(
                                  label: 'Nama Pengorder Lapangan',
                                  hint: 'Tuliskan nama pengorder lapangan',
                                  controller: _requesterController,
                                  readOnly: true,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Isi nama pengorder lapangan.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Nama mengetahui dari kantor akan terisi otomatis saat disetujui admin.',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _glassButton(
                      onPressed: isSubmitting ? null : _submit,
                      label: isSubmitting ? 'Mengirim…' : 'Kirim Permintaan',
                      icon: Icons.send,
                      showProgress: isSubmitting,
                    ),
                    const SizedBox(height: 12),
                    _buildPoweredBy(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildCompanyField() {
    final isManualCompany = _viewModel.isManualCompany;
    final selectedCompany = _viewModel.selectedCompany.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nama PT / CV',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        if (isManualCompany)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RepaintBoundary(
                child: TextFormField(
                  controller: _companyController,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  maxLines: 1,
                  style: const TextStyle(color: Colors.white),
                  decoration:
                      _glassInputDecoration(
                        'Tuliskan nama perusahaan (bisa diketik)',
                      ).copyWith(
                        suffixIcon: const Icon(
                          Icons.edit,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Isi nama perusahaan.';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    final defaultCompany =
                        MaterialRequestPageViewModel.companyOptions.first;
                    _viewModel.resetCompanyToDefault();
                    _companyController.text = defaultCompany;
                  },
                  icon: const Icon(Icons.list_alt, color: Colors.white70),
                  label: const Text(
                    'Pilih dari daftar',
                    style: TextStyle(color: Colors.white70),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: Colors.white70,
                  ),
                ),
              ),
            ],
          )
        else
          FormField<String>(
            initialValue: selectedCompany,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Pilih nama perusahaan.';
              }
              return null;
            },
            builder: (state) {
              return SizedBox(
                width: double.infinity,
                child: PopupMenuButton<String>(
                  initialValue: selectedCompany,
                  padding: EdgeInsets.zero,
                  position: PopupMenuPosition.under,
                  offset: const Offset(0, 6),
                  color: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onSelected: (value) {
                    _viewModel.selectCompany(value);
                    if (_viewModel.isManualCompany) {
                      _companyController.clear();
                    } else {
                      _companyController.text = value;
                    }
                    state.didChange(value);
                  },
                  itemBuilder: (context) => _viewModel.companyOptionsWithManual
                      .map(
                        (opt) => PopupMenuItem<String>(
                          value: opt,
                          child: Text(
                            opt,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      )
                      .toList(),
                  child: InputDecorator(
                    decoration: _glassInputDecoration('Pilih nama perusahaan')
                        .copyWith(
                          errorText: state.errorText,
                          suffixIcon: const Icon(
                            Icons.arrow_drop_down_rounded,
                            color: Colors.white,
                          ),
                        ),
                    isEmpty: selectedCompany.isEmpty,
                    child: Text(
                      selectedCompany,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
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
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.35), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _glassButton({
    required VoidCallback? onPressed,
    required String label,
    IconData icon = Icons.send,
    bool showProgress = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.28),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withOpacity(0.45),
              width: 1.2,
            ),
          ),
          child: TextButton(
            onPressed: onPressed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (showProgress)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
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

  InputDecoration _glassInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.white.withOpacity(0.6),
          width: 1.2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextCapitalization capitalization = TextCapitalization.none,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          textCapitalization: capitalization,
          style: const TextStyle(color: Colors.white),
          readOnly: readOnly,
          enableInteractiveSelection: !readOnly,
          decoration: _glassInputDecoration(hint).copyWith(
            suffixIcon: readOnly
                ? const Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: Colors.white70,
                  )
                : null,
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDateField() {
    final requestDate = _viewModel.requestDate.value;
    final display = requestDate == null
        ? 'Pilih tanggal permintaan'
        : '${requestDate.day.toString().padLeft(2, '0')}-'
              '${requestDate.month.toString().padLeft(2, '0')}-'
              '${requestDate.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tanggal Permintaan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.35),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    display,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(Icons.calendar_today, size: 18, color: Colors.white),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPoweredBy() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Powered by',
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('lib/app/assets/images/cvm.png', height: 18),
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
    );
  }
}

class _MaterialItemField {
  _MaterialItemField({
    required this.nameController,
    required this.quantityController,
  });

  final TextEditingController nameController;
  final TextEditingController quantityController;

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
  }
}

class _MaterialItemCard extends StatelessWidget {
  const _MaterialItemCard({
    required this.index,
    required this.field,
    required this.onRemove,
  });

  final int index;
  final _MaterialItemField field;
  final VoidCallback onRemove;

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.white.withOpacity(0.6),
          width: 1.2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Material ${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onRemove,
                tooltip: 'Hapus material ini',
                icon: const Icon(Icons.delete_outline, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: field.nameController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Jenis material'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: field.quantityController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Jumlah / satuan'),
          ),
        ],
      ),
    );
  }
}
