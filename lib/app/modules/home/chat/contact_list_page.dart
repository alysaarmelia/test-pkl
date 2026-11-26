// lib/app/modules/home/chat/contact_list_page.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:cipta_vera_mandiri_digital/app/services/avatar_thumbnail_cache_service.dart';
import 'package:cipta_vera_mandiri_digital/app/widgets/glass_snack_bar.dart';
import 'package:cipta_vera_mandiri_digital/app/modules/home/chat/chat_page.dart';
import 'package:cipta_vera_mandiri_digital/repositories/contact_list_repository.dart';
import 'package:cipta_vera_mandiri_digital/view_models/contact_list_view_model.dart';
import 'package:get/get.dart';

class ContactListPage extends StatefulWidget {
  final String? chatId;
  final bool isGroup;
  final ContactListRepository? repository;
  final ContactListViewModel? viewModel;
  final Future<String?> Function()? pinScanner;

  const ContactListPage({
    super.key,
    this.chatId,
    this.isGroup = false,
    this.repository,
    this.viewModel,
    this.pinScanner,
  });

  @override
  State<ContactListPage> createState() => _ContactListPageState();
}

class _PinQrScannerPage extends StatefulWidget {
  const _PinQrScannerPage();

  @override
  State<_PinQrScannerPage> createState() => _PinQrScannerPageState();
}

