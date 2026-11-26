# Integration Test UI Black Box (Flutter + Firebase Emulator)

Folder ini berisi uji otomatis UI untuk sebagian kasus uji Black Box
(`Hasil_Pengujian.xlsx`, lembar "Black Box", BB-01 s.d. BB-69) aplikasi
karyawan PT Cipta Vera Mandiri. Uji dijalankan pada emulator Android bersama
Firebase Emulator (Auth, Firestore, Storage) dengan project id **`demo-cvm`**.
Tidak ada project Firebase asli yang disentuh.

> Status: kode ditulis dan diperiksa secara statis terhadap sumber aplikasi.
> **Belum pernah dikompilasi atau dijalankan**, karena Flutter dan pub.dev tidak
> tersedia di lingkungan penulisan. Harapkan perbaikan kecil pada eksekusi CI
> pertama (lihat bagian "Risiko").

## 1. Pendekatan

Dipilih **pendekatan (b): uji tingkat halaman**. Halaman asli aplikasi dipompa
satu per satu di dalam `GetMaterialApp`. Repository dan view model **bawaan**
halaman dipakai apa adanya (tanpa fake) sehingga memakai `FirebaseAuth.instance`,
`FirebaseFirestore.instance`, dan `FirebaseStorage.instance` yang sudah
diarahkan ke emulator. Tidak ada kode aplikasi yang diubah.

Mengapa tidak pendekatan (a), yaitu menjalankan aplikasi penuh dari rute `/splash`:

- `main()` tidak bisa dipanggil dari tes. Ia memerlukan `availableCameras()`,
  App Check, `FaceRecognitionService`, notifikasi lokal, dan FCM. Konfigurasi
  Firebase-nya juga dibaca dari `.env` lewat `DefaultFirebaseOptions`.
- Root widget **bisa** dibangun sendiri (`GetMaterialApp(initialRoute: Routes.SPLASH,
  getPages: AppPages.routes)` setelah `Firebase.initializeApp` dan `useXxxEmulator`).
  Namun rute `/home` (`HomePage`) langsung membuat lima tab sekaligus (chat, kalender,
  profil, pengaturan). Tab-tab itu memakai RSS berita (`banjarmasin.tribunnews.com`),
  API hari libur (`api-harilibur.vercel.app`), notifikasi lokal, dan FCM.
  Layanan-layanan itu tidak diinisialisasi bila `main()` dilewati, sehingga tes
  menjadi rapuh dan bergantung jaringan luar.
- Pendekatan (b) memberi pengecekan yang sama atas perilaku yang diuji
  (validasi, tulis ke Firestore/Storage, status di UI) dengan penyebab gagal
  yang jelas.

Konsekuensi yang perlu dicatat di Bab 4:

- Kasus yang berakhir di "Beranda" (BB-03, BB-10) dibuktikan lewat navigasi
  atau callback yang dipanggil aplikasi (`onLoginSuccess`, rute `/home`).
  Halaman Beranda asli diganti penanda `BERANDA_STUB`. Itu sebabnya BB-03 dan
  BB-10 berstatus "otomatis sebagian".
- Pengecekan data memakai REST Firebase Emulator, bukan UI Admin.

### Pengisian data awal (seeding)

Seeding tidak memakai SDK klien, karena SDK klien tunduk pada security rules.
`support/emulator.dart` memakai REST emulator dengan header
`Authorization: Bearer owner`, yang **melewati rules** (cara yang sama dipakai
Firebase Admin SDK):

| Kebutuhan | Endpoint emulator |
|---|---|
| Buat akun (uid, email, sandi, nama, status verifikasi) | `POST :9099/identitytoolkit.googleapis.com/v1/projects/demo-cvm/accounts` (cadangan: `accounts:signUp` lalu `projects/demo-cvm/accounts:update`) |
| Baca email verifikasi/reset yang "terkirim" | `GET :9099/emulator/v1/projects/demo-cvm/oobCodes` |
| Tulis/baca dokumen Firestore | `PATCH/GET :8080/v1/projects/demo-cvm/databases/(default)/documents/...` |
| Bersihkan data tiap tes | `DELETE :8080/emulator/v1/projects/demo-cvm/databases/(default)/documents` dan `DELETE :9099/emulator/v1/projects/demo-cvm/accounts` |

