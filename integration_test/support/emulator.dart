// Dukungan emulator Firebase untuk integration test Black Box.
//
// - Menyiapkan Firebase (project "demo-cvm") dan mengarahkan Auth, Firestore,
//   dan Storage ke Firebase Emulator (default host 10.0.2.2 = localhost PC dari
//   dalam Android emulator).
// - Menyediakan klien REST "admin" (header `Authorization: Bearer owner`) untuk
//   mengisi data awal TANPA melewati security rules, membaca hasil, dan
//   membersihkan data antar-tes.
//
// Tidak ada kode aplikasi yang diubah. Tidak ada rahasia yang dibaca/dicetak.
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Project id khusus emulator. Awalan "demo-" membuat emulator menolak
/// koneksi ke layanan produksi.
const String kProjectId = 'demo-cvm';

/// 10.0.2.2 = loopback PC host dari dalam Android emulator.
/// Ganti dengan `--dart-define=EMULATOR_HOST=...` bila perlu.
const String kEmulatorHost =
    String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');
const int kAuthPort =
    int.fromEnvironment('AUTH_EMULATOR_PORT', defaultValue: 9099);
const int kFirestorePort =
    int.fromEnvironment('FIRESTORE_EMULATOR_PORT', defaultValue: 8080);
const int kStoragePort =
    int.fromEnvironment('STORAGE_EMULATOR_PORT', defaultValue: 9199);

const String kDefaultPassword = 'Passw0rd!23';

/// Akun uji yang dibuat di Auth emulator.
class TestAccount {
  TestAccount({
    required this.uid,
    required this.email,
    required this.password,
    required this.name,
  });

  final String uid;
  final String email;
  final String password;
  final String name;
}

class Emu {
  Emu._();

  static bool _ready = false;
  static int _seq = 0;

  static const Map<String, String> _adminHeaders = <String, String>{
    'Authorization': 'Bearer owner',
    'Content-Type': 'application/json',
  };

  static String get _authBase => 'http://$kEmulatorHost:$kAuthPort';
  static String get _fsBase => 'http://$kEmulatorHost:$kFirestorePort';

  // ---------------------------------------------------------------------------
  // Inisialisasi (sekali per proses)
  // ---------------------------------------------------------------------------

  /// Inisialisasi Firebase + arahkan ke emulator. Aman dipanggil berulang.
  ///
  /// Tidak memanggil `main()` aplikasi (butuh kamera, FCM, App Check, dll.) dan
  /// tidak memakai `DefaultFirebaseOptions` (yang membaca `.env`).
  static Future<void> setup() async {
    if (_ready) return;

    // Beberapa kode aplikasi membaca dotenv; sediakan env kosong agar tidak
    // melempar NotInitializedError. Tidak ada nilai rahasia yang dimuat.
    try {
      dotenv.testLoad(fileInput: '');
    } catch (_) {}

    await _initFirebase();

    final String actual = Firebase.app().options.projectId;
    if (actual != kProjectId) {
      throw StateError(
        'Firebase default app memakai projectId "$actual", bukan "$kProjectId". '
        'Jalankan integration_test/ci/prepare_ci.sh (mengganti '
        'android/app/google-services.json dengan versi demo) sebelum '
        'flutter test integration_test. Dibatalkan agar tidak menyentuh '
        'konfigurasi proyek asli.',
      );
    }

    // Urutan penting: settings dulu, baru useEmulator.
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: false);
    // Pada versi cloud_firestore/firebase_storage tertentu return type-nya void,
    // pada versi lain Future; dipanggil sebagai statement agar valid di keduanya.
    FirebaseFirestore.instance.useFirestoreEmulator(
      kEmulatorHost,
      kFirestorePort,
    );
    await FirebaseAuth.instance.useAuthEmulator(kEmulatorHost, kAuthPort);
    FirebaseStorage.instance.useStorageEmulator(kEmulatorHost, kStoragePort);

