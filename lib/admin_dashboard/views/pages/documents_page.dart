import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:cipta_vera_mandiri_digital/app/widgets/glass_snack_bar.dart';
import 'package:cipta_vera_mandiri_digital/shared/models/document_record.dart';
import 'package:cipta_vera_mandiri_digital/shared/models/calendar_event.dart';
import 'package:cipta_vera_mandiri_digital/shared/services/document_repository.dart';
import 'package:cipta_vera_mandiri_digital/admin_dashboard/widgets/glass.dart';
import 'package:cipta_vera_mandiri_digital/admin_dashboard/services/admin_notification_service.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  final DocumentRepository _repository = DocumentRepository();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminNotificationService _adminNotificationService =
      AdminNotificationService();

  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';
  _ExpiryFilter _filter = _ExpiryFilter.all;

  final Map<String, _UserInfo?> _userCache = <String, _UserInfo?>{};
  final Set<String> _pendingUserFetch = <String>{};
  bool _isUploading = false;
  final Set<String> _deletingIds = <String>{};
  final Map<String, DateTime> _lastReminderSent = <String, DateTime>{};
  bool _sendingReminders = false;
  bool _reminderStateLoaded = false;

  static const _prefsReminderKey = 'admin_document_reminders_last';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initReminderState();
  }

  Future<void> _initReminderState() async {
    await _adminNotificationService.start();
    await _loadReminderState();
  }

  Future<void> _loadReminderState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsReminderKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        decoded.forEach((key, value) {
          final parsed = DateTime.tryParse(value.toString());
          if (parsed != null) {
            _lastReminderSent[key] = parsed;
          }
        });
      }
    } catch (_) {
      // ignore corrupted state
    } finally {
      _reminderStateLoaded = true;
    }
  }

  Future<void> _saveReminderState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _lastReminderSent.map(
        (key, value) => MapEntry(key, value.toIso8601String()),
      );
      await prefs.setString(_prefsReminderKey, jsonEncode(data));
    } catch (_) {
      // ignore persistence errors
    }
  }

  Future<void> _showAddDocumentDialog() async {
    final emailController = TextEditingController();
    final titleController = TextEditingController();
    final notesController = TextEditingController();
    DateTime? expiresAt;
    Duration? reminder;
    PlatformFile? pickedFile;
    List<String> selectedDivisions = [CalendarDivision.all];

    final result = await showDialog<_AdminDocumentFormResult?>
      (context: context, barrierDismissible: false, builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> pickFile() async {
              final res = await FilePicker.platform.pickFiles(
                withData: true,
                allowMultiple: false,
              );
              if (res == null || res.files.isEmpty) return;
              setStateDialog(() => pickedFile = res.files.first);
            }

            Future<void> pickDate() async {
              final now = DateTime.now();
              final selected = await showDatePicker(
                context: context,
                initialDate: expiresAt ?? now.add(const Duration(days: 180)),
                firstDate: DateTime(now.year - 5),
                lastDate: DateTime(now.year + 10),
              );
              if (selected != null) {
                setStateDialog(() => expiresAt = selected);
                if (reminder == null) {
                  reminder = const Duration(days: 90);
                }
              }
            }

            void removeDate() {
              setStateDialog(() {
                expiresAt = null;
                reminder = null;
              });
            }

            void submit() {
              final email = emailController.text.trim();
              final title = titleController.text.trim();
              final notes = notesController.text.trim();
              if (email.isEmpty || title.isEmpty || pickedFile == null) {
                showGlassSnackBar(
                  context,
                  message:
                      'Isi email/nama karyawan, judul dokumen, dan pilih berkas.',
                  tone: GlassSnackTone.warning,
                );
                return;
              }
                  Navigator.of(dialogContext).pop(
                    _AdminDocumentFormResult(
                      email: email,
                      title: title,
                      notes: notes.isEmpty ? null : notes,
                      expiresAt: expiresAt,
                      reminderInterval: reminder,
                      file: pickedFile!,
                      divisions: selectedDivisions,
                    ),
                  );
            }

            return GlassContainer(
              borderRadius: 28,
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Tambah Dokumen',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close, color: Colors.white70),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _DialogField(
                        label: 'Email / Nama Karyawan',
                        child: TextField(
                          controller: emailController,
                          keyboardType: TextInputType.text,
                          style: const TextStyle(color: Colors.white),
                          decoration: _dialogInputDecoration(
                            'contoh: user@perusahaan.com atau Budi Santoso',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _DialogField(
                        label: 'Judul Dokumen',
                        child: TextField(
                          controller: titleController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _dialogInputDecoration('mis. Kontrak Kerja Tahunan'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _DialogField(
                        label: 'Catatan (opsional)',
                        child: TextField(
                          controller: notesController,
                          maxLines: 3,
                          style: const TextStyle(color: Colors.white),
                          decoration: _dialogInputDecoration('Keterangan tambahan'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _DialogField(
                        label: 'Divisi yang Dapat Melihat Notifikasi',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: CalendarDivision.options.map((option) {
                            final isSelected = selectedDivisions.contains(option.id);
                            return FilterChip(
                              label: Text(
                                option.label,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white70,
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                setStateDialog(() {
                                  if (selected) {
                                    if (option.id == CalendarDivision.all) {
                                      selectedDivisions = [CalendarDivision.all];
                                    } else {
                                      selectedDivisions = selectedDivisions
                                          .where((d) => d != CalendarDivision.all)
                                          .toList();
                                      if (!selectedDivisions.contains(option.id)) {
                                        selectedDivisions.add(option.id);
                                      }
                                    }
                                  } else {
                                    selectedDivisions.remove(option.id);
                                    if (selectedDivisions.isEmpty) {
                                      selectedDivisions = [CalendarDivision.all];
                                    }
                                  }
                                });
                              },
                              backgroundColor: Colors.white.withOpacity(0.1),
                              selectedColor: Colors.white.withOpacity(0.2),
                              checkmarkColor: Colors.white,
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _DialogField(
                        label: 'Tanggal Kedaluwarsa',
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                expiresAt != null
                                    ? _formatDate(expiresAt!)
                                    : 'Belum dipilih',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            TextButton(
                              onPressed: pickDate,
                              child: const Text('Pilih', style: TextStyle(color: Colors.white)),
                            ),
                            if (expiresAt != null)
                              TextButton(
                                onPressed: removeDate,
                                child: const Text('Hapus', style: TextStyle(color: Colors.white70)),
                              ),
                          ],
                        ),
                      ),
                      if (expiresAt != null) ...[
                        const SizedBox(height: 16),
                        _DialogField(
                          label: 'Pengingat',
                          child: DropdownButton<Duration?>(
                            value: reminder,
                            hint: const Text('Pilih interval', style: TextStyle(color: Colors.white70)),
                            dropdownColor: const Color(0xFF1B2645),
                            iconEnabledColor: Colors.white,
                            style: const TextStyle(color: Colors.white),
                            underline: const SizedBox.shrink(),
                            onChanged: (value) => setStateDialog(() => reminder = value),
                            items: const [
                              DropdownMenuItem(value: null, child: Text('Tanpa pengingat')),
                              DropdownMenuItem(value: Duration(days: 30), child: Text('Setiap 1 bulan')),
                              DropdownMenuItem(value: Duration(days: 60), child: Text('Setiap 2 bulan')),
                              DropdownMenuItem(value: Duration(days: 90), child: Text('Setiap 3 bulan')),
                              DropdownMenuItem(value: Duration(days: 180), child: Text('Setiap 6 bulan')),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _DialogField(
                        label: 'File Dokumen',
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                pickedFile?.name ?? 'Belum ada file dipilih',
                                style: const TextStyle(color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: pickFile,
                              icon: const Icon(Icons.attach_file, color: Colors.white),
                              label: const Text('Pilih', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 12,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(dialogContext).pop(),
                              child: const Text('Batal', style: TextStyle(color: Colors.white70)),
                            ),
                            FilledButton.icon(
                              onPressed: submit,
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
            );
          },
        ),
      );
    });

    emailController.dispose();
    titleController.dispose();
    notesController.dispose();

    if (!mounted || result == null) return;
    await _uploadDocument(result);
  }

  Future<void> _uploadDocument(_AdminDocumentFormResult form) async {
    setState(() => _isUploading = true);
    try {
      final userDoc = await _findUserByIdentifier(form.email);
      if (userDoc == null) {
        if (!mounted) return;
        showGlassSnackBar(
          context,
          message:
              'Pengguna dengan email atau nama tersebut tidak ditemukan.',
          tone: GlassSnackTone.warning,
        );
        return;
      }

      final uid = userDoc.id;
      final sanitizedName = form.file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'pemberkasan/$uid/${timestamp}_$sanitizedName';
      final ref = FirebaseStorage.instance.ref(storagePath);

      final bytes = form.file.bytes;
      if (bytes == null) {
        if (!mounted) return;
        showGlassSnackBar(
          context,
          message: 'Gagal membaca isi file yang dipilih.',
          tone: GlassSnackTone.error,
        );
        return;
      }

      final metadata = SettableMetadata(contentType: _resolveContentType(form.file.name));
      await ref.putData(bytes, metadata);
      final downloadUrl = await ref.getDownloadURL();

      final documentId = await _repository.addDocument(
        uid: uid,
        title: form.title,
        storagePath: storagePath,
        downloadUrl: downloadUrl,
        createdBy: FirebaseAuth.instance.currentUser?.uid ?? 'admin-dashboard',
        expiresAt: form.expiresAt,
        reminderInterval: form.reminderInterval,
        originalFileName: form.file.name,
        divisions: form.divisions,
        extra: form.notes != null && form.notes!.isNotEmpty
            ? {'notes': form.notes}
            : null,
      );

      // Push admin notification tanpa menunggu, supaya UI lebih cepat kembali.
      unawaited(_sendDivisionNotification(documentId, form));

      if (!mounted) return;
      showGlassSnackBar(
        context,
        message: 'Dokumen “${form.title}” berhasil ditambahkan.',
        tone: GlassSnackTone.success,
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      showGlassSnackBar(
        context,
        message: 'Gagal mengunggah dokumen: ${e.message ?? e.code}',
        tone: GlassSnackTone.error,
      );
    } catch (e) {
      if (!mounted) return;
      showGlassSnackBar(
        context,
        message: 'Gagal mengunggah dokumen: $e',
        tone: GlassSnackTone.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findUserByIdentifier(
    String value,
  ) async {
    final identifier = value.trim();
    if (identifier.isEmpty) return null;
    final users = _firestore.collection('users');

    Future<DocumentSnapshot<Map<String, dynamic>>?> query(String field) async {
      final snapshot =
          await users.where(field, isEqualTo: identifier).limit(1).get();
      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first;
    }

    if (identifier.contains('@')) {
      final emailDoc = await query('email');
      if (emailDoc != null) return emailDoc;
    }

    for (final field in ['displayName', 'fullName', 'name', 'username']) {
      final doc = await query(field);
      if (doc != null) return doc;
    }

    return null;
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor =
        theme.colorScheme.brightness == Brightness.dark ? Colors.white : null;
    final subtitleColor = textColor?.withOpacity(0.72);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 1120;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: wide ? 380 : 320,
                  child: GlassContainer(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    borderRadius: 18,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() => _searchTerm = value.trim().toLowerCase());
                      },
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Cari dokumen, pemilik, atau catatan…',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                        ),
                        border: InputBorder.none,
                        icon: Icon(Icons.search,
                            color: Colors.white.withOpacity(0.8)),
                      ),
                    ),
                  ),
                ),
                GlassContainer(
                  borderRadius: 18,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<_ExpiryFilter>(
                      value: _filter,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      dropdownColor: const Color(0xFF1E2A4A),
                      borderRadius: BorderRadius.circular(16),
                      iconEnabledColor: Colors.white,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _filter = value);
                      },
                      selectedItemBuilder: (_) => _ExpiryFilter.values
                          .map(
                            (f) => _ExpiryFilterChip(
                              filter: f,
                              isCompact: true,
                            ),
                          )
                          .toList(growable: false),
                      items: _ExpiryFilter.values
                          .map(
                            (f) => DropdownMenuItem<_ExpiryFilter>(
                              value: f,
                              child: _ExpiryFilterChip(filter: f),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
                GlassContainer(
                  borderRadius: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: TextButton.icon(
                    onPressed: _isUploading ? null : _showAddDocumentDialog,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.add, color: Colors.white),
                    label: Text(
                      _isUploading ? 'Mengunggah…' : 'Tambah Dokumen',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Pemberkasan Karyawan',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: textColor ?? theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pantau dokumen yang diunggah karyawan dan tindak lanjuti sebelum masa berlaku habis.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: subtitleColor ?? theme.textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 22),
            Expanded(
              child: StreamBuilder<List<DocumentRecord>>(
                stream: _repository.watchAllDocuments(limit: 600),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: GlassContainer(
                        borderRadius: 28,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.white.withOpacity(0.88), size: 52),
                            const SizedBox(height: 12),
                            Text(
                              'Gagal memuat dokumen',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final docs = snapshot.data ?? const <DocumentRecord>[];
                  _maybeSendReminders(docs);
                  final filtered = docs.where(_matchesFilter).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: GlassContainer(
                        borderRadius: 26,
                        padding: const EdgeInsets.all(30),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder_off,
                                color: Colors.white.withOpacity(0.8), size: 56),
                            const SizedBox(height: 12),
                            Text(
                              'Tidak ada dokumen',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Coba ubah pencarian atau filter untuk melihat dokumen lainnya.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Scrollbar(
                    thumbVisibility: true,
                    child: ListView.separated(
                      itemBuilder: (context, index) {
                        final record = filtered[index];
                        _ensureUserInfo(record.uid);
                        final isDeleting = _deletingIds.contains(record.id);
                        return _DocumentCard(
                          record: record,
                          onOpen: () => _openUrl(record.downloadUrl),
                          onCopyLink: () =>
                              _copyToClipboard(record.downloadUrl),
                          onDelete: () => _confirmDelete(record),
                          isDeleting: isDeleting,
                        );
                      },
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemCount: filtered.length,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  bool _matchesFilter(DocumentRecord record) {
    if (!_filter.matches(record)) {
      return false;
    }
    final query = _searchTerm;
    if (query.isEmpty) return true;

    final userInfo = _userCache[record.uid];

    final haystacks = [
      record.title,
      record.originalFileName,
      record.uid,
      record.storagePath,
      record.raw['notes'],
      userInfo?.name,
      userInfo?.email,
    ].whereType<String>();

    for (final value in haystacks) {
      if (value.toLowerCase().contains(query)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _ensureUserInfo(String uid) async {
    if (uid.isEmpty || _userCache.containsKey(uid) || _pendingUserFetch.contains(uid)) {
      return;
    }
    _pendingUserFetch.add(uid);
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data();
      final info = _UserInfo(
        name: _extractName(data),
        email: _extractEmail(data),
      );
      if (!mounted) return;
      setState(() {
        _userCache[uid] = info;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _userCache[uid] = null;
      });
    } finally {
      _pendingUserFetch.remove(uid);
    }
  }

  String? _extractName(Map<String, dynamic>? data) {
    if (data == null) return null;
    final candidates = [
      data['displayName'],
      data['fullName'],
      data['name'],
      data['username'],
    ];
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return null;
  }

  String? _extractEmail(Map<String, dynamic>? data) {
    if (data == null) return null;
    final email = data['email'];
    if (email is String && email.trim().isNotEmpty) {
      return email.trim();
    }
    return null;
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _copyToClipboard(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    showGlassSnackBar(
      context,
      message: 'Tautan dokumen disalin ke clipboard',
      tone: GlassSnackTone.info,
    );
  }

  Future<void> _maybeSendReminders(List<DocumentRecord> docs) async {
    if (!_reminderStateLoaded || _sendingReminders) return;
    _sendingReminders = true;
    try {
      final now = DateTime.now();
      bool changed = false;

      for (final record in docs) {
        final expiresAt = record.expiresAt;
        if (expiresAt == null) continue;
        if (expiresAt.isBefore(now)) continue;
        if (expiresAt.isAfter(now.add(const Duration(days: 90)))) continue;

        final last = _lastReminderSent[record.id];
        if (last != null && now.difference(last).inDays < 7) {
          continue; // already reminded this week
        }

        final daysLeft = expiresAt.difference(now).inDays;
        final bucket = daysLeft <= 30
            ? '1 bulan'
            : daysLeft <= 60
                ? '2 bulan'
                : '3 bulan';
        final weekKey = _weekKey(now);

        final entry = AdminNotificationEntry(
          id: 'document_reminder:${record.id}:$weekKey',
          type: AdminNotificationType.document,
          title: 'Pengingat perpanjangan dokumen',
          body:
              'Dokumen "${record.title}" akan kedaluwarsa pada ${_formatDate(expiresAt)} (sisa ~$bucket). Segera perpanjang.',
          timestamp: now,
          targetPageIndex: 4,
          data: {
            'documentId': record.id,
            'expiresAt': expiresAt.toIso8601String(),
            'daysLeft': daysLeft,
          },
        );

        await _adminNotificationService.addNotification(entry);
        _lastReminderSent[record.id] = now;
        changed = true;
      }

      if (changed) {
        await _saveReminderState();
      }
    } finally {
      _sendingReminders = false;
    }
  }

  String _weekKey(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    final y = monday.year.toString().padLeft(4, '0');
    final m = monday.month.toString().padLeft(2, '0');
    final d = monday.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  Future<void> _confirmDelete(DocumentRecord record) async {
    if (_deletingIds.contains(record.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: GlassContainer(
            borderRadius: 26,
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.redAccent.withOpacity(0.14),
                          border: Border.all(
                            color: Colors.redAccent.withOpacity(0.32),
                          ),
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Hapus dokumen?',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Dokumen "${record.title}" akan dihapus dari pemberkasan dan Storage. Tindakan ini tidak dapat dibatalkan.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.85),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(false),
                        child: const Text(
                          'Batal',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(true),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text(
                          'Hapus',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (confirmed != true) return;
    await _deleteDocument(record);
  }

  Future<void> _deleteDocument(DocumentRecord record) async {
    setState(() => _deletingIds.add(record.id));
    try {
      await _repository.deleteDocument(documentId: record.id);
      // Hapus file di Storage tanpa menahan UI.
      unawaited(_deleteStoragePath(record.storagePath));
      if (!mounted) return;
      showGlassSnackBar(
        context,
        message: 'Dokumen "${record.title}" telah dihapus.',
        tone: GlassSnackTone.success,
      );
    } catch (e) {
      if (!mounted) return;
      showGlassSnackBar(
        context,
        message: 'Gagal menghapus dokumen: $e',
        tone: GlassSnackTone.error,
      );
    } finally {
      if (mounted) {
        setState(() => _deletingIds.remove(record.id));
      } else {
        _deletingIds.remove(record.id);
      }
    }
  }

  Future<void> _deleteStoragePath(String storagePath) async {
    if (storagePath.trim().isEmpty) return;
    try {
      await FirebaseStorage.instance.ref(storagePath).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') {
        // Diam saja untuk error lain agar tidak mengganggu UI; log bisa ditambahkan bila perlu.
      }
    } catch (_) {}
  }

  Future<void> _sendDivisionNotification(
    String documentId,
    _AdminDocumentFormResult form,
  ) async {
    if (form.divisions.isEmpty || form.divisions == [CalendarDivision.all]) {
      return;
    }
    try {
      await _adminNotificationService.start();

      final visibleDivisions = form.divisions;
      final entry = AdminNotificationEntry(
        id: 'document:$documentId',
        type: AdminNotificationType.document,
        title: 'Dokumen baru ditambahkan',
        body:
            'Dokumen "${form.title}" telah ditambahkan untuk divisi ${visibleDivisions.map((d) => CalendarDivision.labelFor(d) ?? d).join(', ')}.',
        timestamp: DateTime.now(),
        targetPageIndex: 4, // Documents page index
        data: {
          'documentId': documentId,
          'title': form.title,
          'divisions': visibleDivisions,
        },
      );

      await _adminNotificationService.addNotification(entry);
    } catch (_) {}
  }
}

String _resolveContentType(String fileName) {
  final ext = fileName.contains('.')
      ? fileName.split('.').last.toLowerCase()
      : '';
  const knownTypes = <String, String>{
    'pdf': 'application/pdf',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'bmp': 'image/bmp',
    'heic': 'image/heic',
    'webp': 'image/webp',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx':
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'txt': 'text/plain',
    'csv': 'text/csv',
    'json': 'application/json',
    'zip': 'application/zip',
    'rar': 'application/vnd.rar',
    '7z': 'application/x-7z-compressed',
  };
  return knownTypes[ext] ?? 'application/octet-stream';
}

InputDecoration _dialogInputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.white.withOpacity(0.72)),
    filled: true,
    fillColor: Colors.white.withOpacity(0.12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}

class _DialogField extends StatelessWidget {
  const _DialogField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
        child,
      ],
    );
  }
}

class _AdminDocumentFormResult {
  _AdminDocumentFormResult({
    required this.email,
    required this.title,
    required this.file,
    this.notes,
    this.expiresAt,
    this.reminderInterval,
    this.divisions = const [CalendarDivision.all],
  });

  final String email;
  final String title;
  final PlatformFile file;
  final String? notes;
  final DateTime? expiresAt;
  final Duration? reminderInterval;
  final List<String> divisions;
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.record,
    required this.onOpen,
    required this.onCopyLink,
    required this.onDelete,
    this.isDeleting = false,
  });

  final DocumentRecord record;
  final VoidCallback onOpen;
  final VoidCallback onCopyLink;
  final VoidCallback onDelete;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _ExpiryStatus.from(record);

    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: status.color,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: status.color.withOpacity(0.6),
                      blurRadius: 8,
                      spreadRadius: -1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
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
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.75),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opsi dokumen',
                icon: Icon(Icons.more_horiz,
                    color: Colors.white.withOpacity(0.85)),
                onSelected: (value) {
                  if (value == 'open') {
                    onOpen();
                  } else if (value == 'copy') {
                    onCopyLink();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(
                    value: 'open',
                    child: ListTile(
                      leading: Icon(Icons.open_in_new),
                      title: Text('Buka dokumen'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'copy',
                    child: ListTile(
                      leading: Icon(Icons.link),
                      title: Text('Salin tautan'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, color: Colors.red),
                      title: Text(
                        'Hapus dokumen',
                        style: TextStyle(color: Colors.red),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _MiniStat(
                icon: Icons.timer_outlined,
                text: status.label,
                color: status.color,
              ),
              _MiniStat(
                icon: Icons.upload_outlined,
                text: 'Diunggah ${_formatDate(record.createdAt)}',
              ),
            ],
          ),
          if (record.raw['notes'] != null &&
              record.raw['notes'].toString().trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              record.raw['notes'].toString().trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.85),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: isDeleting ? null : onOpen,
                icon: const Icon(Icons.open_in_new, color: Colors.white),
                label: const Text(
                  'Buka',
                  style: TextStyle(color: Colors.white),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: isDeleting ? null : onDelete,
                icon: isDeleting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.delete_outline, color: Colors.redAccent),
                label: Text(
                  isDeleting ? 'Menghapus…' : 'Hapus',
                  style: TextStyle(
                    color: isDeleting ? Colors.white : Colors.redAccent,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.text,
    this.color,
  });

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = color ??
        (theme.brightness == Brightness.dark
            ? Colors.white.withOpacity(0.82)
            : theme.colorScheme.onSurface.withOpacity(0.82));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: baseColor),
        const SizedBox(width: 6),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: baseColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _UserInfo {
  const _UserInfo({this.name, this.email});

  final String? name;
  final String? email;
}

enum _ExpiryFilter { all, expiringSoon, expired }

extension on _ExpiryFilter {
  String get label {
    switch (this) {
      case _ExpiryFilter.all:
        return 'Semua';
      case _ExpiryFilter.expiringSoon:
        return 'Segera kedaluwarsa';
      case _ExpiryFilter.expired:
        return 'Sudah kedaluwarsa';
    }
  }

  String get description {
    switch (this) {
      case _ExpiryFilter.all:
        return 'Tampilkan seluruh dokumen';
      case _ExpiryFilter.expiringSoon:
        return 'Masa berlaku habis ≤ 30 hari';
      case _ExpiryFilter.expired:
        return 'Masa berlaku sudah lewat';
    }
  }

  IconData get icon {
    switch (this) {
      case _ExpiryFilter.all:
        return Icons.layers_outlined;
      case _ExpiryFilter.expiringSoon:
        return Icons.hourglass_bottom_rounded;
      case _ExpiryFilter.expired:
        return Icons.warning_amber_rounded;
    }
  }

  Color get accentColor {
    switch (this) {
      case _ExpiryFilter.all:
        return const Color(0xFF7DD3FC);
      case _ExpiryFilter.expiringSoon:
        return const Color(0xFFFFD166);
      case _ExpiryFilter.expired:
        return const Color(0xFFFF7B7B);
    }
  }

  bool matches(DocumentRecord record) {
    final expiresAt = record.expiresAt;
    if (this == _ExpiryFilter.all || expiresAt == null) {
      return this == _ExpiryFilter.all;
    }
    final now = DateTime.now();
    if (this == _ExpiryFilter.expired) {
      return expiresAt.isBefore(now);
    }
    // expiring soon: within 30 days and not expired
    final diff = expiresAt.difference(now).inDays;
    return diff >= 0 && diff <= 30;
  }
}

class _ExpiryFilterChip extends StatelessWidget {
  const _ExpiryFilterChip({
    required this.filter,
    this.isCompact = false,
  });

  final _ExpiryFilter filter;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = filter.accentColor;
    final textColor = theme.brightness == Brightness.dark
        ? Colors.white
        : theme.colorScheme.onSurface;

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.16),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withOpacity(0.45), width: 0.8),
          ),
          child: Icon(filter.icon, color: accent, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                filter.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!isCompact) ...[
                const SizedBox(height: 2),
                Text(
                  filter.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: textColor.withOpacity(0.75),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ExpiryStatus {
  const _ExpiryStatus(this.label, this.color);

  final String label;
  final Color color;

  static _ExpiryStatus from(DocumentRecord record) {
    final expiresAt = record.expiresAt;
    if (expiresAt == null) {
      return const _ExpiryStatus('Tidak ada kedaluwarsa', Color(0xFF38BDF8));
    }
    final now = DateTime.now();
    final diff = expiresAt.difference(now).inDays;
    if (diff < 0) {
      return const _ExpiryStatus('Sudah kedaluwarsa', Color(0xFFFF6666));
    }
    if (diff == 0) {
      return const _ExpiryStatus('Kedaluwarsa hari ini', Color(0xFFFF9966));
    }
    if (diff <= 7) {
      return _ExpiryStatus('Akan kedaluwarsa dalam $diff hari', const Color(0xFFFFB347));
    }
    if (diff <= 30) {
      return _ExpiryStatus('Kedaluwarsa dalam $diff hari', const Color(0xFFFFD36B));
    }
    return _ExpiryStatus(
      'Kedaluwarsa ${_formatDate(expiresAt)}',
      const Color(0xFF34D399),
    );
  }
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
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
  final month = months[(local.month - 1).clamp(0, months.length - 1)];
  return '${local.day} $month ${local.year}';
}
