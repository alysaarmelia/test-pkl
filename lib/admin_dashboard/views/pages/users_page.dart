import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/widgets/glass_snack_bar.dart';
import '../../data/attendance_repository.dart';
import '../../widgets/glass.dart';

class _RoleToggleOption {
  const _RoleToggleOption({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String key;
  final String label;
  final String description;
  final IconData icon;
}

const List<_RoleToggleOption> _roleToggleOptions = [
  _RoleToggleOption(
    key: 'superAdmin',
    label: 'Super Admin',
    description: 'Akses penuh ke seluruh modul dan pengaturan administrator.',
    icon: Icons.workspace_premium_outlined,
  ),
  _RoleToggleOption(
    key: 'attendance',
    label: 'Kelola Absensi',
    description: 'Melihat dan mengelola data kehadiran karyawan.',
    icon: Icons.how_to_reg_outlined,
  ),
  _RoleToggleOption(
    key: 'requests',
    label: 'Cuti & Izin',
    description: 'Memproses pengajuan cuti dan izin karyawan.',
    icon: Icons.assignment_turned_in_outlined,
  ),
  _RoleToggleOption(
    key: 'calendar',
    label: 'Kalender',
    description: 'Mengatur jadwal dan acara perusahaan.',
    icon: Icons.calendar_month_outlined,
  ),
  _RoleToggleOption(
    key: 'documents',
    label: 'Pemberkasan',
    description: 'Mengelola dokumen dan arsip perusahaan.',
    icon: Icons.folder_shared_outlined,
  ),
  _RoleToggleOption(
    key: 'material',
    label: 'Permintaan Material',
    description: 'Mengelola permintaan dan distribusi material.',
    icon: Icons.inventory_2_outlined,
  ),
  _RoleToggleOption(
    key: 'users',
    label: 'Pengguna',
    description: 'Mengatur profil dan hak akses admin pengguna lain.',
    icon: Icons.people_alt_outlined,
  ),
];

final Set<String> _roleOptionKeys = {
  for (final option in _roleToggleOptions) option.key,
};

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _teamController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String _searchTerm = '';
  _UserEntry? _selectedEntry;
  bool _profileCompleted = false;
  bool _saving = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _currentAdminRoleSub;
  Map<String, bool> _roleStates = {
    for (final option in _roleToggleOptions) option.key: false,
  };
  bool _currentIsSuperAdmin = false;
  Map<String, bool>? _roleStatesBeforeSuper;

  bool get _canEditRoles => _currentIsSuperAdmin;

  @override
  void initState() {
    super.initState();
    _listenToCurrentAdminRoles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _teamController.dispose();
    _departmentController.dispose();
    _roleController.dispose();
    _pinController.dispose();
    _phoneController.dispose();
    _currentAdminRoleSub?.cancel();
    super.dispose();
  }

  void _listenToCurrentAdminRoles() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _currentIsSuperAdmin = false;
      });
      return;
    }
    _currentAdminRoleSub?.cancel();
    _currentAdminRoleSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
          final data = snapshot.data();
          final roles = _readRoles(data?['roles']);
          final isSuper = roles['superAdmin'] == true || roles['admin'] == true;
          if (!mounted) return;
          setState(() {
            _currentIsSuperAdmin = isSuper;
          });
        });
  }

  Map<String, dynamic> _readRoles(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return value.map((key, dynamic v) => MapEntry(key.toString(), v));
    }
    return <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtle = theme.colorScheme.onSurface.withValues(alpha: 0.72);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Manajemen Pengguna',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Kelola profil pengguna, atur informasi tim, dan pantau status kelengkapan profil.',
          style: theme.textTheme.bodyMedium?.copyWith(color: subtle),
        ),
        const SizedBox(height: 22),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 1120;
              if (!wide) {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUserList(compact: true),
                      const SizedBox(height: 18),
                      _buildDetailPane(compact: true),
                    ],
                  ),
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildUserList()),
                  const SizedBox(width: 24),
                  Expanded(flex: 4, child: _buildDetailPane()),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserList({bool compact = false}) {
    final theme = Theme.of(context);
    final baseText = theme.colorScheme.brightness == Brightness.dark
        ? Colors.white
        : theme.colorScheme.onSurface;
    final subtle = baseText.withValues(alpha: 0.65);

    final list = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .limit(500)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Gagal memuat pengguna: ${snapshot.error}',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final docs = snapshot.data!.docs;
        final entries = docs
            .map(
              (doc) => _UserEntry(
                summary: AdminUserSummary.fromSnapshot(doc),
                raw: doc.data(),
              ),
            )
            .toList();

        final query = _searchTerm.trim().toLowerCase();
        final filtered = query.isEmpty
            ? entries
            : entries.where((entry) {
                return entry.matches(query);
              }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_search_outlined,
                    size: 48,
                    color: baseText.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    query.isEmpty
                        ? 'Belum ada pengguna terdaftar.'
                        : 'Tidak ada pengguna yang cocok dengan pencarian.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: subtle),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        filtered.sort((a, b) {
          final createdA =
              a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final createdB =
              b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return createdB.compareTo(createdA);
        });

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 16),
          shrinkWrap: compact,
          physics: compact ? const NeverScrollableScrollPhysics() : null,
          itemBuilder: (context, index) {
            final entry = filtered[index];
            final selected = entry.summary.uid == _selectedEntry?.summary.uid;
            return InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => _selectEntry(entry),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: selected
                      ? Colors.white.withValues(alpha: 0.16)
                      : Colors.white.withValues(alpha: 0.08),
                  border: Border.all(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.45)
                        : Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvatar(entry),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.summary.displayName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: baseText,
                                  ),
                                ),
                              ),
                              if (entry.profileCompleted)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.greenAccent.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.verified_outlined,
                                        size: 16,
                                        color: Colors.greenAccent,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Profil lengkap',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.greenAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (entry.summary.email != null)
                            Text(
                              entry.summary.email!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: subtle,
                              ),
                            ),
                          if (entry.primaryRoleLabel != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              entry.primaryRoleLabel!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: subtle,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              _metaChip(
                                icon: Icons.badge_outlined,
                                label: entry.summary.uid,
                              ),
                              if (entry.pin != null)
                                _metaChip(
                                  icon: Icons.key_rounded,
                                  label: 'PIN ${entry.pin}',
                                ),
                              if (entry.createdAt != null)
                                _metaChip(
                                  icon: Icons.calendar_today_outlined,
                                  label:
                                      'Bergabung ${_formatDate(entry.createdAt!)}',
                                ),
                            ],
                          ),
                          ..._roleChipWidgets(entry),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          separatorBuilder: (context, _) => const SizedBox(height: 12),
          itemCount: filtered.length,
        );
      },
    );

    return GlassContainer(
      borderRadius: 26,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari nama, email, UID, atau PIN pengguna...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
            ),
            onChanged: (value) {
              setState(() => _searchTerm = value);
            },
          ),
          const SizedBox(height: 18),
          if (compact) list else Expanded(child: list),
        ],
      ),
    );
  }

  Widget _buildDetailPane({bool compact = false}) {
    final theme = Theme.of(context);
    final subtle = theme.colorScheme.onSurface.withValues(alpha: 0.72);

    if (_selectedEntry == null) {
      return GlassContainer(
        borderRadius: 26,
        padding: EdgeInsets.symmetric(
          vertical: compact ? 32 : 48,
          horizontal: compact ? 24 : 30,
        ),
        child: compact
            ? _EmptyDetailPlaceholder.compact(color: subtle)
            : _EmptyDetailPlaceholder.wide(
                color: subtle,
                textTheme: theme.textTheme,
              ),
      );
    }

    final entry = _selectedEntry!;

    final detailBodyChildren = <Widget>[
      if (_shouldShowRolesForEntry(entry)) ...[
        _buildRoleSection(entry),
        const SizedBox(height: 18),
      ],
      _buildTextField(
        controller: _nameController,
        label: 'Nama lengkap',
        placeholder: 'Nama sesuai profil',
      ),
      const SizedBox(height: 14),
      _buildTextField(
        controller: _teamController,
        label: 'Tim / Divisi',
        placeholder: 'Contoh: Operasional',
      ),
      const SizedBox(height: 14),
      _buildTextField(
        controller: _departmentController,
        label: 'Departemen',
        placeholder: 'Contoh: HRD',
      ),
      const SizedBox(height: 14),
      _buildTextField(
        controller: _roleController,
        label: 'Jabatan',
        placeholder: 'Contoh: Supervisor',
      ),
      const SizedBox(height: 14),
      _buildTextField(
        controller: _pinController,
        label: 'PIN',
        placeholder: 'PIN absen',
        keyboardType: TextInputType.number,
      ),
      const SizedBox(height: 14),
      _buildTextField(
        controller: _phoneController,
        label: 'Nomor telepon',
        placeholder: 'Contoh: 08123456789',
        keyboardType: TextInputType.phone,
      ),
      const SizedBox(height: 18),
      SwitchListTile.adaptive(
        value: _profileCompleted,
        activeTrackColor: Colors.greenAccent.withValues(alpha: 0.45),
        activeThumbColor: Colors.greenAccent,
        title: const Text('Profil sudah lengkap'),
        subtitle: Text(
          'Gunakan ini untuk menandai apakah pengguna telah melengkapi seluruh data profilnya.',
          style: theme.textTheme.bodySmall?.copyWith(color: subtle),
        ),
        onChanged: (value) {
          setState(() => _profileCompleted = value);
        },
      ),
      const SizedBox(height: 24),
      Row(
        children: [
          ElevatedButton.icon(
            onPressed: _saving ? null : _saveUserChanges,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(_saving ? 'Menyimpan...' : 'Simpan perubahan'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: _saving ? null : _resetForm,
            child: const Text('Batalkan perubahan'),
          ),
        ],
      ),
    ];

    final detailBody = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: detailBodyChildren,
      ),
    );

    return GlassContainer(
      borderRadius: 26,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(entry, radius: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.summary.displayName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (entry.summary.email != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        entry.summary.email!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: subtle,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        _metaChip(
                          icon: Icons.fingerprint,
                          label: entry.summary.uid,
                        ),
                        if (entry.pin != null)
                          _metaChip(
                            icon: Icons.key_outlined,
                            label: 'PIN ${entry.pin}',
                          ),
                        if (entry.createdAt != null)
                          _metaChip(
                            icon: Icons.calendar_today_outlined,
                            label:
                                'Dibuat ${_formatDate(entry.createdAt!, includeTime: true)}',
                          ),
                        if (entry.updatedAt != null)
                          _metaChip(
                            icon: Icons.schedule_outlined,
                            label:
                                'Diubah ${_formatDate(entry.updatedAt!, includeTime: true)}',
                          ),
                      ],
                    ),
                    ..._roleChipWidgets(entry),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Salin tautan Firestore',
                onPressed: () {
                  final url =
                      'https://console.firebase.google.com/u/0/project/${FirebaseFirestore.instance.app.options.projectId}/firestore/data/~2Fusers~2F${entry.summary.uid}';
                  Clipboard.setData(ClipboardData(text: url));
                  if (!mounted) return;
                  showGlassSnackBar(
                    context,
                    message: 'Tautan disalin ke clipboard.',
                    tone: GlassSnackTone.info,
                  );
                },
                icon: const Icon(Icons.copy_rounded),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (compact) detailBody else Expanded(child: detailBody),
        ],
      ),
    );
  }

  bool _shouldShowRolesForEntry(_UserEntry entry) =>
      _canEditRoles || entry.hasAnyAdminAccess;

  Widget _buildRoleSection(_UserEntry entry) {
    final theme = Theme.of(context);
    final helperColor = theme.colorScheme.onSurface.withValues(alpha: 0.68);
    final canEdit = _canEditRoles;
    final superActive = _roleStates['superAdmin'] == true;

    final helperText = canEdit
        ? 'Pilih modul yang dapat diakses ketika pengguna login ke dashboard admin.'
        : 'Anda hanya dapat melihat hak akses. Minta Super Admin untuk melakukan perubahan.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hak akses admin',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            helperText,
            style: theme.textTheme.bodySmall?.copyWith(color: helperColor),
          ),
          const SizedBox(height: 16),
          for (final option in _roleToggleOptions)
            _RoleToggleTile(
              option: option,
              value: option.key == 'superAdmin'
                  ? superActive
                  : (superActive ? true : (_roleStates[option.key] ?? false)),
              enabled: canEdit && (option.key == 'superAdmin' || !superActive),
              lockedBySuper: superActive && option.key != 'superAdmin',
              onChanged: (value) => _onRoleChanged(option.key, value),
            ),
        ],
      ),
    );
  }

  List<Widget> _roleChipWidgets(_UserEntry entry) {
    final chips = _buildRoleChips(entry);
    if (chips.isEmpty) return const [];
    return [
      const SizedBox(height: 10),
      Wrap(spacing: 10, runSpacing: 8, children: chips),
    ];
  }

  List<Widget> _buildRoleChips(_UserEntry entry) {
    if (!entry.hasAnyAdminAccess) return const [];
    if (entry.isSuperAdmin) {
      return [
        _metaChip(icon: Icons.workspace_premium_outlined, label: 'Super Admin'),
      ];
    }
    final chips = <Widget>[];
    for (final option in _roleToggleOptions) {
      if (option.key == 'superAdmin') continue;
      if (entry.roleStates[option.key] == true) {
        chips.add(_metaChip(icon: option.icon, label: option.label));
      }
    }
    return chips;
  }

  void _onRoleChanged(String key, bool value) {
    final updated = Map<String, bool>.from(_roleStates);
    if (key == 'superAdmin') {
      if (value) {
        _roleStatesBeforeSuper = Map<String, bool>.from(_roleStates);
      } else {
        final restore = _roleStatesBeforeSuper;
        final reset = {
          for (final option in _roleToggleOptions) option.key: false,
        };
        if (restore != null) {
          for (final entry in restore.entries) {
            reset[entry.key] = entry.value;
          }
        }
        reset['superAdmin'] = false;
        _roleStatesBeforeSuper = null;
        setState(() {
          _roleStates = reset;
        });
        return;
      }
    }
    updated[key] = value;
    setState(() {
      _roleStates = updated;
    });
  }

  void _applyRoleUpdates(Map<String, dynamic> updates, _UserEntry entry) {
    final superActive = _roleStates['superAdmin'] == true;
    final existingRoles = _readRoles(entry.raw['roles']);
    final preservedRoles = <String, dynamic>{};

    existingRoles.forEach((key, value) {
      if (key == 'admin' || key == 'superAdmin') return;
      if (_roleOptionKeys.contains(key)) return;
      preservedRoles[key] = value;
    });

    final rolesMap = <String, dynamic>{...preservedRoles};
    final keysToEnable = <String>{};

    if (superActive) {
      keysToEnable.add('superAdmin');
      keysToEnable.add('admin');
      for (final option in _roleToggleOptions) {
        if (option.key == 'superAdmin') continue;
        keysToEnable.add(option.key);
      }
    } else {
      for (final option in _roleToggleOptions) {
        final key = option.key;
        if (key == 'superAdmin') continue;
        if (_roleStates[key] == true) {
          keysToEnable.add(key);
        }
      }
    }

    for (final key in keysToEnable) {
      rolesMap[key] = true;
    }

    if (!superActive) {
      rolesMap.remove('admin');
      rolesMap.remove('superAdmin');
    }

    if (rolesMap.isEmpty) {
      updates['roles'] = FieldValue.delete();
    } else {
      updates['roles'] = rolesMap;
    }

    for (final key in _roleOptionKeys) {
      final path = 'roles.$key';
      if (rolesMap.containsKey(key)) {
        updates[path] = true;
      } else {
        updates[path] = FieldValue.delete();
      }
    }

    updates['roles.admin'] = rolesMap.containsKey('admin')
        ? true
        : FieldValue.delete();
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? placeholder,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: placeholder,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _metaChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(_UserEntry entry, {double radius = 22}) {
    final theme = Theme.of(context);
    final initials = entry.summary.displayName.isNotEmpty
        ? entry.summary.displayName[0].toUpperCase()
        : '?';
    final photoUrl = entry.summary.photoUrl;
    final placeholder = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.18),
      ),
      child: Text(
        initials,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );

    if (photoUrl == null || photoUrl.isEmpty) {
      return SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: placeholder,
      );
    }

    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: ClipOval(
        child: Image.network(
          photoUrl,
          fit: BoxFit.cover,
          width: radius * 2,
          height: radius * 2,
          errorBuilder: (context, error, stackTrace) {
            debugPrint(
              'Failed to load user photo for ${entry.summary.uid}: $error',
            );
            return placeholder;
          },
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return placeholder;
          },
        ),
      ),
    );
  }

  Future<void> _saveUserChanges() async {
    final entry = _selectedEntry;
    if (entry == null) return;
    final uid = entry.summary.uid;

    final name = _nameController.text.trim();
    final team = _teamController.text.trim();
    final department = _departmentController.text.trim();
    final role = _roleController.text.trim();
    final pin = _pinController.text.trim();
    final phone = _phoneController.text.trim();

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      'profileCompleted': _profileCompleted,
    };

    void setOrDelete(String key, String value, {bool alsoDisplayName = false}) {
      if (value.isEmpty) {
        updates[key] = FieldValue.delete();
        if (alsoDisplayName) {
          updates['displayName'] = FieldValue.delete();
        }
      } else {
        updates[key] = value;
        if (alsoDisplayName) {
          updates['displayName'] = value;
        }
      }
    }

    setOrDelete('name', name, alsoDisplayName: true);
    setOrDelete('team', team);
    setOrDelete('department', department);
    setOrDelete('role', role);
    setOrDelete('division', department.isEmpty ? team : department);
    setOrDelete('pin', pin);
    setOrDelete('userPin', pin);
    setOrDelete('chatPin', pin);
    setOrDelete('phone', phone);
    setOrDelete('phoneNumber', phone);

    if (_canEditRoles) {
      _applyRoleUpdates(updates, entry);
    }

    setState(() => _saving = true);
    FocusScope.of(context).unfocus();
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(updates, SetOptions(merge: true));
      if (!mounted) return;
      showGlassSnackBar(
        context,
        message: 'Profil pengguna berhasil diperbarui.',
        tone: GlassSnackTone.success,
      );
    } catch (e) {
      if (!mounted) return;
      showGlassSnackBar(
        context,
        message: 'Gagal menyimpan perubahan: $e',
        tone: GlassSnackTone.error,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _resetForm() {
    if (_selectedEntry == null) return;
    _populateForm(_selectedEntry!);
  }

  void _selectEntry(_UserEntry entry) {
    setState(() {
      _selectedEntry = entry;
    });
    _populateForm(entry);
  }

  void _populateForm(_UserEntry entry) {
    final raw = entry.raw;
    String pickFirst(List<dynamic> keys) {
      for (final key in keys) {
        if (key is String && key.trim().isNotEmpty) return key.trim();
      }
      return '';
    }

    _nameController.text = pickFirst([
      raw['name'],
      raw['displayName'],
      raw['fullName'],
      entry.summary.displayName,
    ]);
    _teamController.text = pickFirst([raw['team'], raw['division']]);
    _departmentController.text = pickFirst([
      raw['department'],
      raw['division'],
    ]);
    _roleController.text = pickFirst([
      raw['role'],
      raw['jobTitle'],
      raw['position'],
    ]);
    _pinController.text = pickFirst([
      raw['pin'],
      raw['chatPin'],
      raw['userPin'],
      raw['PIN'],
    ]);
    _phoneController.text = pickFirst([
      raw['phone'],
      raw['phoneNumber'],
      raw['mobile'],
      raw['contactNumber'],
    ]);
    final newRoleStates = {
      for (final option in _roleToggleOptions)
        option.key: entry.roleStates[option.key] ?? false,
    };
    setState(() {
      _profileCompleted = raw['profileCompleted'] == true;
      _roleStates = newRoleStates;
      _roleStatesBeforeSuper = null;
    });
  }

  String _formatDate(DateTime value, {bool includeTime = false}) {
    final local = value.toLocal();
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
    final day = local.day.toString().padLeft(2, '0');
    final month = months[local.month - 1];
    final base = '$day $month ${local.year}';
    if (!includeTime) return base;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$base, $hour:$minute';
  }
}

class _RoleToggleTile extends StatelessWidget {
  const _RoleToggleTile({
    required this.option,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.lockedBySuper = false,
  });

  final _RoleToggleOption option;
  final bool value;
  final bool enabled;
  final bool lockedBySuper;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleColor = Colors.white.withValues(alpha: enabled ? 0.72 : 0.62);
    final highlight = option.key == 'superAdmin' && value;
    final titleColor = highlight
        ? Colors.amberAccent
        : Colors.white.withValues(alpha: 0.95);
    final iconColor = highlight
        ? Colors.amberAccent
        : Colors.white.withValues(alpha: enabled ? 0.92 : 0.6);
    final description = lockedBySuper
        ? '${option.description}\nAktif otomatis karena Super Admin.'
        : option.description;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(option.icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: option.key == 'superAdmin'
                        ? FontWeight.w700
                        : FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: subtitleColor,
                    height: 1.28,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeColor: Colors.greenAccent,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _EmptyDetailPlaceholder extends StatelessWidget {
  const _EmptyDetailPlaceholder._({
    required this.iconSize,
    required this.alignment,
    required this.layout,
  });

  factory _EmptyDetailPlaceholder.compact({required Color color}) {
    return _EmptyDetailPlaceholder._(
      iconSize: 64,
      alignment: Alignment.center,
      layout: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: 64, color: color),
          const SizedBox(height: 16),
          const _EmptyDetailTitle(),
          const SizedBox(height: 8),
          _EmptyDetailDescription(color: color),
        ],
      ),
    );
  }

  factory _EmptyDetailPlaceholder.wide({
    required Color color,
    required TextTheme textTheme,
  }) {
    return _EmptyDetailPlaceholder._(
      iconSize: 72,
      alignment: Alignment.centerLeft,
      layout: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Icon(Icons.person_outline, size: 48, color: color),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const _EmptyDetailTitle(alignment: TextAlign.left),
                const SizedBox(height: 10),
                _EmptyDetailDescription(
                  color: color,
                  alignment: TextAlign.left,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  final double iconSize;
  final Alignment alignment;
  final Widget layout;

  @override
  Widget build(BuildContext context) {
    return Align(alignment: alignment, child: layout);
  }
}

class _EmptyDetailTitle extends StatelessWidget {
  const _EmptyDetailTitle({this.alignment = TextAlign.center});

  final TextAlign alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'Pilih pengguna',
      textAlign: alignment,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _EmptyDetailDescription extends StatelessWidget {
  const _EmptyDetailDescription({
    required this.color,
    this.alignment = TextAlign.center,
  });

  final Color color;
  final TextAlign alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'Klik salah satu pengguna di daftar untuk melihat detail profil dan melakukan perubahan.',
      style: theme.textTheme.bodyMedium?.copyWith(color: color),
      textAlign: alignment,
    );
  }
}

class _UserEntry {
  _UserEntry({required this.summary, required this.raw})
    : createdAt = _timestampToDateTime(raw['createdAt']),
      updatedAt = _timestampToDateTime(raw['updatedAt']),
      profileCompleted = raw['profileCompleted'] == true,
      pin =
          raw['pin'] ??
          raw['chatPin'] ??
          raw['userPin'] ??
          raw['PIN']?.toString(),
      roleStates = _buildRoleStates(raw['roles']);

  final AdminUserSummary summary;
  final Map<String, dynamic> raw;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool profileCompleted;
  final String? pin;
  final Map<String, bool> roleStates;

  String? get primaryRoleLabel =>
      summary.department ?? summary.team ?? summary.role;

  bool get isSuperAdmin => roleStates['superAdmin'] == true;

  bool get hasAnyAdminAccess => roleStates.values.any((value) => value == true);

  bool hasRole(String key) => roleStates[key] == true;

  bool matches(String query) {
    final lowered = query.toLowerCase();
    bool contains(dynamic value) {
      if (value == null) return false;
      return value.toString().toLowerCase().contains(lowered);
    }

    return contains(summary.displayName) ||
        contains(summary.email) ||
        contains(summary.uid) ||
        contains(pin) ||
        raw.entries.any((entry) => contains(entry.value));
  }

  static Map<String, bool> _buildRoleStates(dynamic rawRoles) {
    final states = {for (final option in _roleToggleOptions) option.key: false};
    final map = _asRoleMap(rawRoles);
    if (map == null) return states;

    bool toBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final lowered = value.toLowerCase();
        return lowered == 'true' || lowered == '1';
      }
      return false;
    }

    for (final option in _roleToggleOptions) {
      if (toBool(map[option.key])) {
        states[option.key] = true;
      }
    }

    if (toBool(map['admin'])) {
      states['superAdmin'] = true;
    }

    return states;
  }

  static Map<String, dynamic>? _asRoleMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, dynamic v) => MapEntry(key.toString(), v));
    }
    return null;
  }

  static DateTime? _timestampToDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
