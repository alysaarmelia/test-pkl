# Pengujian Black Box Otomatis (sisi server) - PT Cipta Vera Mandiri

Folder ini berisi pengujian otomatis yang berjalan **tanpa menyentuh project Firebase sungguhan** (project palsu `demo-cvm`).
Tidak ada berkas aplikasi, aturan, maupun `functions/src` yang diubah; semua berkas baru berada di `tests_ci/`.

| Suite | Folder | Teknologi | Perlu emulator? | Keluaran JUnit |
|---|---|---|---|---|
| Aturan keamanan Firestore + Storage | `tests_ci/firestore_rules/` | Jest + `@firebase/rules-unit-testing` (+ `firebase` v11, API compat) | Ya (Firestore + Storage, butuh Java) | `tests_ci/results/firestore-rules-junit.xml` |
| Logika Cloud Functions | `tests_ci/functions/` | Jest + ts-jest + `firebase-functions-test` (mode offline), `firebase-admin` di-mock | Tidak | `tests_ci/results/functions-junit.xml` |

## 1. Menjalankan secara lokal

Prasyarat: Node.js 20+; untuk suite aturan juga `firebase-tools` dan Java (JDK 11+).

### Suite aturan Firestore + Storage

```bash
cd tests_ci/firestore_rules
npm install
# dari ROOT repo (agar firebase.json dan firestore.rules/storage.rules terbaca):
cd ../..
firebase emulators:exec --project demo-cvm --only firestore,storage "npm --prefix tests_ci/firestore_rules test"
```

Pengujian membaca `firestore.rules` dan `storage.rules` di root repo. Host emulator ditemukan otomatis dari variabel
lingkungan yang diset oleh `emulators:exec`.

### Suite Cloud Functions (offline)

```bash
cd tests_ci/functions
npm install
npm test
```

`functions/src/index.ts` dimuat apa adanya lewat `ts-jest`. `firebase-admin` diganti mock in-memory
(`test/adminMock.js`: Firestore sederhana + `messaging().sendEachForMulticast`), sehingga tidak ada kredensial atau emulator.
Waktu dikendalikan dengan fake timers (jam WITA). Fungsi terjadwal dipanggil lewat `firebase-functions-test` (`wrap`);
pemicu Firestore v2 dipanggil lewat handler mentah `fn.run(event)` karena `wrap` untuk pemicu Firestore memerlukan kelas
`DocumentSnapshot` asli dari firebase-admin.

## 2. Menjalankan di CI (GitHub Actions)

Contoh langkah (Java wajib untuk emulator):

```yaml
- uses: actions/setup-node@v4
  with: { node-version: 20 }
- uses: actions/setup-java@v4
  with: { distribution: temurin, java-version: 17 }
- run: npm install -g firebase-tools
- run: npm --prefix tests_ci/firestore_rules ci || npm --prefix tests_ci/firestore_rules install
- run: npm --prefix tests_ci/functions ci || npm --prefix tests_ci/functions install
- name: Uji aturan Firestore + Storage
  run: firebase emulators:exec --project demo-cvm --only firestore,storage "npm --prefix tests_ci/firestore_rules test"
  continue-on-error: true   # beberapa tes [TEMUAN] memang diperkirakan gagal; hapus jika ingin job merah saat ada temuan
- name: Uji Cloud Functions
  run: npm --prefix tests_ci/functions test
  continue-on-error: true
- uses: actions/upload-artifact@v4
  if: always()
  with: { name: junit-results, path: tests_ci/results/*.xml }
```

Laporan JUnit ditulis ke `tests_ci/results/` oleh `jest-junit` (konfigurasi di `package.json` / `jest.config.js`).

## 3. Konvensi penamaan dan arti hasil

- `BB-xx` = ID kasus pada `Hasil_Pengujian.xlsx` sheet "Black Box" (hanya bagian yang dapat diuji di sisi server/aturan).
  `(sisi aturan)` berarti tes memeriksa penegakan di server untuk kasus yang di UI dijaga klien.