Setiap tes (`bbTest`) membersihkan emulator, membuat akun dan dokumen sendiri,
lalu keluar akun dan membuang pohon widget. Tes tidak bergantung satu sama lain.
Dokumen `material_requests` yang di-seed memuat seluruh field (termasuk yang
bernilai `null`) persis seperti `MaterialRequestDraft.toFirestorePayload()`,
karena aturan update pemohon di `firestore.rules` menolak penambahan kunci baru.

Operasi yang **memang melewati rules** dan diuji lewat UI sebenarnya:
pengajuan cuti/izin, pembuatan permintaan material beserta unggahan DOCX/PDF,
konfirmasi barang diterima, unggah/hapus dokumen pemberkasan, simpan profil dan
PIN. Bila ada rule yang menolak, tes gagal. Itu temuan yang sah.

### Pengganti perangkat native

- Pemilih berkas: `FilePicker.platform` diganti `FakeFilePicker`
  (`support/test_helpers.dart`). Berkas uji nyata dibuat di direktori sementara
  aplikasi dan benar-benar diunggah ke Storage emulator.
- Dialog tanggal/jam diisi lewat UI (tombol OK). Jam selesai pada form izin
  memakai mode ketik (ikon papan ketik) karena dial analog tidak bisa disentuh
  lewat teks.
- Pengingat lokal dimatikan dengan parameter bawaan halaman
  (`PemberkasanPage(enableReminders: false)`).
- Riwayat kehadiran lokal (SharedPreferences) diisi lewat `AttendanceHistory.saveRecord`
  milik aplikasi (check-in nyata butuh kamera/GPS).

## 2. Prasyarat

1. Flutter stable (sesuai `pubspec.lock`: Dart >= 3.9, Flutter >= 3.35.1).
2. Android emulator (API 30 s.d. 34, x86_64, image `google_apis`) atau perangkat.
3. Node.js 20 dan `firebase-tools`. Java 11 atau lebih baru (dibutuhkan emulator
   Firestore dan Storage).
4. `integration_test/ci/prepare_ci.sh` dijalankan **sebelum build**. Skrip ini
   bekerja di working copy CI dan tidak perlu di-commit:
   - mengganti `android/app/google-services.json` dengan versi demo
     (`demo-cvm`, kunci palsu). Tanpa ini, default app di APK memakai project
     produksi dan `Emu.setup()` sengaja berhenti dengan pesan galat;
   - menambahkan `usesCleartextTraffic="true"` ke manifest **debug** agar SDK
     Firebase boleh memakai HTTP ke `10.0.2.2` (Android 9+ memblokirnya);
   - membuat `.env` kosong bila belum ada (pubspec mendaftarkan `.env` sebagai
     asset; tes tidak membaca nilainya).

## 3. dev_dependencies yang dibutuhkan

Ditambahkan oleh pemilik repo ke `pubspec.yaml`. Saya tidak mengubah file itu.

```yaml
dev_dependencies:
  integration_test:
    sdk: flutter
```

Paket lain **sudah ada** di `dependencies`: `http`, `path_provider`,
`shared_preferences`, `flutter_dotenv`, `firebase_core/auth/storage`,
`cloud_firestore`, `get`, `file_picker` (path lokal). Tidak perlu paket tambahan
(`fake_cloud_firestore` dan `mocktail` milik `test/` tidak dipakai di sini).

## 4. Cara menjalankan

Lokal (emulator Android sudah menyala, dari root repo):

```bash
bash integration_test/ci/prepare_ci.sh
flutter pub get
firebase emulators:exec \
  --project demo-cvm \
  --config integration_test/firebase.integration.json \
  --only auth,firestore,storage \
  "flutter test integration_test --machine"
```

