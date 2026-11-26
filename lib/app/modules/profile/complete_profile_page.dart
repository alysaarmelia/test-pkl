import 'dart:io';
import 'package:cipta_vera_mandiri_digital/app/modules/home/homeview/home_theme.dart';
import 'package:cipta_vera_mandiri_digital/app/widgets/glass_snack_bar.dart';
import 'package:cipta_vera_mandiri_digital/repositories/complete_profile_repository.dart';
import 'package:cipta_vera_mandiri_digital/view_models/complete_profile_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:ui' show ImageFilter;

class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key, this.repository, this.viewModel});

  final CompleteProfileRepository? repository;
  final CompleteProfileViewModel? viewModel;

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  late final CompleteProfileViewModel _viewModel;
  late final String _viewModelTag;
  File? _imageFile;
  bool _loading = false;
  final List<String> _divisionOptions = const [
    'Purchasing and Logistik',
    'Administrations',
    'Finance',
    'Project Officer',
    'Heavy Equipment',
    'Head Officer',
  ];
  String? _selectedDivision;
  List<String> get _divisionDropdownItems {
    if (_selectedDivision == null ||
        !_divisionOptions.contains(_selectedDivision)) {
      return _divisionOptions;
    }
    return [
      _selectedDivision!,
      ..._divisionOptions.where((opt) => opt != _selectedDivision),
    ];
  }

  @override
  void initState() {
    super.initState();
    _viewModelTag = 'complete-profile-${identityHashCode(this)}';
    _viewModel = Get.put(
        widget.viewModel ??
            CompleteProfileViewModel(
              repository: widget.repository ?? CompleteProfileRepositoryImpl(),
            ),
        tag: _viewModelTag,
    );
    _loadPin();
  }

  @override
  void dispose() {
    if (Get.isRegistered<CompleteProfileViewModel>(tag: _viewModelTag)) {
      Get.delete<CompleteProfileViewModel>(tag: _viewModelTag, force: true);
    }
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loadPin() async {
    final result = await _viewModel.loadOrGeneratePin();
    if (!mounted) return;

    if (result.success && (result.pin ?? '').isNotEmpty) {
      setState(() {
        _pinController.text = result.pin!;
      });
      return;
    }

    if (_pinController.text.isEmpty) {
      setState(() {
        _pinController.text = 'PIN belum tersedia';
      });
      showGlassSnackBar(
        context,
        message:
            result.message ??
            'Tidak dapat membuat PIN. Coba lagi atau hubungi admin.',
        tone: GlassSnackTone.error,
      );
    }
  }

  Future<void> _pickFrom(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;

      // Crop image setelah dipilih
      CroppedFile? cropped;
      try {
        cropped = await ImageCropper().cropImage(
          sourcePath: picked.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Foto',
              toolbarColor: Color(0xFF007BC1),
              toolbarWidgetColor: Colors.white,
              hideBottomControls: false,
              lockAspectRatio: false,
            ),
            IOSUiSettings(title: 'Crop Foto', aspectRatioLockEnabled: false),
          ],
        );
      } catch (e, st) {
        debugPrint('Crop gagal: $e');
        debugPrint('$st');
      }

      if (!mounted) return;
      setState(() {
        _imageFile = File((cropped?.path) ?? picked.path);
      });
    } on PlatformException catch (e, st) {
      debugPrint('Pick image error: $e');
      debugPrint('$st');
      if (mounted) {
        showGlassSnackBar(
          context,
          message: 'Tidak bisa membuka kamera/galeri (${e.code}).',
          tone: GlassSnackTone.error,
        );
      }
    } catch (e, st) {
      debugPrint('Pick image unexpected error: $e');
      debugPrint('$st');
      if (mounted) {
        showGlassSnackBar(
          context,
          message: 'Tidak bisa memuat foto. Coba lagi.',
          tone: GlassSnackTone.error,
        );
      }
    }
  }

  Future<void> _pickImage() async {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Ambil dari Kamera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFrom(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Pilih dari Galeri'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFrom(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
    });

    try {
      final feedback = await _viewModel.saveProfile(
        name: _nameController.text,
        division: _selectedDivision ?? '',
        pin: _pinController.text,
        imageFile: _imageFile,
      );

      if (!mounted) return;

      if (feedback.type == CompleteProfileFeedbackType.success) {
        Navigator.pushReplacementNamed(context, '/home');
      } else if (feedback.type != CompleteProfileFeedbackType.none) {
        _showFeedback(feedback);
      }
    } catch (e) {
      debugPrint('Error simpan profil: $e');
      if (mounted) {
        showGlassSnackBar(
          context,
          message: 'Gagal menyimpan profil: $e',
          tone: GlassSnackTone.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _showFeedback(CompleteProfileFeedback feedback) {
    if (!mounted || feedback.type == CompleteProfileFeedbackType.none) {
      return;
    }

    final tone = switch (feedback.type) {
      CompleteProfileFeedbackType.success => GlassSnackTone.success,
      CompleteProfileFeedbackType.info => GlassSnackTone.info,
      CompleteProfileFeedbackType.warning => GlassSnackTone.warning,
      CompleteProfileFeedbackType.error => GlassSnackTone.error,
      CompleteProfileFeedbackType.none => GlassSnackTone.info,
    };

    showGlassSnackBar(context, message: feedback.message, tone: tone);
  }

  Widget _glassField(
    String hint,
    IconData icon,
    TextEditingController ctrl, {
    String? Function(String?)? validator,
    bool obscure = false,
    bool readOnly = false,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: hint.toLowerCase() == 'email'
          ? TextInputType.emailAddress
          : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      readOnly: readOnly,
      enabled: enabled,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.2),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
      validator: validator,
    );
  }

  Widget _glassDropdown(
    String hint,
    IconData icon,
    List<String> options, {
    required String? value,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withOpacity(0.45),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: DropdownButtonHideUnderline(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: DropdownButtonFormField<String>(
                  hint: Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  value: value,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.arrow_drop_down_rounded,
                    color: Colors.white,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: Colors.black,
                  selectedItemBuilder: (ctx) => options
                      .map(
                        (opt) => Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            opt,
                            maxLines: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    prefixIcon: Icon(icon, color: Colors.white),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onChanged: _loading ? null : onChanged,
                  validator: validator,
                  items: options
                      .map(
                        (opt) => DropdownMenuItem<String>(
                          value: opt,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 4,
                            ),
                            child: Text(
                              opt,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
        title: const Text(
          'Lengkapi Data Diri Anda',
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: Colors.white.withOpacity(0.15)),
        ),
      ),
      body: HomeGlassTheme.background(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 32,
              right: 32,
              top: 24,
              bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 90),

                  // Avatar
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 56,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        backgroundImage: _imageFile != null
                            ? FileImage(_imageFile!)
                            : null,
                        child: _imageFile == null
                            ? const Icon(
                                Icons.person,
                                size: 56,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: _loading ? null : _pickImage,
                          icon: const Icon(Icons.edit, color: Colors.black87),
                          tooltip: 'Ganti foto',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  // Tombol kamera & galeri
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Kamera (glass button)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            width: 140,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.32),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                                width: 1.2,
                              ),
                            ),
                            child: TextButton.icon(
                              onPressed: _loading
                                  ? null
                                  : () => _pickFrom(ImageSource.camera),
                              icon: const Icon(
                                Icons.photo_camera,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Kamera',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Galeri (glass button)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            width: 140,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.32),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                                width: 1.2,
                              ),
                            ),
                            child: TextButton.icon(
                              onPressed: _loading
                                  ? null
                                  : () => _pickFrom(ImageSource.gallery),
                              icon: const Icon(
                                Icons.photo_library,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Galeri',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // Heading di atas form
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Masukan data diri :',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Nama Lengkap
                  _glassField(
                    'Nama Lengkap',
                    Icons.person,
                    _nameController,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Nama wajib diisi'
                        : null,
                  ),

                  const SizedBox(height: 10),
                  // Divisi (dropdown)
                  _glassDropdown(
                    'Pilih Divisi',
                    Icons.badge_outlined,
                    _divisionDropdownItems,
                    value: _selectedDivision,
                    onChanged: (value) {
                      setState(() {
                        _selectedDivision = value;
                      });
                    },
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Divisi wajib dipilih'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  // PIN (read-only, auto-generated)
                  _glassField(
                    'PIN (otomatis)',
                    Icons.vpn_key,
                    _pinController,
                    enabled: false,
                  ),

                  const SizedBox(height: 50),
                  // Tombol Simpan (match Sign Up style)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        width: 220,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.32),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                            width: 1.2,
                          ),
                        ),
                        child: TextButton(
                          onPressed: _loading ? null : _saveProfile,
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Simpan',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      const SizedBox(height: 70),
                      Text(
                        'Powered by',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'lib/app/assets/images/cvm.png',
                            height: 20,
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
                      const SizedBox(height: 0),
                    ],
                  ),
                  const SizedBox(height: 0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