- `RULE-xx` = aturan Firestore/Storage; `RULE-Fxx` = Cloud Functions; `RULE-Sxx` = Storage. Klaim keamanan tambahan di luar Excel.
- `[TEMUAN]` = tes menulis harapan **AMAN/benar** dan **diperkirakan GAGAL** pada kode saat ini. Kegagalannya adalah temuan nyata,
  bukan kesalahan tes. Tes tidak boleh diubah agar lulus; perbaikilah aturan/kodenya.
- Seed data memakai `withSecurityRulesDisabled`; divisi pegawai disimpan di `users/{uid}.role`, peran admin di `users/{uid}.roles`.

### Temuan yang diperkirakan muncul (tes bertanda [TEMUAN])

| Tes | Penjelasan |
|---|---|
| RULE-04, RULE-05, RULE-06 | Pemilik dokumen `users/{uid}` dapat mengubah/membuat `roles` miliknya sendiri (eskalasi hak ke superAdmin). `userAllowedKeys()` ada di aturan tetapi tidak dipakai. |
| RULE-07 | Peran `users` tidak dapat mengedit profil pengguna lain (hanya admin/superAdmin), padahal tab Pengguna memintanya. |
| RULE-10 | Dokumen `chats/{id}` dapat dibaca (`get`/`list`) oleh semua pengguna login, bukan hanya anggota. |
| BB-50, BB-51 (peran attendance) | Aturan `attendance_windows` dan `admin_signals` hanya `isAdmin()` (admin/superAdmin); Admin Divisi Administrasi berperan `attendance` ditolak, padahal skenario BB-50/BB-51 mengharapkan berhasil. |
| BB-22, BB-24 | Alasan cuti/izin kosong lolos di server (validasi hanya di klien). |
| BB-39, RULE-26 | Pembatasan divisi menu Material hanya di UI; `material_requests` dapat dibuat dan di-list oleh semua pegawai login. |
| RULE-S01 .. RULE-S04 | `storage.rules` = `allow read, write: if true`; anonim dapat membaca/menulis, pegawai dapat menimpa berkas pegawai lain. |
| RULE-F02 | `holidays/{tanggal}` dengan `isHoliday:false` tetapi ada `name` tetap dianggap libur (`isHoliday !== false || name`). |
| RULE-F04 | Divisi "Heavy Equipment" ada di Lengkapi Profil namun tidak dikenali `normalizeDivision`, sehingga tidak dapat menjadi sasaran notifikasi dokumen. |

## 4. Pemetaan nama tes -> ID Black Box -> hasil diharapkan

Catatan: tes bertanda `describe.each`/`test.each` di suite Functions dijalankan berulang untuk 3 fungsi siaran (08.00, 08.30, 09.20)
dan 4 definisi jadwal; tabel mencantumkan satu baris per pola.