`integration_test/firebase.integration.json` memuat emulator `auth:9099`,
`firestore:8080`, `storage:9199` dan menunjuk ke `firestore.rules` serta
`storage.rules` milik repo. Aplikasi di emulator Android mengakses emulator
Firebase lewat `10.0.2.2`. Ganti dengan
`--dart-define=EMULATOR_HOST=...` bila perlu (port: `AUTH_EMULATOR_PORT`,
`FIRESTORE_EMULATOR_PORT`, `STORAGE_EMULATOR_PORT`).

Di GitHub Actions: lihat contoh `integration_test/ci/example-workflow.yml`
(`reactivecircus/android-emulator-runner` + `firebase emulators:exec`).
Perintah `--machine` menghasilkan JSON-lines. Nama tiap tes diawali ID Black Box
(`BB-21 | ...`), sehingga hasilnya bisa disalin ke kolom "Hasil Aktual" dan
"Status" pada Excel.

Satu berkas tes = satu pembangunan dan pemasangan aplikasi (`flutter test`
menjalankan tiap berkas secara terpisah). Ada 5 berkas, jadi 5 kali pasang.

## 5. Pemetaan tes ke ID Black Box

Kolom "Cakupan": **Penuh** = seluruh hasil yang diharapkan diverifikasi.
**Sebagian** = sebagian langkah tidak bisa diotomasi (dijelaskan).

| Berkas | Nama tes | ID | Hasil yang diharapkan (Excel) | Cakupan |
|---|---|---|---|---|
| `auth_test.dart` | BB-01 | BB-01 | Akun dibuat, email verifikasi dikirim | Penuh. Cek: akun ada di Auth emulator, `emailVerified=false`, ada oobCode `VERIFY_EMAIL`, dokumen `users/{uid}` dibuat, sheet "Verifikasi Email" tampil |
| `auth_test.dart` | BB-02 | BB-02 | Registrasi ditolak, ada pesan validasi | Penuh. Ditambah validasi email, panjang sandi, dan konfirmasi sandi. Tidak ada akun dibuat |
| `auth_test.dart` | BB-03 | BB-03 | Masuk ke Beranda | Sebagian. `onLoginSuccess` dipanggil dan sesi Auth aktif. Halaman Beranda asli tidak dipompa |
| `auth_test.dart` | BB-04 | BB-04 | Login ditolak, email verifikasi dikirim ulang | Penuh |
| `auth_test.dart` | BB-05 | BB-05 | Login tidak diproses, ada pesan validasi | Penuh (juga kasus hanya email terisi) |
| `auth_test.dart` | BB-TAMBAHAN-01 | (usulan baru) | Sandi salah: pesan galat, tetap di login | Baris tambahan, belum ada di Excel (Excel mengizinkan penambahan kasus uji) |
| `auth_test.dart` | BB-08 | BB-08 | Email atur ulang sandi dikirim | Penuh. Cek oobCode `PASSWORD_RESET` |
| `profile_test.dart` | BB-09 | BB-09 | Diarahkan ke Lengkapi Profil | Penuh |
| `profile_test.dart` | BB-10 | BB-10 | Profil tersimpan, PIN terbit, masuk Beranda | Sebagian. Unggah foto (kamera/galeri/crop) manual. Nama dan divisi Finance disimpan, PIN terbit dan terdaftar di `pins`, navigasi ke `/home` |
| `profile_test.dart` | BB-10 (validasi) | BB-10 | (tambahan) Nama/divisi kosong ditolak | Penuh |
| `leave_test.dart` | BB-21 | BB-21 | Cuti tersimpan berstatus Menunggu | Penuh. Lampiran PDF diunggah ke Storage emulator, status `pending`, tampil di Riwayat Cuti |
| `leave_test.dart` | BB-22 | BB-22 | Pesan "Lengkapi data cuti terlebih dahulu" | Penuh |
| `leave_test.dart` | BB-23 | BB-23 | Izin tersimpan berstatus Menunggu | Penuh. Tampil di Riwayat Izin |
| `leave_test.dart` | BB-24 | BB-24 | Pesan "Lengkapi data izin terlebih dahulu" | Penuh |
| `leave_test.dart` | BB-19 | BB-19 | Riwayat kehadiran, cuti, izin tampil beserta status | Penuh untuk tampilan. Catatan check-in disiapkan lewat `AttendanceHistory.saveRecord`, bukan check-in nyata |
| `leave_test.dart` | BB-20 | BB-20 | Keadaan kosong | Penuh |
| `material_test.dart` | BB-36 | BB-36 | Pending; dokumen DOCX dan PDF dibuat | Penuh. Cek dokumen `pending`, 2 item, berkas DOCX/PDF ada di Storage emulator |
| `material_test.dart` | BB-37 | BB-37 | "Tambah minimal satu item material." | Penuh |
| `material_test.dart` | BB-38 | BB-38 | "Lengkapi nama dan jumlah untuk setiap material." | Penuh |
| `material_test.dart` | BB-39 | BB-39 | Menu Material ditolak untuk divisi Finance | Penuh (`MenuGrid` nyata, pesan "Akses hanya untuk ...") |
| `material_test.dart` | BB-39 (pembanding) | BB-39 | (kontrol) Divisi Purchasing and Logistik bisa membuka | Pembanding agar tes negatif tidak kosong |
| `material_test.dart` | BB-40 | BB-40 | Daftar permintaan dengan status dan item | Penuh |
| `material_test.dart` | BB-42 | BB-42 | Status berubah jadi Diterima + nama dan waktu penerima | Penuh. Cek `status=delivered`, `receivedBy`, `receivedByUid`, `receivedAt` |
| `material_test.dart` | BB-43 | BB-43 | Tombol "Barang diterima" tidak tersedia pada Pending | Penuh |
| `pemberkasan_test.dart` | BB-44 | BB-44 | Dokumen tampil di daftar dan pengingat terjadwal | Sebagian. Unggah, kedaluwarsa, masa pengingat 1 bulan, dan tampil di daftar otomatis. Penjadwalan notifikasi lokal manual |
| `pemberkasan_test.dart` | BB-44 (validasi) | BB-44 | (tambahan) Nama kosong dan berkas kosong ditolak | Penuh |
| `pemberkasan_test.dart` | BB-46 | BB-46 | Dokumen dan berkas terhapus, pengingat dibatalkan | Sebagian. Dokumen Firestore dan berkas Storage terhapus. Pembatalan pengingat manual |