    _ready = true;
  }

  static Future<void> _initFirebase() async {
    if (Firebase.apps.isNotEmpty) return;
    try {
      // Memakai konfigurasi native (google-services.json demo dari CI).
      await Firebase.initializeApp();
    } catch (_) {
      try {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: 'fake-api-key',
            appId: '1:000000000000:android:0000000000000000',
            messagingSenderId: '000000000000',
            projectId: kProjectId,
            storageBucket: '$kProjectId.appspot.com',
          ),
        );
      } on FirebaseException catch (e) {
        if (e.code != 'duplicate-app') rethrow;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Pembersihan
  // ---------------------------------------------------------------------------

  /// Hapus semua akun Auth dan seluruh dokumen Firestore di emulator.
  /// (Storage tidak punya endpoint hapus; nama objek dibuat unik per tes.)
  static Future<void> clearAll() async {
    final http.Response fs = await http.delete(
      Uri.parse(
        '$_fsBase/emulator/v1/projects/$kProjectId/databases/(default)/documents',
      ),
    );
    _expectOk(fs, 'hapus data Firestore emulator');
    final http.Response au = await http.delete(
      Uri.parse('$_authBase/emulator/v1/projects/$kProjectId/accounts'),
    );
    _expectOk(au, 'hapus akun Auth emulator');
  }

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  /// Membuat akun email+password di Auth emulator lewat REST admin.
  /// [emailVerified] = false mensimulasikan akun yang belum verifikasi email.
  static Future<TestAccount> createAccount({
    required String tag,
    String name = 'Budi Santoso',
    bool emailVerified = true,
    String password = kDefaultPassword,
  }) async {
    final int stamp = DateTime.now().microsecondsSinceEpoch + (_seq++);
    final String wantedUid = 'u${tag.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}x$stamp';
    final String email = '${tag.toLowerCase()}.$stamp@demo-cvm.test';

    // Jalur 1: endpoint admin (dipakai firebase-admin createUser).
    final http.Response created = await http.post(
      Uri.parse(
        '$_authBase/identitytoolkit.googleapis.com/v1/projects/$kProjectId/accounts',
      ),
      headers: _adminHeaders,
      body: jsonEncode(<String, dynamic>{
        'localId': wantedUid,
        'email': email,
        'password': password,
        'displayName': name,
        'emailVerified': emailVerified,
      }),
    );
    if (created.statusCode == 200) {
      final Map<String, dynamic> json =
          jsonDecode(created.body) as Map<String, dynamic>;
      final String? localId = json['localId'] as String?;
      if (localId != null && localId.isNotEmpty) {
        return TestAccount(
          uid: localId,
          email: email,
          password: password,
          name: name,
        );
      }
    }

    // Jalur 2 (cadangan): signUp biasa + update admin.
    final http.Response signUp = await http.post(
      Uri.parse(
        '$_authBase/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key',
      ),
      headers: const <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(<String, dynamic>{
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    );
    _expectOk(signUp, 'signUp akun uji');
    final String localId =
        (jsonDecode(signUp.body) as Map<String, dynamic>)['localId'] as String;
    final http.Response update = await http.post(
      Uri.parse(
        '$_authBase/identitytoolkit.googleapis.com/v1/projects/$kProjectId/accounts:update',
      ),
      headers: _adminHeaders,
      body: jsonEncode(<String, dynamic>{
        'localId': localId,
        'displayName': name,
        'emailVerified': emailVerified,
      }),
    );
    _expectOk(update, 'update akun uji (displayName/emailVerified)');
    return TestAccount(
      uid: localId,
      email: email,
      password: password,
      name: name,
    );
  }

  /// Login klien Firebase sebagai [account] (untuk tes tingkat halaman).
  static Future<void> signIn(TestAccount account) async {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: account.email,
      password: account.password,
    );
  }

  static Future<void> signOutQuietly() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }

  /// Daftar kode OOB (verifikasi email / reset password) yang "dikirim"
  /// oleh Auth emulator. Tiap item: email, requestType, oobCode, oobLink.
  static Future<List<Map<String, dynamic>>> oobCodes() async {
    final http.Response res = await http.get(
      Uri.parse('$_authBase/emulator/v1/projects/$kProjectId/oobCodes'),
    );
    _expectOk(res, 'baca oobCodes');
    final Map<String, dynamic> json =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> list = (json['oobCodes'] as List<dynamic>?) ?? const [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<bool> hasOobCode(String email, String requestType) async {
    final List<Map<String, dynamic>> all = await oobCodes();
    return all.any(
      (c) =>
          (c['email'] as String?)?.toLowerCase() == email.toLowerCase() &&
          c['requestType'] == requestType,
    );
  }

  // ---------------------------------------------------------------------------
  // Firestore (REST admin, melewati rules)
  // ---------------------------------------------------------------------------

  static Uri _docUri(String collection, [String? id]) => Uri.parse(
        '$_fsBase/v1/projects/$kProjectId/databases/(default)/documents/$collection${id == null ? '' : '/$id'}',
      );

  /// Tulis (buat/timpa) dokumen. Nilai: null/bool/int/double/String/DateTime/
  /// List/Map. DateTime disimpan sebagai Timestamp.
  static Future<void> seedDoc(
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async {
    final http.Response res = await http.patch(
      _docUri(collection, id),
      headers: _adminHeaders,
      body: jsonEncode(<String, dynamic>{
        'fields': data.map((k, v) => MapEntry(k, _encode(v))),
      }),
    );
    _expectOk(res, 'seed $collection/$id');
  }

  /// Tulis dokumen dengan id otomatis; mengembalikan id.
  static Future<String> seedDocAuto(
    String collection,
    Map<String, dynamic> data,
  ) async {
    final String id = 'seed${DateTime.now().microsecondsSinceEpoch}x${_seq++}';
    await seedDoc(collection, id, data);
    return id;
  }

  static Future<Map<String, dynamic>?> getDoc(
    String collection,
    String id,
  ) async {
    final http.Response res =
        await http.get(_docUri(collection, id), headers: _adminHeaders);
    if (res.statusCode == 404) return null;
    _expectOk(res, 'baca $collection/$id');
    final Map<String, dynamic> json =
        jsonDecode(res.body) as Map<String, dynamic>;
    return _decodeFields(json['fields'] as Map<String, dynamic>?);
  }

  /// Semua dokumen dalam koleksi (maks. 300), tiap map memuat kunci `_id`.
  static Future<List<Map<String, dynamic>>> listDocs(String collection) async {
    final http.Response res = await http.get(
      Uri.parse('${_docUri(collection)}?pageSize=300'),
      headers: _adminHeaders,
    );
    if (res.statusCode == 404) return <Map<String, dynamic>>[];
    _expectOk(res, 'daftar $collection');
    final Map<String, dynamic> json =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> docs =
        (json['documents'] as List<dynamic>?) ?? const <dynamic>[];
    return docs.map((d) {
      final Map<String, dynamic> m = Map<String, dynamic>.from(d as Map);
      final Map<String, dynamic> out =
          _decodeFields(m['fields'] as Map<String, dynamic>?);
      out['_id'] = (m['name'] as String).split('/').last;
      return out;
    }).toList();
  }

  /// Profil `users/{uid}` seperti yang diharapkan aplikasi.
  static Future<void> seedUserProfile(
    TestAccount a, {
    String? role,
    bool profileCompleted = true,
    String? pin,
    Map<String, dynamic>? extra,
  }) {
    return seedDoc('users', a.uid, <String, dynamic>{
      'name': a.name,
      'email': a.email,
      if (role != null) 'role': role,
      'profileCompleted': profileCompleted,
      if (pin != null) ...<String, dynamic>{
        'pin': pin,
        'chatPin': pin,
        'userPin': pin,
      },
      'createdAt': DateTime.now(),
      if (extra != null) ...extra,
    });
  }

  // ---------------------------------------------------------------------------
  // Encoder / decoder nilai Firestore REST
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _encode(Object? v) {
    if (v == null) return <String, dynamic>{'nullValue': null};
    if (v is bool) return <String, dynamic>{'booleanValue': v};
    if (v is int) return <String, dynamic>{'integerValue': v.toString()};
    if (v is double) return <String, dynamic>{'doubleValue': v};
    if (v is String) return <String, dynamic>{'stringValue': v};
    if (v is DateTime) {
      return <String, dynamic>{'timestampValue': v.toUtc().toIso8601String()};
    }
    if (v is List) {
      return <String, dynamic>{
        'arrayValue': <String, dynamic>{
          'values': v.map(_encode).toList(),
        },
      };
    }
    if (v is Map) {
      return <String, dynamic>{
        'mapValue': <String, dynamic>{
          'fields': v.map((k, val) => MapEntry(k.toString(), _encode(val))),
        },
      };
    }
    throw ArgumentError('Tipe tidak didukung untuk seed: ${v.runtimeType}');
  }

  static Map<String, dynamic> _decodeFields(Map<String, dynamic>? fields) {
    final Map<String, dynamic> out = <String, dynamic>{};
    (fields ?? const <String, dynamic>{}).forEach((k, v) {
      out[k] = _decode(v as Map<String, dynamic>);
    });
    return out;
  }

  static Object? _decode(Map<String, dynamic> v) {
    if (v.containsKey('nullValue')) return null;
    if (v.containsKey('stringValue')) return v['stringValue'];
    if (v.containsKey('booleanValue')) return v['booleanValue'];
    if (v.containsKey('integerValue')) {
      return int.parse(v['integerValue'].toString());
    }
    if (v.containsKey('doubleValue')) return (v['doubleValue'] as num).toDouble();
    if (v.containsKey('timestampValue')) {
      return DateTime.parse(v['timestampValue'] as String);
    }
    if (v.containsKey('arrayValue')) {
      final List<dynamic> values =
          ((v['arrayValue'] as Map<String, dynamic>)['values']
                  as List<dynamic>?) ??
              const <dynamic>[];
      return values.map((e) => _decode(e as Map<String, dynamic>)).toList();
    }
    if (v.containsKey('mapValue')) {
      return _decodeFields(
        (v['mapValue'] as Map<String, dynamic>)['fields']
            as Map<String, dynamic>?,
      );
    }
    return v.toString();
  }

  static void _expectOk(http.Response res, String what) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError(
        'Gagal $what: HTTP ${res.statusCode} ${res.body}. Pastikan Firebase '
        'Emulator (auth/firestore/storage) berjalan dan dapat dijangkau dari '
        'emulator Android di $kEmulatorHost.',
      );
    }
  }
}
