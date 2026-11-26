part of 'absen.dart';

extension _AttendancePageViewBuilder on _AttendancePageState {
  Widget _inFaceRecognitionView() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    Widget cameraPreview() {
      return ClipOval(
        child: SizedBox(
          width: 250,
          height: 250,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Builder(
                builder: (_) {
                  double aspect = _cameraController!.value.aspectRatio;
                  if (aspect <= 0) {
                    aspect = 3 / 4;
                  }
                  final double normalizedAspect = aspect < 1
                      ? (1 / aspect)
                      : aspect;
                  return FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: 180,
                      height: 300 / normalizedAspect,
                      child: CameraPreview(_cameraController!),
                    ),
                  );
                },
              ),
              CustomPaint(
                painter: FaceOverlayPainter(
                  faces: _faces,
                  absoluteImageSize: _absoluteImageSize ?? Size.zero,
                  faceDetected: _faceDetectedInFrame,
                  ringColor: !_faceDetectedInFrame
                      ? Colors.white
                      : (_ownerVerified == false
                            ? Colors.redAccent
                            : Colors.greenAccent),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final List<Widget> content = [
      cameraPreview(),
      const SizedBox(height: 20),
      Builder(
        builder: (_) {
          String msg;
          Color color;
          if (!_faceDetectedInFrame) {
            msg = 'Pusatkan Wajah Anda';
            color = Colors.white;
          } else if (_ownerVerified == true) {
            final name = (_userName != null && _userName!.trim().isNotEmpty)
                ? _userName!
                : 'Wajah cocok';
            msg = name;
            color = Colors.greenAccent;
          } else if (_ownerVerified == false) {
            msg = 'Wajah bukan pemilik akun';
            color = Colors.redAccent;
          } else {
            msg = 'Wajah Terdeteksi';
            color = Colors.greenAccent;
          }
          return Text(
            msg,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          );
        },
      ),
      const SizedBox(height: 8),
      if (_shouldUseScreenFlash)
        const Text(
          'Tidak ada infra merah: layar akan menyala putih sebagai flash bantu.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
    ];

    if (_faceDetectedInFrame && _challenge == null && !_isChallengeReady) {
      content.add(const SizedBox(height: 8));
      content.add(
        _glassButton(onPressed: _pickNewChallenge, label: 'Mulai Tantangan'),
      );
    }

    if (_isDetecting) {
      content.add(const SizedBox(height: 8));
      content.add(
        const Text('Memverifikasi...', style: TextStyle(color: Colors.white)),
      );
    }

    content.add(const SizedBox(height: 8));
    content.add(
      _glassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              _challengeIcon(),
              size: 18,
              color: _challengePassed ? Colors.greenAccent : Colors.white70,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _challengeLabel(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: _pickNewChallenge,
              child: const Text(
                'Ulangi',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(mainAxisSize: MainAxisSize.min, children: content),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _glassButton(
                onPressed:
                    (_faceDetectedInFrame && !_isDetecting && _isChallengeReady)
                    ? _captureAndVerifyFace
                    : null,
                label: _isChallengeReady
                    ? 'Ambil & Verifikasi'
                    : 'Selesaikan Tantangan',
                expand: true,
              ),
              const SizedBox(height: 12),
              _glassButton(
                onPressed: _inFaceRecognition != null ? _nextInStep : null,
                label: 'Lanjut',
                expand: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _inLocationView() {
    final lat = _inPos?.latitude.toStringAsFixed(5);
    final lon = _inPos?.longitude.toStringAsFixed(5);
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              height: 220,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: (_inPos == null)
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(
                                          Icons.my_location,
                                          size: 48,
                                          color: Colors.white,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Belum ada lokasi',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Tekan Ambil Lokasi untuk menampilkan peta',
                                          style: TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    )
                                  : FlutterMap(
                                      options: MapOptions(
                                        initialCenter: LatLng(
                                          _inPos!.latitude,
                                          _inPos!.longitude,
                                        ),
                                        initialZoom: 16,
                                      ),
                                      children: [
                                        TileLayer(
                                          urlTemplate:
                                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                          userAgentPackageName: 'com.cvm.app',
                                          tileProvider:
                                              CancellableNetworkTileProvider(),
                                        ),
                                        MarkerLayer(
                                          markers: [
                                            Marker(
                                              width: 40,
                                              height: 40,
                                              point: LatLng(
                                                _inPos!.latitude,
                                                _inPos!.longitude,
                                              ),
                                              child: const Icon(
                                                Icons.location_pin,
                                                size: 40,
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_inPos != null) ...[
                          Text(
                            'Lat: $lat, Lon: $lon',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                        ],
                        _glassPanel(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 14,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pilih Lokasi',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _glassChoice(
                                    label: 'Kantor',
                                    selected:
                                        _projectController.text == 'Kantor',
                                    onTap: () {
                                      _setStateSafe(() {
                                        _projectController.text = 'Kantor';
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  _glassChoice(
                                    label: 'Proyek',
                                    selected:
                                        _projectController.text.isNotEmpty &&
                                        _projectController.text != 'Kantor',
                                    onTap: () {
                                      _setStateSafe(() {
                                        _projectController.clear();
                                      });
                                      showDialog(
                                        context: context,
                                        builder: (ctx) {
                                          final tempController =
                                              TextEditingController(
                                                text: _projectController.text,
                                              );
                                          return Dialog(
                                            backgroundColor: Colors.transparent,
                                            insetPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 24,
                                                  vertical: 24,
                                                ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              child: BackdropFilter(
                                                filter: ImageFilter.blur(
                                                  sigmaX: 12,
                                                  sigmaY: 12,
                                                ),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    16,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.18,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          18,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.35,
                                                          ),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      const Text(
                                                        'Nama Proyek',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        height: 10,
                                                      ),
                                                      ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        child: BackdropFilter(
                                                          filter:
                                                              ImageFilter.blur(
                                                                sigmaX: 8,
                                                                sigmaY: 8,
                                                              ),
                                                          child: Container(
                                                            decoration: BoxDecoration(
                                                              color: Colors
                                                                  .white
                                                                  .withValues(
                                                                    alpha: 0.15,
                                                                  ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                              border: Border.all(
                                                                color: Colors
                                                                    .white
                                                                    .withValues(
                                                                      alpha:
                                                                          0.3,
                                                                    ),
                                                              ),
                                                            ),
                                                            child: TextField(
                                                              controller:
                                                                  tempController,
                                                              style:
                                                                  const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                              decoration: const InputDecoration(
                                                                contentPadding:
                                                                    EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          12,
                                                                      vertical:
                                                                          12,
                                                                    ),
                                                                hintText:
                                                                    'Masukkan nama proyek',
                                                                hintStyle: TextStyle(
                                                                  color: Colors
                                                                      .white70,
                                                                ),
                                                                border:
                                                                    InputBorder
                                                                        .none,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        height: 16,
                                                      ),
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: _glassButton(
                                                              onPressed: () =>
                                                                  Navigator.of(
                                                                    ctx,
                                                                  ).pop(),
                                                              label: 'Batal',
                                                              expand: true,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 12,
                                                          ),
                                                          Expanded(
                                                            child: _glassButton(
                                                              onPressed: () {
                                                                _setStateSafe(() {
                                                                  _projectController
                                                                          .text =
                                                                      tempController
                                                                          .text
                                                                          .trim();
                                                                });
                                                                Navigator.of(
                                                                  ctx,
                                                                ).pop();
                                                              },
                                                              label: 'Simpan',
                                                              expand: true,
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
                                    },
                                  ),
                                ],
                              ),
                              if (_projectController.text.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Lokasi: ${_projectController.text}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Row(
            children: [
              Expanded(
                child: _glassButton(
                  onPressed: _captureLocation,
                  label: 'Ambil Lokasi',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _glassButton(
                  onPressed: _inPos != null ? _nextInStep : null,
                  label: 'Lanjut',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _inBackPhotoView() {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              height: 220,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: _inBackPhoto != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        _inBackPhoto!,
                                        width: double.infinity,
                                        height: 220,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(
                                          Icons.photo_camera_back_outlined,
                                          size: 64,
                                          color: Colors.white,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Ambil foto lokasi (kamera belakang)',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_inBackPhoto != null) ...[
                          const Text(
                            'Foto lokasi sudah diambil ✅',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Row(
            children: [
              Expanded(
                child: _glassButton(
                  onPressed: _captureBackPhoto,
                  label: 'Ambil Foto',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _glassButton(
                  onPressed: _inBackPhoto != null ? _nextInStep : null,
                  label: 'Lanjut',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _inConfirmView() {
    final lat = _inPos?.latitude.toStringAsFixed(5);
    final lon = _inPos?.longitude.toStringAsFixed(5);
    final bool reasonReady =
        !_isLateNow || _lateReasonController.text.trim().isNotEmpty;
    final bool alreadyCheckedIn = _hasAttendanceToday || checkInAt != null;
    Widget confirmRow({
      required IconData icon,
      required String label,
      required bool ok,
    }) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.cancel,
            color: ok ? Colors.greenAccent : Colors.redAccent,
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      children: [
                        if (alreadyCheckedIn) ...[
                          _glassPanel(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(
                                      0xFF4CAF50,
                                    ).withValues(alpha: 0.16),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF4CAF50,
                                      ).withValues(alpha: 0.42),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.verified_rounded,
                                    color: Color(0xFF4CAF50),
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Anda sudah absen hari ini',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  checkInAt != null
                                      ? 'Check-in pada ${_controller.formatClock(checkInAt!)}'
                                      : 'Check-in tersimpan',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Tunggu admin membuka absen di hari berikutnya.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          _glassPanel(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 20,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'Konfirmasi Check-in',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                confirmRow(
                                  icon: Icons.face_retouching_natural,
                                  label: _inFaceRecognition != null
                                      ? 'Face Recognition OK'
                                      : 'Face Recognition kosong',
                                  ok: _inFaceRecognition != null,
                                ),
                                const SizedBox(height: 6),
                                confirmRow(
                                  icon: Icons.my_location,
                                  label: _inPos != null
                                      ? 'Lokasi: $lat, $lon'
                                      : 'Lokasi kosong',
                                  ok: _inPos != null,
                                ),
                                const SizedBox(height: 6),
                                confirmRow(
                                  icon: Icons.photo_camera_back,
                                  label: _inBackPhoto != null
                                      ? 'Foto lokasi OK'
                                      : 'Foto lokasi kosong',
                                  ok: _inBackPhoto != null,
                                ),
                              ],
                            ),
                          ),
                          if (_attendanceAvailable && _isLateNow) ...[
                            const SizedBox(height: 16),
                            _lateReasonCard(),
                            if (!reasonReady) ...[
                              const SizedBox(height: 10),
                              const Text(
                                'Isi alasan keterlambatan untuk melanjutkan check-in.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _glassButton(
                onPressed:
                    _canCheckIn &&
                        !_isSavingAttendance &&
                        checkInAt == null &&
                        !_hasAttendanceToday &&
                        _attendanceAvailable &&
                        reasonReady
                    ? _submitAttendance
                    : null,
                label: (!_hasAttendanceToday && checkInAt == null)
                    ? (_isSavingAttendance
                          ? 'Menyimpan...'
                          : _attendanceAvailable
                          ? (_isLateNow
                                ? 'Absen (Terlambat)'
                                : 'Absen (Check-in)')
                          : 'Menunggu dibuka')
                    : 'Anda sudah absen hari ini',
                expand: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvailabilityBanner() {
    final loading = !_attendanceWindowLoaded;
    final message = _attendanceStatusMessage ?? 'Memuat jadwal absensi...';

    if (loading) {
      return _glassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: const [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Memuat jadwal absensi...',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final color = _attendanceStatusColor;
    final icon = !_attendanceAvailable
        ? Icons.lock_clock
        : (_isLateNow ? Icons.schedule_rounded : Icons.check_circle_outline);
    final lateMinutes = _currentLateDuration.inMinutes.clamp(1, 999);

    return _glassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.2),
              border: Border.all(color: color.withValues(alpha: 0.45)),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                if (_attendanceAvailable && _isLateNow)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: color.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        'Terlambat $lateMinutes mnt',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedView() {
    if (!_attendanceWindowLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    final message = _attendanceStatusMessage ?? 'Absen belum dibuka admin';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: _glassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _attendanceStatusColor.withValues(alpha: 0.18),
                  border: Border.all(
                    color: _attendanceStatusColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(
                  Icons.lock_clock,
                  color: _attendanceStatusColor,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Hubungi admin apabila membutuhkan penyesuaian jadwal absen.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _attendanceWindowLoaded
                    ? _subscribeAttendanceWindow
                    : null,
                icon: const Icon(Icons.refresh),
                label: const Text('Periksa Ulang'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassPanel({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(12),
    double radius = 16,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(radius),
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

  Widget _glassChoice({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected)
                  const Icon(Icons.check, size: 16, color: Colors.white),
                if (selected) const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassButton({
    required VoidCallback? onPressed,
    required String label,
    bool expand = false,
  }) {
    final btn = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

class FaceOverlayPainter extends CustomPainter {
  final List<Face> faces;
  final Size absoluteImageSize;
  final bool faceDetected;
  final Color ringColor;

  FaceOverlayPainter({
    required this.faces,
    required this.absoluteImageSize,
    required this.faceDetected,
    this.ringColor = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = faceDetected ? ringColor : Colors.white;

    final circleRect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width / 2,
    );

    canvas.drawOval(circleRect, borderPaint);
  }

  @override
  bool shouldRepaint(FaceOverlayPainter oldDelegate) {
    return oldDelegate.faces != faces ||
        oldDelegate.faceDetected != faceDetected;
  }
}