Total: 27 tes pada 5 berkas.

## 6. Kasus Black Box yang tetap manual

| ID | Alasan |
|---|---|
| BB-06, BB-07, BB-48 s.d. BB-69 | Dasbor Admin adalah aplikasi Flutter **web** terpisah (`lib/main_admin.dart`). Integration test pada emulator Android tidak menjangkaunya. Perlu uji web atau manual |
| BB-11 s.d. BB-18 | Presensi memerlukan kamera, deteksi wajah (ML Kit), liveness, GPS, dan jadwal waktu WITA. Tidak bisa dimanipulasi tanpa mengubah kode aplikasi |
| BB-25, BB-26 | Kalender memanggil API hari libur eksternal (`api-harilibur.vercel.app`). Hasil bergantung jaringan luar. Bisa ditambahkan kemudian dengan seeding `calendar_events`, tetapi di luar cakupan tahap ini |
| BB-27, BB-28, BB-29 | Chat: perlu dua akun atau perangkat, PIN, dan listener real-time. Di luar cakupan yang disetujui (kandidat tahap berikutnya) |
| BB-30 | Ganti foto profil memakai kamera/galeri dan crop (plugin native) |
| BB-31 | Biometrik (sidik jari) tidak bisa disimulasikan portabel |
| BB-32 | Logout (`SettingsPage`): di luar cakupan yang disetujui. Layak diotomasi kemudian |
| BB-33, BB-34, BB-35 | Notifikasi push/FCM, Cloud Functions, dan jadwal 08.30 WITA. Emulator Functions tidak diaktifkan |
| BB-41 | "Lihat/Unduh PDF" memakai `url_launcher` dan penyimpanan perangkat |
| BB-45 | **Fitur tidak ada di kode.** `PemberkasanPage` (mobile) tidak punya kolom cari atau filter "Akan habis". Perbaiki skenario di Excel atau uji di Dasbor Admin |
| BB-47 | Notifikasi pengingat tengah malam dan tengah hari (`flutter_local_notifications`) |