| Suite | Nama tes | ID Black Box | Hasil diharapkan (Excel) | Perkiraan pada kode saat ini |
|---|---|---|---|---|
| Rules | BB-10 pemilik melengkapi profil (nama, divisi, foto, PIN) pada dokumennya sendiri | BB-10 | BB-10: Profil tersimpan, PIN unik 6 karakter diperoleh, masuk ke Beranda | Diharapkan lulus |
| Rules | BB-10 pengguna baru membuat dokumen profil miliknya (signup) | BB-10 | BB-10: Profil tersimpan, PIN unik 6 karakter diperoleh, masuk ke Beranda | Diharapkan lulus |
| Rules | BB-30 pemilik mengganti foto profil | BB-30 | BB-30: Foto profil berubah | Diharapkan lulus |
| Rules | BB-25 / BB-27 pengguna login dapat membaca profil pegawai lain (pencarian kontak) | BB-25, BB-27 | BB-25: Acara sesuai divisi dan hari libur nasional tampil; BB-27: Kontak bertambah pada daftar | Diharapkan lulus |
| Rules | RULE-01 pegawai tidak dapat mengubah profil pegawai lain | RULE-01 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | RULE-02 pengguna tanpa login tidak dapat membaca profil | RULE-02 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | RULE-03 pengguna tanpa login tidak dapat mengubah profil | RULE-03 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | RULE-04 [TEMUAN] pemilik TIDAK boleh menaikkan peran dirinya menjadi superAdmin | RULE-04 | Klaim keamanan tambahan (lihat nama test) | Diperkirakan GAGAL (temuan) |
| Rules | RULE-05 [TEMUAN] pemilik TIDAK boleh menambah peran modul (attendance) untuk dirinya sendiri | RULE-05 | Klaim keamanan tambahan (lihat nama test) | Diperkirakan GAGAL (temuan) |
| Rules | RULE-06 [TEMUAN] pengguna baru TIDAK boleh membuat dokumen profil sendiri berisi roles.superAdmin=true | RULE-06 | Klaim keamanan tambahan (lihat nama test) | Diperkirakan GAGAL (temuan) |
| Rules | BB-66 Super Admin mengubah nama dan divisi pengguna lain | BB-66 | BB-66: Perubahan tersimpan | Diharapkan lulus |
| Rules | BB-68 Super Admin memberi peran modul (attendance) kepada pegawai | BB-68 | BB-68: Akun dapat membuka modul Kehadiran di Dasbor Admin | Diharapkan lulus |
| Rules | BB-69 (sisi aturan) admin peran 'users' non-Super Admin tidak dapat mengubah peran orang lain | BB-69 | BB-69: Kontrol pengubahan peran tidak tersedia | Diharapkan lulus |
| Rules | RULE-07 [TEMUAN] admin peran 'users' dapat mengubah nama/PIN pengguna lain (fitur tab Pengguna) | RULE-07 | Klaim keamanan tambahan (lihat nama test) | Diperkirakan GAGAL (temuan) |
| Rules | RULE-08 hanya admin/superAdmin yang dapat menghapus dokumen pengguna | RULE-08 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | BB-27 pemilik mengelola daftar kontaknya; pegawai lain tidak dapat membaca/menulisnya | BB-27 | BB-27: Kontak bertambah pada daftar | Diharapkan lulus |
| Rules | BB-29 pegawai membuat chat grup (dirinya termasuk anggota) | BB-29 | BB-29: Grup dibuat dan anggota dapat berkirim pesan | Diharapkan lulus |
| Rules | BB-28 anggota chat mengirim pesan; anggota lain dapat membacanya | BB-28 | BB-28: Pesan terkirim dan tampil pada kedua perangkat | Diharapkan lulus |
| Rules | RULE-09 non-anggota tidak dapat membaca maupun mengirim pesan pada chat orang lain | RULE-09 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | RULE-09b pengirim tidak dapat memalsukan senderId pegawai lain | RULE-09b | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | RULE-10 [TEMUAN] non-anggota TIDAK boleh membaca dokumen chat (metadata, daftar anggota) milik orang lain | RULE-10 | Klaim keamanan tambahan (lihat nama test) | Diperkirakan GAGAL (temuan) |
| Rules | RULE-11 non-anggota tidak dapat mengubah dokumen chat orang lain | RULE-11 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | RULE-11b pengguna tanpa login tidak dapat membuat chat | RULE-11b | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | BB-14 pegawai menyimpan check-in tepat waktu pada subkoleksi miliknya | BB-14 | BB-14: Check-in tersimpan dengan status checkin dan muncul pesan berhasil | Diharapkan lulus |
| Rules | BB-14 pegawai menulis salinan feed presensinya (attendance_feed) | BB-14 | BB-14: Check-in tersimpan dengan status checkin dan muncul pesan berhasil | Diharapkan lulus |
| Rules | BB-16 check-in terlambat dengan alasan (note) tersimpan | BB-16 | BB-16: Check-in tersimpan dengan status checkin terlambat | Diharapkan lulus |
| Rules | RULE-12 pegawai tidak dapat menulis presensi atas nama pegawai lain | RULE-12 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | RULE-13 dokumen presensi dengan field di luar daftar yang diizinkan ditolak | RULE-13 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | RULE-14 pemilik tidak dapat mengubah atau menghapus rekaman presensinya setelah tersimpan | RULE-14 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | BB-19 pemilik membaca riwayat presensinya sendiri | BB-19 | BB-19: Riwayat kehadiran, cuti, dan izin tampil beserta statusnya | Diharapkan lulus |
| Rules | RULE-15 pegawai tidak dapat membaca presensi pegawai lain | RULE-15 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | BB-53 admin peran attendance membaca detail rekaman presensi pegawai | BB-53 | BB-53: Foto wajah, foto lokasi, dan peta lokasi tampil | Diharapkan lulus |
| Rules | BB-54 admin peran attendance mengoreksi status presensi menjadi Izin (manual) | BB-54 | BB-54: Status berubah dan tercatat sebagai koreksi admin | Diharapkan lulus |
| Rules | RULE-16 pengguna tanpa login tidak dapat membaca/menulis presensi | RULE-16 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | RULE-17 feed presensi hanya dibaca admin/peran attendance, bukan pegawai biasa | RULE-17 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | BB-11 pegawai dapat membaca jadwal absen hari ini | BB-11 | BB-11: Muncul pesan Absen belum dibuka admin | Diharapkan lulus |
| Rules | RULE-18 pengguna tanpa login tidak dapat membaca jadwal absen | RULE-18 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | BB-50 Super Admin membuat/mengatur jadwal absen manual | BB-50 | BB-50: Jadwal tersimpan dan pegawai menerima notifikasi absensi dibuka | Diharapkan lulus |
| Rules | BB-50 [TEMUAN] admin peran 'attendance' (Admin Divisi Administrasi) dapat membuka absensi (jadwal tersimpan) | BB-50 | BB-50: Jadwal tersimpan dan pegawai menerima notifikasi absensi dibuka | Diperkirakan GAGAL (temuan) |
| Rules | BB-50 [TEMUAN] admin peran 'attendance' dapat menulis sinyal admin_signals (pemicu notifikasi) | BB-50 | BB-50: Jadwal tersimpan dan pegawai menerima notifikasi absensi dibuka | Diperkirakan GAGAL (temuan) |
| Rules | BB-50 Super Admin menulis sinyal attendance_open | BB-50 | BB-50: Jadwal tersimpan dan pegawai menerima notifikasi absensi dibuka | Diharapkan lulus |
| Rules | BB-51 Super Admin menutup absensi (hapus jadwal) | BB-51 | BB-51: Jadwal dihapus dan pegawai menerima notifikasi absensi ditutup | Diharapkan lulus |
| Rules | BB-51 [TEMUAN] admin peran 'attendance' dapat menghapus jadwal absen (tutup absensi) | BB-51 | BB-51: Jadwal dihapus dan pegawai menerima notifikasi absensi ditutup | Diperkirakan GAGAL (temuan) |
| Rules | RULE-19 pegawai biasa tidak dapat membuat, mengubah, atau menghapus jadwal absen | RULE-19 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | RULE-20 jadwal dengan field di luar daftar atau tipe salah ditolak (admin) | RULE-20 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | RULE-21 pegawai biasa tidak dapat menulis atau membaca admin_signals; sinyal tidak dapat diubah | RULE-21 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | BB-07 (sisi aturan) akun tanpa roles tidak dapat menulis modul admin mana pun | BB-07 | BB-07: Akses ditolak dengan pesan bukan admin, lalu akun dikeluarkan | Diharapkan lulus |
| Rules | BB-21 pegawai mengajukan cuti lengkap dengan lampiran (status pending) | BB-21 | BB-21: Pengajuan tersimpan berstatus Menunggu | Diharapkan lulus |
| Rules | BB-22 [TEMUAN] pengajuan cuti dengan alasan kosong ditolak server (validasi bukan hanya di klien) | BB-22 | BB-22: Muncul pesan Lengkapi data cuti terlebih dahulu | Diperkirakan GAGAL (temuan) |
| Rules | BB-22 pengajuan cuti tanpa field alasan sama sekali ditolak | BB-22 | BB-22: Muncul pesan Lengkapi data cuti terlebih dahulu | Diharapkan lulus |
| Rules | BB-23 pegawai mengajukan izin lengkap (status pending) | BB-23 | BB-23: Pengajuan tersimpan berstatus Menunggu | Diharapkan lulus |
| Rules | BB-24 [TEMUAN] pengajuan izin dengan alasan kosong ditolak server | BB-24 | BB-24: Muncul pesan Lengkapi data izin terlebih dahulu | Diperkirakan GAGAL (temuan) |
| Rules | RULE-22 pegawai tidak dapat mengajukan atas nama pegawai lain, langsung berstatus approved, atau dengan jenis tak dikenal | RULE-22 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | BB-19 pemilik dan admin peran requests dapat membaca pengajuan; pegawai lain tidak | BB-19 | BB-19: Riwayat kehadiran, cuti, dan izin tampil beserta statusnya | Diharapkan lulus |
| Rules | BB-56 admin peran requests menyetujui pengajuan (nama pemutus tercatat) | BB-56 | BB-56: Status menjadi Disetujui dan nama pemutus tercatat | Diharapkan lulus |
| Rules | BB-57 admin peran requests menolak pengajuan | BB-57 | BB-57: Status menjadi Ditolak | Diharapkan lulus |
| Rules | RULE-23 pemilik tidak dapat menyetujui sendiri atau menghapus pengajuannya; admin peran lain (attendance) tidak dapat memutus | RULE-23 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | BB-36 Pegawai Lapangan membuat permintaan material (status pending) | BB-36 | BB-36: Permintaan tersimpan berstatus Pending; dokumen Order Bahan DOCX dan PDF dibuat | Diharapkan lulus |
| Rules | RULE-24 permintaan material tidak dapat dibuat atas nama pegawai lain atau tanpa login | RULE-24 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | BB-39 [TEMUAN] pegawai divisi kantor (Finance) TIDAK boleh membuat permintaan material (pembatasan di server) | BB-39 | BB-39: Menu tidak dapat dibuka dan muncul pesan pembatasan akses | Diperkirakan GAGAL (temuan) |
| Rules | BB-40 pemohon membaca permintaan miliknya | BB-40 | BB-40: Daftar permintaan tampil dengan status dan item | Diharapkan lulus |
| Rules | RULE-25 pegawai lain tidak dapat membaca (get) permintaan material milik orang lain | RULE-25 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | RULE-26 [TEMUAN] pegawai biasa TIDAK boleh me-list seluruh permintaan material milik orang lain | RULE-26 | Klaim keamanan tambahan (lihat nama test) | Diperkirakan GAGAL (temuan) |
| Rules | BB-42 pemohon menandai barang diterima dari status approved (delivered + penerima + waktu) | BB-42 | BB-42: Status berubah menjadi Diterima dengan nama dan waktu penerima | Diharapkan lulus |
| Rules | BB-43 pemohon tidak dapat menandai diterima saat status masih pending | BB-43 | BB-43: Tombol Barang diterima tidak tersedia | Diharapkan lulus |
| Rules | RULE-27 pegawai lain tidak dapat menandai diterima pada permintaan orang lain | RULE-27 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | RULE-28 pemohon tidak dapat menyetujui permintaannya sendiri atau mengubah item | RULE-28 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | BB-63 admin peran material menyetujui sebagian item (status tetap pending) | BB-63 | BB-63: Item berstatus disetujui, permintaan tetap Pending, PDF memuat nama penyetuju | Diharapkan lulus |
| Rules | BB-64 admin peran material menyetujui seluruh item (status approved, penyetuju tercatat) | BB-64 | BB-64: Status menjadi Disetujui dan dokumen Order Bahan dibuat ulang | Diharapkan lulus |
| Rules | RULE-29 admin peran lain (documents) tidak dapat menyetujui permintaan material | RULE-29 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | RULE-30 hanya peran material yang dapat menghapus permintaan; pemohon tidak | RULE-30 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | BB-44 pegawai mengunggah dokumen miliknya sendiri (dengan kedaluwarsa dan pengingat) | BB-44 | BB-44: Dokumen tampil di daftar dan pengingat lokal terjadwal | Diharapkan lulus |
| Rules | BB-60 admin peran documents mengunggah dokumen untuk pegawai | BB-60 | BB-60: Dokumen tampil pada aplikasi pegawai dan pemilik menerima notifikasi | Diharapkan lulus |
| Rules | RULE-31 pegawai tanpa peran documents tidak dapat membuat dokumen atas nama pegawai lain | RULE-31 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | RULE-32 dokumen dengan field tidak dikenal atau tanpa title ditolak | RULE-32 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | BB-45 pemilik dan admin peran documents dapat membaca dokumen; pegawai lain dan anonim tidak | BB-45 | BB-45: Hanya dokumen yang sesuai tampil | Diharapkan lulus |
| Rules | BB-44 pemilik memperbarui catatan dokumennya | BB-44 | BB-44: Dokumen tampil di daftar dan pengingat lokal terjadwal | Diharapkan lulus |
| Rules | RULE-33 pemilik tidak dapat memindahkan kepemilikan dokumen ke pegawai lain | RULE-33 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | BB-46 pemilik menghapus dokumen miliknya | BB-46 | BB-46: Dokumen dan berkasnya terhapus, pengingat dibatalkan | Diharapkan lulus |
| Rules | BB-62 admin peran documents menghapus dokumen pegawai | BB-62 | BB-62: Tautan tersalin; dokumen dan berkas terhapus | Diharapkan lulus |
| Rules | RULE-34 pegawai lain tidak dapat menghapus atau mengubah dokumen orang lain | RULE-34 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | BB-25 pegawai login dapat membaca acara kalender; anonim tidak | BB-25 | BB-25: Acara sesuai divisi dan hari libur nasional tampil | Diharapkan lulus |
| Rules | BB-58 admin peran calendar membuat acara untuk divisi sasaran | BB-58 | BB-58: Acara tampil pada kalender pegawai divisi sasaran | Diharapkan lulus |
| Rules | BB-26 pegawai menambah acara pribadi (createdBy = dirinya) | BB-26 | BB-26: Acara tampil pada kalender | Diharapkan lulus |
| Rules | RULE-35 pegawai tidak dapat membuat acara atas nama orang lain atau tanpa judul | RULE-35 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | BB-59 admin peran calendar mengubah judul lalu menghapus acara | BB-59 | BB-59: Perubahan tersimpan dan acara terhapus | Diharapkan lulus |
| Rules | RULE-36 pegawai tanpa peran calendar tidak dapat mengubah/menghapus acara | RULE-36 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | RULE-37 konten company profile dapat dibaca publik tanpa login | RULE-37 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | RULE-38 konten company profile hanya dapat diubah admin/superAdmin | RULE-38 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Rules | RULE-39 koleksi yang tidak terdaftar ditolak untuk semua pengguna, termasuk superAdmin | RULE-39 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Storage | BB-44 pegawai login mengunggah berkas dokumen miliknya | BB-44 | BB-44: Dokumen tampil di daftar dan pengingat lokal terjadwal | Diharapkan lulus |
| Storage | BB-30 pegawai login mengunggah/mengganti foto profil | BB-30 | BB-30: Foto profil berubah | Diharapkan lulus |
| Storage | BB-41 pegawai login dapat membuka/mengunduh berkas miliknya (PDF/dokumen) | BB-41 | BB-41: PDF Order Bahan terbuka dan terunduh | Diharapkan lulus |
| Storage | RULE-S01 [TEMUAN] pengguna tanpa login TIDAK boleh membaca berkas dokumen pegawai | RULE-S01 | Klaim keamanan tambahan (lihat nama test) | Diperkirakan GAGAL (temuan) |
| Storage | RULE-S02 [TEMUAN] pengguna tanpa login TIDAK boleh mengunggah berkas | RULE-S02 | Klaim keamanan tambahan (lihat nama test) | Diperkirakan GAGAL (temuan) |
| Storage | RULE-S03 [TEMUAN] pegawai TIDAK boleh menimpa berkas dokumen milik pegawai lain | RULE-S03 | Klaim keamanan tambahan (lihat nama test) | Diperkirakan GAGAL (temuan) |
| Storage | RULE-S04 [TEMUAN] pegawai TIDAK boleh membaca berkas dokumen pegawai lain | RULE-S04 | Klaim keamanan tambahan (lihat nama test) | Diperkirakan GAGAL (temuan) |
| Functions | BB-52 Senin: membuat attendance_windows/{yyyy-MM-dd} 08:30-09:30 WITA, toleransi 30 menit | BB-52 | BB-52: Jadwal 08.30-09.30 WITA dengan toleransi 30 menit terbentuk | Diharapkan lulus |
| Functions | BB-52 Sabtu: tetap membuat jadwal (hanya Minggu yang dilewati) | BB-52 | BB-52: Jadwal 08.30-09.30 WITA dengan toleransi 30 menit terbentuk | Diharapkan lulus |
| Functions | BB-52 Minggu: tidak membuat jadwal | BB-52 | BB-52: Jadwal 08.30-09.30 WITA dengan toleransi 30 menit terbentuk | Diharapkan lulus |
| Functions | BB-52 Tanggal ada di koleksi holidays: jadwal dilewati | BB-52 | BB-52: Jadwal 08.30-09.30 WITA dengan toleransi 30 menit terbentuk | Diharapkan lulus |
| Functions | BB-52 Zona waktu: pukul 06.00 WITA = 22.00 UTC hari sebelumnya tetap memakai tanggal WITA | BB-52 | BB-52: Jadwal 08.30-09.30 WITA dengan toleransi 30 menit terbentuk | Diharapkan lulus |
| Functions | RULE-F01 holidays/{tanggal} berisi isHoliday:false (tanpa name) tidak dianggap libur | RULE-F01 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Functions | RULE-F02 [TEMUAN] isHoliday:false DENGAN name semestinya bukan libur (kode: (isHoliday !== false // name)) | RULE-F02 | Klaim keamanan tambahan (lihat nama test) | Diperkirakan GAGAL (temuan) |
| Functions | BB-35 Minggu: tidak mengirim | BB-35 | BB-35: Pegawai menerima notifikasi bahwa absensi telah dibuka | Diharapkan lulus |
| Functions | BB-35 Hari libur (holidays): tidak mengirim | BB-35 | BB-35: Pegawai menerima notifikasi bahwa absensi telah dibuka | Diharapkan lulus |
| Functions | BB-35 Tanpa token terdaftar: tidak memanggil FCM | BB-35 | BB-35: Pegawai menerima notifikasi bahwa absensi telah dibuka | Diharapkan lulus |
| Functions | BB-35 Token ganda antar pengguna hanya dikirim sekali; >450 token dipecah per batch 450 | BB-35 | BB-35: Pegawai menerima notifikasi bahwa absensi telah dibuka | Diharapkan lulus |
| Functions | BB-35 Sabtu 08.30 WITA tetap mengirim (Senin-Sabtu) | BB-35 | BB-35: Pegawai menerima notifikasi bahwa absensi telah dibuka | Diharapkan lulus |
| Functions | BB-44 pemilik mengunggah sendiri (createdBy == uid): tidak ada notifikasi | BB-44 | BB-44: Dokumen tampil di daftar dan pengingat lokal terjadwal | Diharapkan lulus |
| Functions | BB-60 admin mengunggah untuk pegawai (createdBy != uid): notifikasi ke token pemilik | BB-60 | BB-60: Dokumen tampil pada aplikasi pegawai dan pemilik menerima notifikasi | Diharapkan lulus |
| Functions | BB-60 createdBy 'admin-dashboard' (cadangan UI admin) tetap dianggap dari admin | BB-60 | BB-60: Dokumen tampil pada aplikasi pegawai dan pemilik menerima notifikasi | Diharapkan lulus |
| Functions | BB-60 divisions tertentu: token pemilik + semua pengguna divisi sasaran, tidak termasuk divisi lain | BB-60 | BB-60: Dokumen tampil pada aplikasi pegawai dan pemilik menerima notifikasi | Diharapkan lulus |
| Functions | BB-60 divisions 'all': hanya pemilik dokumen (tidak broadcast ke semua pegawai) | BB-60 | BB-60: Dokumen tampil pada aplikasi pegawai dan pemilik menerima notifikasi | Diharapkan lulus |
| Functions | BB-60 pemilik tanpa token dan tanpa divisi sasaran: tidak ada pengiriman | BB-60 | BB-60: Dokumen tampil pada aplikasi pegawai dan pemilik menerima notifikasi | Diharapkan lulus |
| Functions | BB-60 token pemilik dicari lewat email bila dokumen pengguna tidak memilikinya | BB-60 | BB-60: Dokumen tampil pada aplikasi pegawai dan pemilik menerima notifikasi | Diharapkan lulus |
| Functions | RULE-F03 event tanpa data: fungsi selesai tanpa error dan tanpa kirim | RULE-F03 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Functions | RULE-F04 [TEMUAN] dokumen untuk divisi 'Heavy Equipment' (ada di daftar profil) semestinya sampai ke pengguna divisi itu | RULE-F04 | Klaim keamanan tambahan (lihat nama test) | Diperkirakan GAGAL (temuan) |
| Functions | BB-28 pesan 1-1: terkirim ke token lawan bicara saja, judul = nama pengirim, isi = teks | BB-28 | BB-28: Pesan terkirim dan tampil pada kedua perangkat | Diharapkan lulus |
| Functions | BB-29 pesan grup (>2 anggota): judul = nama grup, token semua anggota selain pengirim | BB-29 | BB-29: Grup dibuat dan anggota dapat berkirim pesan | Diharapkan lulus |
| Functions | BB-28 pesan foto/file tanpa teks memakai isi bawaan | BB-28 | BB-28: Pesan terkirim dan tampil pada kedua perangkat | Diharapkan lulus |
| Functions | BB-28 pesan silent, tanpa senderId, chat tidak ada, atau tanpa token: tidak mengirim | BB-28 | BB-28: Pesan terkirim dan tampil pada kedua perangkat | Diharapkan lulus |
| Functions | BB-33 / BB-50 sinyal attendance_open: notifikasi 'Admin membuka absensi' ke semua token | BB-33, BB-50 | BB-33: Pegawai menerima notifikasi Admin membuka absensi; BB-50: Jadwal tersimpan dan pegawai menerima notifikasi absensi dibuka | Diharapkan lulus |
| Functions | BB-51 sinyal attendance_close: notifikasi 'Admin menutup absensi' | BB-51 | BB-51: Jadwal dihapus dan pegawai menerima notifikasi absensi ditutup | Diharapkan lulus |
| Functions | RULE-F05 tipe sinyal lain diabaikan | RULE-F05 | Klaim keamanan tambahan (lihat nama test) | Diharapkan lulus |
| Functions | BB-52 / BB-35 definisi cron + zona waktu (4 fungsi terjadwal) = 4 kasus | BB-52, BB-35 | BB-52: Jadwal 08.30-09.30 WITA dengan toleransi 30 menit terbentuk; BB-35: Pegawai menerima notifikasi bahwa absensi telah dibuka | Diharapkan lulus |
| Functions | BB-35 matriks 3 notifikasi x 5 kasus (hari kerja, Minggu, libur, tanpa token, batch 450) = 15 kasus | BB-35 | BB-35: Pegawai menerima notifikasi bahwa absensi telah dibuka | Diharapkan lulus |

## 5. Yang tidak dapat diotomatisasi di sini

- Semua kasus UI/validasi klien (BB-01..BB-05, BB-08, BB-09, BB-12, BB-13, BB-15, BB-17, BB-18, BB-20, BB-31, BB-32, BB-37, BB-38, BB-47, BB-49, BB-55, BB-61, BB-65): logika ada di aplikasi Flutter (widget test / integration test terpisah).
  Contoh: aturan jendela waktu (BB-11, BB-15, BB-17), anti-absen ganda (BB-18) dan alasan terlambat hanya dicek klien; aturan Firestore tidak menegakkannya.
- Pembuatan DOCX/PDF Order Bahan (BB-36, BB-41, BB-64) dan ekspor XLSX (BB-55) dilakukan klien.
- Notifikasi keputusan cuti (BB-34), notifikasi permintaan material di dasbor (BB-65) dan pengingat dokumen lokal (BB-47) bukan Cloud Function (listener klien / notifikasi lokal).
- Pengiriman FCM nyata ke perangkat tidak diuji; `sendEachForMulticast` hanya diperiksa isi payload dan jumlah token.
- Suite aturan (Firestore + Storage) hanya divalidasi sintaksnya di lingkungan penyusun (emulator tidak dapat diunduh); hasil sebenarnya baru terlihat saat dijalankan di CI.
- Pemicu Firestore tidak diuji lewat `wrap` firebase-functions-test (lihat bagian 1).