class _PinQrScannerPageState extends State<_PinQrScannerPage> {
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'PIN_QR');
  QRViewController? _controller;
  bool _handled = false;

  Future<void> _safeCameraCall(
    Future<void> Function(QRViewController controller) action,
  ) async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await action(controller);
    } on CameraException catch (e) {
      final description = (e.description ?? '').toLowerCase();
      if (e.code == '404' || description.contains('no barcode view found')) {
        return;
      }
      debugPrint('QR camera call failed: $e');
    } catch (e) {
      debugPrint('QR camera call failed: $e');
    }
  }

  Future<void> _safePauseCamera() async {
    await _safeCameraCall((controller) => controller.pauseCamera());
  }

  Future<void> _safeResumeCamera() async {
    await _safeCameraCall((controller) => controller.resumeCamera());
  }

  @override
  void reassemble() {
    super.reassemble();
    if (defaultTargetPlatform == TargetPlatform.android) {
      unawaited(_safePauseCamera());
    }
    unawaited(_safeResumeCamera());
  }

  @override
  void dispose() {
    unawaited(_safePauseCamera());
    _controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    _controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (_handled) return;
      final value = scanData.code;
      if (value != null && value.trim().isNotEmpty) {
        if (!mounted) return;
        _handled = true;
        Navigator.of(context).pop(value.trim());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cutOut = MediaQuery.of(context).size.width * 0.75;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Pindai PIN Kontak'),
      ),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom:
                MediaQuery.of(context).size.height *
                0.15, // Move up by reducing bottom
            child: QRView(
              key: _qrKey,
              onQRViewCreated: _onQRViewCreated,
              overlay: QrScannerOverlayShape(
                borderRadius: 16,
                borderColor: Colors.white,
                borderWidth: 6,
                borderLength: 24,
                cutOutSize: cutOut,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Text(
                'Arahkan kamera ke kode QR PIN rekan Anda untuk menambah kontak.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactListPageState extends State<ContactListPage> {
  late final ContactListViewModel _viewModel;
  late final String _viewModelTag;
  final Map<String, String?> _avatarThumbPathCache = <String, String?>{};
  final Map<String, Future<String?>> _avatarThumbFutureCache =
      <String, Future<String?>>{};
  final Map<String, ContactListUserProfile> _profileCache =
      <String, ContactListUserProfile>{};
  final Set<String> _profileLoading = <String>{};
  final Set<String> _optimisticRemovedPeerUids = <String>{};

  // Reusable glass icon button
  Widget _glassIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: _surfaceStrong,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _surfaceBorder, width: 1),
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onTap,
          ),
        ),
      ),
    );
  }

  final TextEditingController _searchCtrl = TextEditingController();

  String get _myUid => _viewModel.currentUserUid;
  String _q = '';

  // Controllers untuk tambah/edit kontak
  final TextEditingController _addPinCtrl = TextEditingController();
  final TextEditingController _aliasCtrl = TextEditingController();
  bool _scanningPin = false;

  static const Color _surfaceStrong = Color.fromRGBO(255, 255, 255, 0.18);
  static const Color _surfaceSoft = Color.fromRGBO(255, 255, 255, 0.12);
  static const Color _surfaceBorder = Color.fromRGBO(255, 255, 255, 0.35);
  static const Color _surfaceInput = Color.fromRGBO(255, 255, 255, 0.15);
  static const Color _textSubtle = Color.fromRGBO(255, 255, 255, 0.6);
  static const Color _textEmphasis = Color.fromRGBO(255, 255, 255, 0.95);

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts.first;
      return s.substring(0, s.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Future<String?> _getAvatarThumbPath(
    String avatarUrl, {
    int targetSize = 96,
    int quality = 64,
  }) async {
    final normalized = avatarUrl.trim();
    if (normalized.isEmpty || !normalized.startsWith('http')) return null;

    final cached = _avatarThumbPathCache[normalized];
    if (cached != null && cached.isNotEmpty && File(cached).existsSync()) {
      return cached;
    }

    final inFlight = _avatarThumbFutureCache[normalized];
    if (inFlight != null) return inFlight;

    final future = AvatarThumbnailCacheService.instance
        .getOrCreateThumbnailPath(
          imageUrl: normalized,
          targetSize: targetSize,
          quality: quality,
        )
        .then((path) {
          _avatarThumbPathCache[normalized] = path;
          return path;
        })
        .catchError((_) => null)
        .whenComplete(() {
          _avatarThumbFutureCache.remove(normalized);
        });
    _avatarThumbFutureCache[normalized] = future;
    return future;
  }

  @override
  void initState() {
    super.initState();
    _viewModelTag = 'contact-list-${identityHashCode(this)}';
    _viewModel = Get.put(
      widget.viewModel ??
          ContactListViewModel(
            repository: widget.repository ?? ContactListRepositoryImpl(),
          ),
      tag: _viewModelTag,
    );
    _searchCtrl.addListener(() {
      final v = _searchCtrl.text.trim();
      if (v != _q) {
        setState(() => _q = v);
      }
    });
  }

  void _showFeedback(ContactListFeedback feedback) {
    if (!mounted || feedback.type == ContactListFeedbackType.none) return;
    switch (feedback.type) {
      case ContactListFeedbackType.success:
        showGlassSnackBar(
          context,
          message: feedback.message,
          tone: GlassSnackTone.success,
        );
        break;
      case ContactListFeedbackType.info:
        showGlassSnackBar(
          context,
          message: feedback.message,
          tone: GlassSnackTone.info,
        );
        break;
      case ContactListFeedbackType.warning:
        showGlassSnackBar(
          context,
          message: feedback.message,
          tone: GlassSnackTone.warning,
        );
        break;
      case ContactListFeedbackType.error:
        showGlassSnackBar(
          context,
          message: feedback.message,
          tone: GlassSnackTone.error,
        );
        break;
      case ContactListFeedbackType.none:
        break;
    }
  }

  @override
  void dispose() {
    if (Get.isRegistered<ContactListViewModel>(tag: _viewModelTag)) {
      Get.delete<ContactListViewModel>(tag: _viewModelTag, force: true);
    }
    _searchCtrl.dispose();
    _addPinCtrl.dispose();
    _aliasCtrl.dispose();
    super.dispose();
  }

  // Membuat / mendapatkan DM chatId antara saya & peer
  Future<String?> _ensureDmChat(
    String peerUid, {
    String? peerName,
    String? peerAvatarUrl,
    String? peerPin,
    String? myName,
    String? myAvatarUrl,
    String? myPin,
  }) async {
    final result = await _viewModel.ensureDmChat(
      peerUid: peerUid,
      peerName: peerName,
      peerAvatarUrl: peerAvatarUrl,
      peerPin: peerPin,
      myName: myName,
      myAvatarUrl: myAvatarUrl,
      myPin: myPin,
    );
    _showFeedback(result.feedback);
    return result.chatId;
  }

  Future<void> _addMemberToGroup({
    required String peerUid,
    required String displayName,
    required String alias,
    required String pin,
    required String avatarUrl,
  }) async {
    final chatId = widget.chatId;
    if (chatId == null || chatId.isEmpty) {
      if (mounted) {
        showGlassSnackBar(
          context,
          message: 'Grup tidak ditemukan',
          tone: GlassSnackTone.warning,
        );
      }
      return;
    }

    final result = await _viewModel.addMemberToGroup(
      chatId: chatId,
      peerUid: peerUid,
      displayName: displayName,
      alias: alias,
      pin: pin,
      avatarUrl: avatarUrl,
    );
    _showFeedback(result);
  }

  Stream<List<ContactListContact>> _contactsStream() {
    if (_myUid.isEmpty) {
      return const Stream<List<ContactListContact>>.empty();
    }
    return _viewModel.watchContacts(uid: _myUid);
  }

  Future<ContactListUserProfile> _fetchUserProfile(
    String uid, {
    String collection = 'users',
  }) async {
    return _viewModel.fetchUserProfile(uid, collection: collection);
  }

  void _warmContactProfiles(List<ContactListContact> contacts) {
    for (final contact in contacts) {
      final peerUid = contact.peerUid;
      if (peerUid.isEmpty ||
          _profileCache.containsKey(peerUid) ||
          _profileLoading.contains(peerUid)) {
        continue;
      }
      _profileLoading.add(peerUid);
      _fetchUserProfile(peerUid, collection: contact.collection)
          .then((profile) {
            _profileCache[peerUid] = profile;
            if (mounted) setState(() {});
          })
          .catchError((_) {})
          .whenComplete(() {
            _profileLoading.remove(peerUid);
          });
    }
  }

  void _showContactMenu({
    required String peerUid,
    required String currentAlias,
    required String currentDisplayName,
    required String currentPin,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surfaceSoft,
                border: Border.all(color: _surfaceBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kelola Kontak',
                    style: TextStyle(
                      color: _textEmphasis,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.edit, color: Colors.white),
                    title: const Text(
                      'Edit nama (alias)',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _editContactName(
                        peerUid: peerUid,
                        currentAlias: currentAlias,
                        fallbackName: currentDisplayName,
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.redAccent),
                    title: const Text(
                      'Hapus kontak',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      await _deleteContact(peerUid);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteContact(String peerUid) async {
    if (mounted) {
      setState(() {
        _optimisticRemovedPeerUids.add(peerUid);
        _profileCache.remove(peerUid);
      });
    }
    final feedback = await _viewModel.deleteContact(peerUid: peerUid);
    if (feedback.type == ContactListFeedbackType.error && mounted) {
      setState(() {
        _optimisticRemovedPeerUids.remove(peerUid);
      });
    }
    _showFeedback(feedback);
  }

  Future<void> _editContactName({
    required String peerUid,
    required String currentAlias,
    required String fallbackName,
  }) async {
    _aliasCtrl.text = currentAlias.isNotEmpty ? currentAlias : fallbackName;
    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _surfaceSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _surfaceBorder, width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Edit nama kontak',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _aliasCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Nama alias',
                        hintStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: _surfaceInput,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            'Batal',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _surfaceStrong,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _surfaceBorder,
                                  width: 1,
                                ),
                              ),
                              child: TextButton(
                                onPressed: () async {
                                  final alias = _aliasCtrl.text.trim();
                                  Navigator.pop(ctx);
                                  final feedback = await _viewModel
                                      .updateContactAlias(
                                        peerUid: peerUid,
                                        alias: alias,
                                      );
                                  _showFeedback(feedback);
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12.0,
                                  ),
                                  child: Text(
                                    'Simpan',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openAddContactSheet() {
    _addPinCtrl.clear();
    _aliasCtrl.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: _surfaceSoft,
                border: Border.all(color: _surfaceBorder),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tambah Kontak',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _addPinCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Masukkan PIN (contoh: CV123456M)',
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: _surfaceInput,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _aliasCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Nama alias (opsional)',
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: _surfaceInput,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: _addContactByPin,
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Tambah'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _addContactByPin() async {
    final raw = _addPinCtrl.text;
    final pin = _viewModel.normalizePin(raw);
    final alias = _aliasCtrl.text.trim();
    // Coba fast path via koleksi `pins`
    Navigator.pop(context);
    await _addContactByPinValue(pin, alias: alias);
  }

  Future<void> _addContactByPinValue(String pin, {String alias = ''}) async {
    final feedback = await _viewModel.addContactByPin(pin: pin, alias: alias);
    _showFeedback(feedback);
  }

  Future<void> _handleScanPin() async {
    if (_scanningPin) return;
    setState(() => _scanningPin = true);

    try {
      final scannedValue = widget.pinScanner != null
          ? await widget.pinScanner!()
          : await _scanPinWithCamera();

      if (!mounted || scannedValue == null) return;

      final normalized = _viewModel.normalizePin(scannedValue);
      if (normalized.isEmpty) {
        showGlassSnackBar(
          context,
          message: 'PIN pada QR tidak valid',
          tone: GlassSnackTone.warning,
        );
        return;
      }

      await _addContactByPinValue(normalized);
    } finally {
      if (mounted) {
        setState(() => _scanningPin = false);
      } else {
        _scanningPin = false;
      }
    }
  }

  Future<String?> _scanPinWithCamera() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }

    if (!status.isGranted) {
      if (!mounted) return null;
      showGlassSnackBar(
        context,
        message: status.isPermanentlyDenied
            ? 'Izin kamera ditolak permanen. Aktifkan melalui pengaturan.'
            : 'Izin kamera diperlukan untuk memindai PIN.',
        tone: GlassSnackTone.warning,
      );
      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
      return null;
    }

    if (!mounted) return null;
    return Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _PinQrScannerPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Kontak',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        flexibleSpace: Stack(
          fit: StackFit.expand,
          children: [
            // Background gradient under the AppBar (so it doesn't look black)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF101529), Color(0xFF1C2844)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Glass overlay + bottom border
            ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: _surfaceSoft,
                    border: Border(
                      bottom: BorderSide(
                        color: const Color.fromRGBO(255, 255, 255, 0.2),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.qr_code_scanner,
              color: _scanningPin ? Colors.white54 : Colors.white,
            ),
            onPressed: _scanningPin ? null : _handleScanPin,
            tooltip: 'Pindai QR PIN',
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
            onPressed: _openAddContactSheet,
            tooltip: 'Tambah kontak manual',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _surfaceStrong,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _surfaceBorder, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.white70),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Cari nama / PIN',
                            hintStyle: TextStyle(
                              color: Color.fromRGBO(255, 255, 255, 0.7),
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      if (_q.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => _searchCtrl.clear(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF101529), Color(0xFF1C2844)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          top: true,
          bottom: true,
          child: Column(
            children: [
              const SizedBox(height: 8),
              // Header: profil saya (per akun)
              StreamBuilder<ContactListUserProfile?>(
                stream: _myUid.isEmpty
                    ? const Stream<ContactListUserProfile?>.empty()
                    : _viewModel.watchCurrentUserProfile(uid: _myUid),
                builder: (context, snapMe) {
                  final profile = snapMe.data;
                  final myName = profile?.name ?? '';
                  final myPin = profile?.pin ?? '';
                  final netAvatar = profile?.photoUrl ?? '';

                  final effectiveNetAvatar = netAvatar.isNotEmpty
                      ? netAvatar
                      : (_viewModel.currentUserPhotoUrl ?? '');
                  final myInitials = _initials(
                    myName.isNotEmpty ? myName : 'Profil Saya',
                  );

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _surfaceStrong,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _surfaceBorder, width: 1),
                          ),
                          child: Row(
                            children: [
                              (effectiveNetAvatar.isNotEmpty &&
                                      effectiveNetAvatar.startsWith('http'))
                                  ? FutureBuilder<String?>(
                                      future: _getAvatarThumbPath(
                                        effectiveNetAvatar,
                                        targetSize: 96,
                                        quality: 64,
                                      ),
                                      builder: (context, avatarSnap) {
                                        final localPath = avatarSnap.data;
                                        ImageProvider? avatarProvider;
                                        if (localPath != null &&
                                            localPath.isNotEmpty &&
                                            File(localPath).existsSync()) {
                                          avatarProvider = FileImage(
                                            File(localPath),
                                          );
                                        } else {
                                          avatarProvider = NetworkImage(
                                            effectiveNetAvatar,
                                          );
                                        }
                                        return CircleAvatar(
                                          radius: 24,
                                          backgroundImage: avatarProvider,
                                          backgroundColor: Colors.white
                                              .withValues(alpha: 0.18),
                                        );
                                      },
                                    )
                                  : CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.18,
                                      ),
                                      child: Text(
                                        myInitials,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      myName.isNotEmpty
                                          ? myName
                                          : 'Profil Saya',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (myPin.isNotEmpty)
                                      Text(
                                        'PIN: $myPin',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              _glassIconButton(
                                icon: Icons.refresh,
                                onTap: () {
                                  if (mounted) setState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Expanded(
                child: StreamBuilder<List<ContactListContact>>(
                  stream: _contactsStream(),
                  builder: (context, snap) {
                    final incomingContacts =
                        snap.data ?? const <ContactListContact>[];
                    if (!snap.hasData &&
                        snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }

                    if (snap.hasData) {
                      final incomingPeerUids = incomingContacts
                          .map((contact) => contact.peerUid)
                          .toSet();
                      _optimisticRemovedPeerUids.removeWhere(
                        (peerUid) => !incomingPeerUids.contains(peerUid),
                      );
                    }

                    final visibleContacts = incomingContacts
                        .where(
                          (contact) => !_optimisticRemovedPeerUids.contains(
                            contact.peerUid,
                          ),
                        )
                        .toList(growable: false);
                    final contactDocs = _viewModel.filterContacts(
                      contacts: visibleContacts,
                      query: _q,
                    );
                    _warmContactProfiles(contactDocs);

                    if (contactDocs.isEmpty) {
                      return const Center(
                        child: Text(
                          'Belum ada kontak. Tambahkan lewat tombol di AppBar.',
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        8,
                        8,
                        8,
                        24 + MediaQuery.of(context).padding.bottom,
                      ),
                      itemCount: contactDocs.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final d = contactDocs[i];
                        final peerUid = d.peerUid;
                        final displayName = d.displayName;
                        final pin = d.pin;
                        final alias = d.alias;
                        final cachedProfile = _profileCache[peerUid];
                        final avatar = (cachedProfile?.photoUrl ?? d.photoUrl)
                            .trim();
                        final online = cachedProfile?.online ?? d.online;
                        final shownName = alias.isNotEmpty
                            ? alias
                            : (displayName.isNotEmpty
                                  ? displayName
                                  : 'Tanpa Nama');
                        final contactInitials = _initials(shownName);

                        final hasHttpAvatar =
                            avatar.isNotEmpty && avatar.startsWith('http');
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _surfaceStrong,
                                border: Border.all(color: _surfaceBorder),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ListTile(
                                leading: Stack(
                                  children: [
                                    if (hasHttpAvatar)
                                      FutureBuilder<String?>(
                                        future: _getAvatarThumbPath(
                                          avatar,
                                          targetSize: 88,
                                          quality: 62,
                                        ),
                                        builder: (context, avatarSnap) {
                                          final localPath = avatarSnap.data;
                                          final imageProvider =
                                              (localPath != null &&
                                                  localPath.isNotEmpty &&
                                                  File(localPath).existsSync())
                                              ? FileImage(File(localPath))
                                              : NetworkImage(avatar)
                                                    as ImageProvider;
                                          return CircleAvatar(
                                            radius: 22,
                                            backgroundImage: imageProvider,
                                            backgroundColor: Colors.white
                                                .withValues(alpha: 0.18),
                                          );
                                        },
                                      )
                                    else
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.18),
                                        child: Text(
                                          contactInitials,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: online
                                              ? const Color(0xFF25D366)
                                              : Colors.grey,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                title: Text(
                                  shownName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  pin.isNotEmpty ? 'PIN: $pin' : displayName,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                onTap: () async {
                                  if (widget.isGroup) {
                                    await _addMemberToGroup(
                                      peerUid: peerUid,
                                      displayName: displayName,
                                      alias: alias,
                                      pin: pin,
                                      avatarUrl: avatar,
                                    );
                                    return;
                                  }
                                  final chatId = await _ensureDmChat(
                                    peerUid,
                                    peerName: shownName,
                                    peerAvatarUrl: avatar,
                                    peerPin: pin,
                                    myName: _viewModel.currentUserDisplayName,
                                    myAvatarUrl: _viewModel.currentUserPhotoUrl,
                                  );
                                  if (!context.mounted || chatId == null) {
                                    return;
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatPage(
                                        chatId: chatId,
                                        peerName: shownName,
                                        peerAvatarUrl: avatar.isNotEmpty
                                            ? avatar
                                            : null,
                                      ),
                                    ),
                                  );
                                },
                                onLongPress: widget.isGroup
                                    ? null
                                    : () => _showContactMenu(
                                        peerUid: peerUid,
                                        currentAlias: alias,
                                        currentDisplayName: displayName,
                                        currentPin: pin,
                                      ),
                                trailing: widget.isGroup
                                    ? null
                                    : _glassIconButton(
                                        icon: Icons.more_vert,
                                        onTap: () => _showContactMenu(
                                          peerUid: peerUid,
                                          currentAlias: alias,
                                          currentDisplayName: displayName,
                                          currentPin: pin,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              // Powered by
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Powered by',
                      style: TextStyle(color: _textSubtle, fontSize: 10),
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
    );
  }
}