Bagian dari kasus yang otomatis sebagian dan perlu dilengkapi manual:
foto profil (BB-10), pemeriksaan Beranda sungguhan (BB-03, BB-10),
penjadwalan atau pembatalan pengingat lokal (BB-44, BB-46).

## 7. Temuan saat membaca kode (perlu dicek peneliti)

- **BB-10**: Excel menulis "PIN unik 6 karakter", sedangkan
  `ChatPinService.generateUniquePin` menghasilkan `CV` + 6 digit + `M`
  (9 karakter, mis. `CV123456M`). Tes memeriksa format 9 karakter. Sesuaikan
  teks Excel atau konfirmasi maksud.
- **BB-45**: lihat bagian 6.
- **BB-01**: Excel berbunyi "pilih Sign up"; UI memakai tautan "Sign up" di
  halaman login dan tombol "Sign Up" di halaman registrasi. Tes memompa
  `SignupView` langsung.
- Rute `/signup` terdefinisi tetapi tidak dipasang di `AppPages`
  (registrasi hanya lewat `AuthView`).

## 8. Risiko yang bisa membuat CI pertama gagal

1. **Cleartext HTTP.** Bila `usesCleartextTraffic` tidak aktif, Auth dan Storage
   gagal terhubung ke `10.0.2.2` (galat "Cleartext HTTP traffic ... not
   permitted"). `prepare_ci.sh` menanganinya; pastikan dijalankan sebelum build.
2. **google-services.json.** Bila tidak diganti, `Emu.setup()` berhenti dengan
   pesan jelas (projectId bukan `demo-cvm`). Itu disengaja.
3. **Build Android x86_64.** Dependensi native berat (`google_mlkit_face_detection`,
   `face_verification`, `camera`, plugin lokal `qr_code_scanner` dan
   `file_picker`) belum pernah dibangun di runner CI. Kegagalan Gradle atau NDK
   bisa muncul sebelum tes jalan. Waktu build pertama bisa 10 menit atau lebih.
4. **Aset `.env`.** `pubspec.yaml` mendaftarkan `.env` sebagai asset. File harus
   ada saat build (skrip membuat file kosong bila tidak ada).
5. **Endpoint admin pembuatan akun.** `Emu.createAccount` mencoba
   `projects/demo-cvm/accounts` (dipakai firebase-admin); bila versi
   `firebase-tools` menolaknya, ia otomatis memakai cadangan `signUp` + `accounts:update`.
   Bila keduanya ditolak, semua tes gagal di awal dengan pesan HTTP yang jelas.
6. **Time picker (BB-23).** Pengisian jam selesai memakai mode ketik. Ikon
   papan ketik dicari beberapa varian. Jika versi Flutter mengubah layout,
   tes ini yang paling mungkin perlu penyesuaian.
7. **Teks dan locale.** Tes mengunci locale `en_US` (tombol "OK"). Pencarian
   teks memakai string UI saat ini. Perubahan redaksi di aplikasi akan mematahkan tes yang bersangkutan.
8. **Waktu nyata.** Penantian memakai `pumpUntil` (polling waktu nyata,
   batas 25 s sampai 90 s). Emulator CI yang lambat (terutama pembuatan DOCX/PDF
   pada BB-36) mungkin butuh batas lebih panjang.
9. **Signature plugin.** `Settings(persistenceEnabled: false)`,
   `useFirestoreEmulator`/`useStorageEmulator` (dipanggil sebagai statement
   karena tipe kembaliannya berbeda antar versi), dan `FakeFilePicker.pickFiles`
   (harus sama persis dengan `local_plugins/file_picker`) belum dikompilasi.
10. **Tab Beranda asli tidak diuji** (lihat bagian 1).
11. `flutter test integration_test` dengan banyak berkas memasang ulang APK per
    berkas; waktu total beberapa menit per berkas.
