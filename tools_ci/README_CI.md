# Pengujian Otomatis di GitHub Actions

Berkas alur kerja: `.github/workflows/pengujian-otomatis.yml` (nama: "Pengujian Otomatis").
Proyek Firebase yang dipakai hanya `demo-cvm` (emulator lokal). Tidak ada kredensial Firebase asli dan tidak ada GitHub Secrets.

## Cara menjalankan
1. Dorong (push) kode ke cabang **`pengujian-otomatis`**, atau
2. Buka tab **Actions** -> pilih **Pengujian Otomatis** -> **Run workflow** (pilih cabang tersebut).

Cabang lain tidak memicu alur kerja ini secara otomatis.

## Isi pekerjaan (job)
| Job | Fungsi | Keluaran (artefak) |
|---|---|---|
| `white-box` | Memasang Flutter 3.35.7, membuat `.env` palsu, `flutter pub get`, lalu `flutter test --machine` pada folder `test/` | `hasil-white-box` (`white_box.jsonl`, `.stderr.txt`, `.exitcode`) |
| `server-black-box` | Node 20 + Java 17 + firebase-tools; menjalankan uji aturan Firestore/Storage di emulator (`tests_ci/firestore_rules`) dan uji logika Cloud Functions offline (`tests_ci/functions`) | `hasil-server-black-box` (JUnit XML dari `tests_ci/results/`) |
| `ui-black-box` | Menjalankan `integration_test/ci/prepare_ci.sh` (google-services demo-cvm, cleartext 10.0.2.2, hanya di checkout CI), menambah `integration_test` ke dev_dependencies di checkout CI saja (`tools_ci/tambah_dep_integration_test.sh`), lalu di emulator Android (API 34, x86_64) menjalankan `firebase emulators:exec --config integration_test/firebase.integration.json` yang membungkus `flutter test integration_test --machine` | `hasil-ui-black-box`, `log-emulator-firebase` |
| `rekap` | Mengunduh semua artefak dan menjalankan `tools_ci/parse_results.py` | `rekap` (`rekap.json`, dan `Hasil_Pengujian_terisi.xlsx` bila templat tersedia) |

Kegagalan uji tidak menggagalkan job; hasilnya tetap diunggah. Job `ui-black-box` bertanda `continue-on-error` sehingga emulator yang tidak stabil tidak menyembunyikan hasil lain.

## Di mana hasilnya
Buka run yang selesai -> bagian **Artifacts** di bagian bawah halaman. Unduh `rekap` untuk ringkasan; ringkasan singkat juga tampil di halaman job **Rekap hasil**.

## Mengisi Excel Hasil_Pengujian.xlsx
Secara bawaan alur kerja hanya membuat `rekap.json`. Agar salinan Excel terisi otomatis, simpan templat di `tools_ci/templat/Hasil_Pengujian.xlsx` pada cabang tersebut. Atau jalankan di komputer sendiri setelah mengunduh artefak ke satu folder:

```
pip install openpyxl
python tools_ci/parse_results.py --input folder_artefak --output rekap.json \
    --excel Hasil_Pengujian.xlsx --excel-out Hasil_Pengujian_terisi.xlsx
```

Aturan pemetaan:
- Tes Flutter dari `test/` -> lembar **White Box**, dicocokkan lewat kolom *Berkas Uji* + *Nama Fungsi Uji*. Tes yang tidak ditemukan di Excel dan baris Excel yang tidak mendapat hasil dilaporkan di `rekap.json`.
- Tes yang namanya memuat ID `BB-nn` (JUnit maupun `integration_test`) -> lembar **Black Box**. Beri nama tes dengan awalan ID, misalnya `BB-02 login dengan sandi salah`. ID tambahan seperti `BB-TAMBAHAN-01` dikenali tetapi dilaporkan sebagai tidak ada di Excel. Bila satu ID punya beberapa tes (mis. dua tes BB-39, atau tes UI dan tes aturan server untuk BB-10/BB-44), baris Berhasil hanya jika semua tesnya lulus; satu saja yang gagal membuatnya Gagal (termasuk tes server bertanda [TEMUAN]).
- Kolom Hasil/Status diisi `Berhasil` atau `Gagal`; pesan galat masuk ke Keterangan (White Box) atau Hasil Aktual (Black Box). Rumus tetap utuh dan dihitung ulang saat Excel dibuka.
- Berkas Excel asli tidak pernah ditimpa; sel yang sudah terisi dilewati kecuali memakai `--timpa`.
- Hasil yang diisi hanya yang benar-benar dijalankan. Kasus Black Box yang tidak punya tes otomatis (mis. UI penuh atau notifikasi) tetap kosong dan harus diisi manual.

## Perkiraan waktu
Kira-kira 5-10 menit untuk `white-box`, 5-10 menit untuk `server-black-box` (unduhan emulator pertama lebih lama), 20-40 menit untuk `ui-black-box` (build Gradle pertama dan boot emulator). Total sekitar 30-45 menit; job berjalan paralel. Ini perkiraan, belum diukur.

## Risiko yang diketahui
- Alur kerja belum pernah dijalankan; run pertama kemungkinan perlu perbaikan kecil (versi action, versi Flutter, resolusi dependensi).
- Versi Flutter dipatok 3.35.7 (memenuhi `pubspec.lock`: Dart >= 3.9.0, Flutter >= 3.35.1). Bila `flutter pub get` menolak, naikkan `FLUTTER_VERSION` di berkas alur kerja.
- Versi action memakai tag mayor (`@v4`, `@v2`, `@v5`), bukan SHA; belum diverifikasi dari sini.
- `.env` di repositori tampaknya dilacak git dan berisi nilai Firebase asli. CI menimpanya dengan nilai palsu di workspace CI saja (tidak di-commit). Tes `test/` tidak membaca `.env`; berkas itu hanya harus ada karena terdaftar sebagai aset.
- `android/app/google-services.json` tetap berisi konfigurasi proyek asli; uji integrasi harus mengarahkan Firebase ke emulator (host `10.0.2.2` dari dalam emulator Android) agar tidak menyentuh proyek asli. Pastikan kode uji di `integration_test/` melakukan hal itu.
- Plugin lokal (`local_plugins/`) dan paket native (ML Kit, kamera) dapat memperlambat atau menggagalkan build Android di CI.
- Emulator Android di runner GitHub kadang gagal boot atau lambat; job UI mungkin perlu dijalankan ulang.
- Unduhan emulator Firebase dan paket npm membutuhkan internet dari runner (tersedia di GitHub, tidak di lingkungan penyusun).
- Penyimpanan artefak GitHub terbatas; artefak otomatis kedaluwarsa (bawaan 90 hari).
