# Use Case Spesifik Cipta Vera Mandiri Digital

Dokumentasi ini merinci skenario pemakaian utama untuk tiga pengalaman inti Cipta Vera Mandiri Digital: **Admin Dashboard**, **Aplikasi Karyawan**, dan **Company Profile & Marketing Site**. Setiap use case dilengkapi kebutuhan data, validasi, integrasi sistem, serta variasi alur untuk memudahkan pemetaan kebutuhan bisnis dan teknis. Dokumen ini melengkapi diagram pada `diagram.drawio` dan `usecase.drawio`.

## Konvensi ID
- `UC-A*` : Use case portal Admin Dashboard.
- `UC-E*` : Use case aplikasi Karyawan.
- `UC-C*` : Use case Company Profile & Marketing Site.
- Kode alternatif menggunakan format `<ID>.A<n>` dan eksepsi kegagalan `<ID>.E<n>`.

## Ringkasan Jumlah Use Case
- Company Profile & Marketing Site: 6 use case terperinci.
- Portal Admin: 17 use case terperinci.
- Aplikasi Karyawan: 17 use case terperinci.
- Total: 40 use case terdokumentasi dengan alur alternatif dan catatan bisnis.
- Diagram referensi: `diagram.drawio` (alur fitur) dan `usecase.drawio` (diagram use case).

## Pemetaan Fitur ke Use Case
| Area Fitur | Sorotan | Use Case |
| --- | --- | --- |
| Autentikasi & Akses | Login, reset password, validasi role | UC-A1, UC-A2, UC-A3, UC-E1, UC-E2 |
| Manajemen Peran & Profil | Pengaturan role, kelengkapan profil, perangkat aktif | UC-A3, UC-A10, UC-E3, UC-E11, UC-E17 |
| Absensi & Kehadiran | Ringkasan KPI, log, koreksi, rekapan | UC-A4, UC-A5, UC-A13, UC-A14, UC-E4, UC-E5, UC-E12, UC-E13 |
| Izin & Cuti | Permohonan, approval, kuota | UC-A6, UC-E6 |
| Kalender & Event | Kalender operasional, undangan, berbagi event | UC-A7, UC-E7, UC-E15 |
| Dokumen & Compliance | Pemberkasan, template, eskalasi kedaluwarsa | UC-A8, UC-A15, UC-A16, UC-E9 |
| Permintaan Material & Logistik | Workflow material, rekonsiliasi stok | UC-A9, UC-A17, UC-E8 |
| Komunikasi & Notifikasi | Chat, notifikasi real-time, support | UC-A11, UC-E10, UC-E16 |
| Audit & Keamanan | Audit trail, koreksi akses, perangkat | UC-A12, UC-E17 |
| Company Profile Experience | Landing page, detail entitas, struktur organisasi, portofolio | UC-C1, UC-C2, UC-C3, UC-C4, UC-C5, UC-C6 |

## Company Profile & Marketing Site

### UC-C1 Jelajah Landing Page & Navigasi
**Aktor Utama:** Calon Klien / Mitra Media  
**Stakeholder Pendukung:** Tim Marketing, Business Development  
**Pemicu:** Pengunjung membuka `CompanyHomePage` dari tautan publik atau sesi demo.  
**Prasyarat:** `CompanyProfileApp` memuat tema gelap, daftar `companyProfiles`, aset hero, serta konfigurasi `_sections` dan CTA.  
**Kebutuhan Data:** Tagline utama, daftar section (`_sections`), data statistik hero, daftar layanan, konten visi/misi/nilai, saluran kontak.  
**Validasi:** Penentuan breakpoint lebar layar, ketersediaan `GlobalKey` untuk `Scrollable.ensureVisible`, preload gambar hero, sinkronisasi ValueNotifier offset.  
**Integrasi Sistem:** Flutter `ScrollController`, `ValueNotifier`, animasi `ScrollReveal`, widget kustom `GlassContainer`, CTA ke `url_launcher` (diterusan lewat `UC-C6`), rute tambahan (`UC-C4`, `UC-C5`).

**Alur Utama:**
1. Sistem menampilkan hero dengan badge futuristik, headline, statistik, dan tombol CTA.
2. Pengunjung menggunakan tombol navigasi (`Beranda`, `Tentang`, `Layanan`, `Visi & Misi`, `Kontak`) pada app bar.
3. Sistem mengeksekusi `_scrollTo(key)` yang menggulir viewport ke section terkait dan memicu animasi kemunculan konten.
4. Section `Layanan` menyajikan kartu layanan inti, sedangkan `Visi & Misi` menampilkan pernyataan visi, misi, dan nilai.
5. Section `Kontak` menonjolkan saluran komunikasi dan menyediakan tombol CTA yang melanjutkan alur ke `UC-C6`.

**Alur Alternatif:**
- `C1.A1 – Pengunjung melakukan scroll manual panjang:` Sistem tetap menjalankan animasi reveal bertahap tanpa interaksi tombol.
- `C1.A2 – Perangkat dengan layar < 720 piksel:` Layout masuk mode kompak (padding mengecil, CTA ditumpuk vertikal) tetapi konten yang dirender tetap sama.

**Eksepsi Kegagalan:**
- `C1.E1 – GlobalKey belum memiliki context saat tombol ditekan:` Sistem menunda eksekusi hingga frame berikutnya atau menampilkan snackbar untuk mencoba ulang.
- `C1.E2 – Aset gambar hero gagal dimuat:` Sistem mengganti dengan placeholder warna solid dan log diagnostik dicatat.

**Pasca Kondisi:** Seluruh section landing dapat diakses, konten hero terbaca, dan CTA siap dipakai untuk lanjut ke alur kontak (`UC-C6`).

**Catatan Bisnis:** Konten hero dan statistik harus diperbarui mengikuti materi kampanye terbaru agar pesan merek konsisten di setiap presentasi.

---

### UC-C2 Menelusuri Entitas CVM Group
**Aktor Utama:** Calon Mitra / Investor / Kandidat Talenta  
**Stakeholder Pendukung:** Corporate Strategy, Employer Branding  
**Pemicu:** Pengunjung menekan menu `Perusahaan` pada app bar.  
**Prasyarat:** Daftar `companyProfiles` termuat dan minimal satu profil aktif.  
**Kebutuhan Data:** `CompanyProfileData` (nama, tagline, tipe badan hukum, warna brand).  
**Validasi:** Profil tidak duplikat, pointer ke rute detail tersedia, status loading menu jelas.  
**Integrasi Sistem:** `PopupMenuButton`, navigator `CompanyProfileDetailPage.route`, animasi transisi `FadeTransition + SlideTransition`.

**Alur Utama:**
1. Sistem menampilkan menu dropdown berisi daftar entitas CVM Group lengkap dengan tagline dan jenis badan hukum.
2. Pengunjung memilih salah satu entitas.
3. Sistem menutup menu, menyimpan pilihan, dan mem-push rute `CompanyProfileDetailPage` sambil mengoper `CompanyProfileData` terpilih.
4. Sistem mengalihkan kontrol ke `UC-C3` untuk eksplorasi lebih detail.

**Alur Alternatif:**
- `C2.A1 – Pengunjung menutup menu tanpa memilih:` Sistem menjaga state halaman saat ini tanpa navigasi tambahan.
- `C2.A2 – Pengunjung memilih entitas yang sama berturut-turut:` Sistem tetap membuka halaman detail baru dan menumpuk rute sebelumnya di navigator untuk memudahkan perbandingan.

**Eksepsi Kegagalan:**
- `C2.E1 – Daftar profil kosong atau gagal dimuat:` Sistem menonaktifkan menu dan menampilkan tooltip `Data perusahaan belum tersedia`.
- `C2.E2 – Navigator gagal membuat rute (misal karena konteks tidak valid):` Sistem menampilkan snackbar kesalahan dan menyarankan refresh halaman.

**Pasca Kondisi:** Entitas yang dipilih aktif pada navigator stack dan siap ditinjau melalui `UC-C3`.

**Catatan Bisnis:** Urutan entitas dalam menu sebaiknya mengikuti prioritas kampanye sehingga perusahaan unggulan muncul di posisi teratas.

---

### UC-C3 Menjelajah Detail Profil Perusahaan
**Aktor Utama:** Calon Mitra / Kandidat Talenta / Media  
**Stakeholder Pendukung:** Tim Corporate Communication, HR Marketing  
**Pemicu:** `UC-C2` selesai dan rute `CompanyProfileDetailPage` terbuka.  
**Prasyarat:** Data `CompanyProfileData` tersedia lengkap (summary, history, core values, focus areas).  
**Kebutuhan Data:** Judul profil, tagline, ringkasan, sejarah, daftar nilai inti, bidang fokus, warna brand opsional.  
**Validasi:** Daftar nilai/fokus minimal satu item, teks panjang diformat, warna brand valid untuk tema gelap.  
**Integrasi Sistem:** `ScrollController` + `ValueNotifier` untuk efek parallax, widget `GlassContainer`, komponen `ScrollReveal`.

**Alur Utama:**
1. Sistem merender hero detail dengan aksen warna brand, ikon perusahaan, dan tagline.
2. Pengunjung menggulir untuk membaca ringkasan, nilai inti, fokus layanan, dan sejarah perusahaan.
3. Sistem menjalankan animasi reveal pada setiap blok konten dengan jeda teratur agar presentasi terasa dinamis.
4. Pengunjung menekan tombol `Close` untuk kembali ke halaman sebelumnya.

**Alur Alternatif:**
- `C3.A1 – Pengunjung membandingkan beberapa entitas:` Setelah menekan `Close`, pengunjung dapat memilih entitas lain dari menu `UC-C2` tanpa kehilangan posisi scroll awal.
- `C3.A2 – Konten diakses saat demo layar besar:` Sistem menyesuaikan lebar kolom agar tetap berada pada batas 1100 px untuk keterbacaan.

**Eksepsi Kegagalan:**
- `C3.E1 – Ada properti profil yang kosong:` Sistem menyembunyikan blok tersebut dan mencatat kebutuhan pengisian data kepada tim konten.
- `C3.E2 – ScrollController gagal terpasang (misal disposed prematur):` Sistem menampilkan konten statis tanpa animasi dan mencatat log.

**Pasca Kondisi:** Informasi profil perusahaan tersampaikan, dan pengguna dapat kembali ke landing atau menjelajah entitas lain.

**Catatan Bisnis:** Konten detail harus melalui proses review legal sebelum dipublikasikan untuk memastikan kesesuaian brand voice.

---

### UC-C4 Meninjau Struktur Organisasi & Tribe
**Aktor Utama:** Calon Mitra / Kandidat Talenta  
**Stakeholder Pendukung:** People & Culture, Leadership Team  
**Pemicu:** Pengunjung menekan tombol `Struktur` pada app bar landing atau pranala internal.  
**Prasyarat:** Data metrik organisasi, daftar leadership, divisi strategis, dan unit pendukung tersiap.  
**Kebutuhan Data:** Nilai metrik (jumlah tribe, chapter, CoE), data leadership (nama, peran, misi, ikon), daftar divisi, unit pendukung.  
**Validasi:** Layout responsif terhadap lebar layar, minimal satu item di setiap daftar, teks ringkas agar muat dalam kartu.  
**Integrasi Sistem:** `CompanyOrganizationPage.route`, `ScrollController`, `GlassContainer`, animasi fade/slide bawaan halaman.

**Alur Utama:**
1. Sistem membuka halaman `CompanyOrganizationPage` dengan hero yang menyorot blueprint organisasi.
2. Pengunjung melihat metrik utama (jumlah proyek, tribe, chapter) dalam kartu glass.
3. Pengunjung menggulir untuk meninjau kartu leadership, divisi strategis, dan unit pendukung beserta perannya.
4. Tombol `Close` menutup halaman dan mengembalikan pengguna ke landing.

**Alur Alternatif:**
- `C4.A1 – Pengunjung menggunakan keyboard/page scroll pada desktop:` Sistem menyesuaikan animasi reveal mengikuti offset scroll yang diterima.
- `C4.A2 – Mode mobile:` Layout otomatis beralih ke satu kolom agar konten tetap terbaca.

**Eksepsi Kegagalan:**
- `C4.E1 – Data divisi belum lengkap:` Sistem menampilkan placeholder `Segera diperbarui` dan mencatat kebutuhan input kepada People & Culture.
- `C4.E2 – Navigasi kembali di-blokir (misal route sudah ditutup):` Sistem menampilkan toast peringatan dan menawarkan kembali ke halaman utama melalui `Navigator.popUntil`.

**Pasca Kondisi:** Pengunjung memahami struktur organisasi dan dapat melanjutkan melihat portofolio (`UC-C5`) atau kembali ke landing.

**Catatan Bisnis:** Halaman struktur sering dipakai saat employer branding; kontennya harus diselaraskan dengan deck perekrutan resmi.

---

### UC-C5 Menjelajah Portofolio Proyek
**Aktor Utama:** Calon Klien / Partner Strategis  
**Stakeholder Pendukung:** Tim Delivery, Business Development  
**Pemicu:** Pengunjung menekan tombol `Proyek` pada app bar.  
**Prasyarat:** Data demo proyek tersedia (nama, deskripsi, klien, timeline, status, tag).  
**Kebutuhan Data:** Daftar `_ProjectEntry`, status proyek (in progress/completed), tag teknologi, jalur gambar pendukung.  
**Validasi:** Setiap proyek memiliki tag minimal satu, gambar tersedia, status diterjemahkan ke badge visual.  
**Integrasi Sistem:** `CompanyProjectsPage.route`, `ScrollController`, animasi highlight status.

**Alur Utama:**
1. Sistem membuka halaman portofolio dan menampilkan ringkasan jumlah proyek selesai vs berjalan.
2. Pengunjung menggulir daftar proyek; setiap kartu menampilkan deskripsi, klien, timeline, dan tag teknologi.
3. Pengunjung menyorot kartu untuk melihat highlight status (misal badge hijau untuk proyek selesai).
4. Pengunjung menutup halaman melalui tombol `Close` untuk kembali ke landing.

**Alur Alternatif:**
- `C5.A1 – Pengunjung memusatkan perhatian pada tag tertentu:` Sistem menonjolkan tag sebagai chip sehingga memudahkan pembahasan saat presentasi.
- `C5.A2 – Presentasi di layar kecil:` Layout otomatis beralih ke satu kolom dengan ketinggian kartu menyesuaikan agar informasi tetap terbaca.

**Eksepsi Kegagalan:**
- `C5.E1 – Daftar proyek kosong:` Sistem menampilkan state kosong dengan CTA hubungi tim bisnis.
- `C5.E2 – Gambar proyek gagal dimuat:` Sistem menggunakan logo CVM default sebagai fallback.

**Pasca Kondisi:** Portofolio proyek tersampaikan dan menjadi bahan diskusi untuk alur penawaran berikutnya.

**Catatan Bisnis:** Data proyek nyata harus mengikuti NDA; gunakan versi yang telah disetujui untuk dipublikasikan.

---

### UC-C6 Mengirim Permintaan Kontak
**Aktor Utama:** Calon Klien / Partner / Media  
**Stakeholder Pendukung:** Tim Marketing, Account Executive  
**Pemicu:** Pengunjung menekan tombol CTA `Hubungi Kami` pada landing (`UC-C1`).  
**Prasyarat:** Perangkat memiliki aplikasi email default atau skema mailto yang valid.  
**Kebutuhan Data:** Alamat email tujuan, subjek default, template body opsional.  
**Validasi:** URI mailto valid, `canLaunchUrl` mengembalikan `true`, fallback pemberitahuan jika tidak ada aplikasi email.  
**Integrasi Sistem:** Paket `url_launcher`, aplikasi email perangkat, log analitik interaksi CTA.

**Alur Utama:**
1. Pengunjung menekan tombol CTA `Hubungi Kami`.
2. Sistem membangun URI `mailto:hello@cvmdigital.id` dengan subjek otomatis.
3. Sistem memanggil `launchUrl` sehingga aplikasi email default terbuka dengan kolom terisi.
4. Pengunjung melengkapi pesan dan mengirim email kepada tim marketing.

**Alur Alternatif:**
- `C6.A1 – Pengunjung membatalkan pengiriman email:` Kontrol kembali ke aplikasi tanpa perubahan; sistem tetap mencatat intent CTA untuk analitik.
- `C6.A2 – Pengunjung ingin berbagi kontak melalui kanal lain:` Sistem menampilkan alamat email pada snackbar agar bisa disalin manual.

**Eksepsi Kegagalan:**
- `C6.E1 – Perangkat tidak memiliki aplikasi email yang dapat menangani mailto:` Sistem menampilkan dialog berisi alamat email dan instruksi untuk menyalin secara manual.
- `C6.E2 – \`launchUrl\` melempar exception:` Sistem menampilkan snackbar kesalahan dan mencatat log untuk investigasi.

**Pasca Kondisi:** Intent kontak tercatat dan tim marketing menerima atau menantikan email dari calon klien.

**Catatan Bisnis:** Konversi CTA harus dipantau; integrasi dengan CRM disarankan agar setiap intent tercatat sebagai lead.

---

## Admin Dashboard

### UC-A1 Login Administrator
**Aktor Utama:** Administrator / Super Administrator  
**Stakeholder Pendukung:** Divisi HR, Tim Operasional, Tim Keamanan TI  
**Pemicu:** Admin membuka halaman login dashboard.  
**Prasyarat:** Aplikasi memuat konfigurasi `.env`, `Firebase.initializeApp()`, kanal notifikasi, dan tema.  
**Kebutuhan Data:** Email korporat, kata sandi, metadata perangkat (opsional), flag `rememberMe`.  
**Validasi:** Format email, minimal panjang kata sandi, status verifikasi email, throttle percobaan gagal.  
**Integrasi Sistem:** Firebase Authentication, Secure Storage/SharedPreferences, Crashlytics untuk audit percobaan.

**Alur Utama:**
1. Admin memasukkan email dan kata sandi lalu menekan tombol masuk.
2. Sistem melakukan validasi sisi-klien (format email, panjang kata sandi).
3. Sistem mengirim permintaan `signInWithEmailAndPassword` ke Firebase Auth.
4. Firebase mengembalikan token ID; sistem memeriksa `emailVerified`.
5. Sistem menyimpan token dan refresh token pada secure storage.
6. Sistem mencatat metadata perangkat dan waktu login ke log audit.
7. Sistem mengarahkan proses ke `UC-A3` untuk inspeksi hak akses.

**Alur Alternatif:**
- `A1.A1 – Email belum verifikasi:` Sistem menawarkan opsi kirim ulang verifikasi, menampilkan snackbar panduan, dan menahan akses.
- `A1.A2 – Admin memilih reset kata sandi:` Sistem berpindah ke `UC-A2` tanpa mengirim kredensial ke server.

**Eksepsi Kegagalan:**
- `A1.E1 – Kredensial salah / akun dikunci:` Sistem mengembalikan pesan generik, menambah counter gagal, dan memblokir sementara setelah 5 percobaan dalam 10 menit.
- `A1.E2 – Gangguan jaringan atau Firebase Auth tidak tersedia:` Sistem menampilkan banner offline dan menyarankan percobaan ulang.

**Pasca Kondisi:** Token autentikasi valid tersimpan dan sesi admin aktif.

**Catatan Bisnis:** Wajib mendukung audit keamanan; login yang sukses memicu notifikasi email ke super admin bila berasal dari perangkat/ lokasi baru.

---

### UC-A2 Reset Kata Sandi Administrator
**Aktor Utama:** Administrator  
**Stakeholder Pendukung:** Tim Keamanan TI  
**Pemicu:** Admin menekan tautan *Lupa kata sandi* pada halaman login.  
**Prasyarat:** `UC-A1` gagal karena kata sandi tidak diingat.  
**Kebutuhan Data:** Email korporat yang terdaftar.  
**Validasi:** Format email, pemeriksaan rate limit reset per akun.  
**Integrasi Sistem:** Firebase Auth `sendPasswordResetEmail`, Cloud Functions untuk pencatatan audit.

**Alur Utama:**
1. Sistem menampilkan dialog reset dan meminta email terdaftar.
2. Admin memasukkan email; sistem memvalidasi format.
3. Sistem mengirim permintaan `sendPasswordResetEmail` ke Firebase.
4. Firebase mengirim email berisi tautan pemulihan.
5. Sistem menampilkan snackbar konfirmasi dan log aktivitas reset.

**Alur Alternatif:**
- `A2.A1 – Admin salah memasukkan email:` Sistem menampilkan pesan generik tanpa mengungkapkan keberadaan akun.

**Eksepsi Kegagalan:**
- `A2.E1 – Batasan rate limit tercapai:` Sistem meminta admin menunggu (mis. 15 menit) sebelum mencoba lagi.
- `A2.E2 – Gangguan jaringan:` Sistem menampilkan status gagal dan menyimpan alasan di log lokal.

**Pasca Kondisi:** Email reset dikirim; sesi login belum aktif sampai tautan digunakan.

**Catatan Bisnis:** Permintaan reset perlu direkap mingguan untuk mendeteksi aktivitas mencurigakan.

---

### UC-A3 Validasi Hak Akses & Muat Dashboard
**Aktor Utama:** Administrator / Super Administrator  
**Stakeholder Pendukung:** Semua pemilik modul (absensi, HR, logistik)  
**Pemicu:** `UC-A1` selesai sukses.  
**Prasyarat:** Token autentikasi valid tersedia.  
**Kebutuhan Data:** Dokumen `users/<uid>`, koleksi `rolePermissions`, daftar modul aktif, preferensi dashboard.  
**Validasi:** Peran mengandung `admin` atau `superAdmin`, status `isActive`, serta izin modul.  
**Integrasi Sistem:** Cloud Firestore, Cloud Functions (policy gating), Firebase Messaging topic subscription.

**Alur Utama:**
1. Sistem mengambil profil admin dan metadata peran dari `users/<uid>`.
2. Sistem memuat daftar izin terperinci (mis. mapping modul ke tindakan) dari `rolePermissions`.
3. Sistem menentukan role aktif (default role utama atau pilihan terakhir admin).
4. Sistem mendaftarkan listener real-time untuk modul yang diperbolehkan dan topik notifikasi FCM terkait.
5. Sistem merakit `AdminDashboardShell` beserta NavigationRail, quick search, dan quick actions sesuai hak akses.

**Alur Alternatif:**
- `A3.A1 – Admin memiliki banyak role aktif:` Sistem meminta admin memilih role utama sebelum memuat dashboard.
- `A3.A2 – Preferensi modul kustom:` Sistem menerapkan filter modul favorit dari preferensi pengguna.

**Eksepsi Kegagalan:**
- `A3.E1 – Peran tidak valid / dicabut:` Sistem menampilkan pesan penolakan, melakukan `signOut`, dan menyarankan kontak super admin.
- `A3.E2 – Firestore tidak tersedia:` Sistem menampilkan mode offline terbatas dan menawarkan retry.

**Pasca Kondisi:** Dashboard shell siap dengan modul yang difilter sesuai hak akses aktif.

**Catatan Bisnis:** Setiap perubahan role harus memicu invalidasi cache dan penyegaran modul agar kebijakan terbaru diterapkan instan.

---

### UC-A4 Meninjau Ringkasan Kehadiran
**Aktor Utama:** Administrator  
**Stakeholder Pendukung:** HR, Pimpinan Operasional  
**Pemicu:** Admin memilih tab Overview pada dashboard.  
**Prasyarat:** `UC-A3` selesai; admin memiliki izin modul statistik kehadiran.  
**Kebutuhan Data:** Agregasi koleksi `attendance_summary`, KPI hadir/izin/cuti, daftar permintaan terbaru, cache profil karyawan.  
**Validasi:** Otorisasi akses data lintas departemen; filter tanggal yang diperbolehkan.  
**Integrasi Sistem:** Firestore aggregation query, Cloud Functions untuk KPI bulanan, local cache (Hive/SQflite) untuk profil.

**Alur Utama:**
1. Sistem memuat ringkasan kehadiran harian dan agregasi 12 bulan.
2. Sistem menampilkan kartu KPI (hadir, izin, cuti) dan highlight permintaan pending.
3. Admin memilih visualisasi (diagram batang atau pie); sistem menyegarkan grafik.
4. Admin melihat daftar karyawan dengan status anomali (mis. terlambat berturut-turut).

**Alur Alternatif:**
- `A4.A1 – Admin mengubah rentang waktu:` Sistem memicu ulang query dengan parameter tanggal baru dan memperbarui KPI.
- `A4.A2 – Admin mengekspor ringkasan:` Sistem menghasilkan CSV/PDF dan mengunggah ke Storage untuk dibagikan.

**Eksepsi Kegagalan:**
- `A4.E1 – Agregasi belum tersedia (prosesi batch):` Sistem menampilkan skeleton dengan timestamp pembaruan terakhir.
- `A4.E2 – Hak akses lintas departemen ditolak:` Sistem menyembunyikan data sensitif dan menampilkan notifikasi role.

**Pasca Kondisi:** Admin memperoleh insight kehadiran terkini untuk pengambilan keputusan cepat.

**Catatan Bisnis:** KPI perlu konsisten dengan laporan HR bulanan; log ekspor wajib disimpan untuk audit.

---

### UC-A5 Mengelola Log Absensi & Window
**Aktor Utama:** Administrator  
**Stakeholder Pendukung:** HR, Supervisor Lapangan  
**Pemicu:** Admin membuka menu Absensi & Window.  
**Prasyarat:** `UC-A3` selesai; admin memiliki izin modul absensi.  
**Kebutuhan Data:** Stream `attendance_logs`, konfigurasi `attendance_windows`, data perangkat, geotag.  
**Validasi:** Hak akses berdasarkan tim/lokasi, validitas perubahan jadwal, kepatuhan regulasi jam kerja.  
**Integrasi Sistem:** Firestore real-time stream, Cloud Functions scheduler, Storage (bukti foto), Map SDK untuk lokasi.

**Alur Utama:**
1. Sistem men-stream log absensi harian dengan filter status default (hadir, terlambat, izin) dan pencarian nama.
2. Admin membuka detail log untuk melihat foto wajah, geolokasi, dan metadata perangkat.
3. Admin menyesuaikan jendela absensi (jam buka/tutup, durasi auto-close) melalui form konfigurasi.
4. Sistem memvalidasi perubahan agar tidak bertabrakan dengan window aktif lain.
5. Sistem menyimpan konfigurasi baru ke Firestore dan mengirim notifikasi ke karyawan terkait.

**Alur Alternatif:**
- `A5.A1 – Admin mengekspor log harian:` Sistem men-generate file CSV dan menaruhnya di Storage dengan tautan unduhan.
- `A5.A2 – Admin memaksa tutup window lebih cepat:` Sistem menyimpan alasan penutupan manual dan mengirim broadcast ke karyawan.

**Eksepsi Kegagalan:**
- `A5.E1 – Perubahan window bertabrakan:` Sistem menolak simpan dan menandai slot yang konflik.
- `A5.E2 – Bukti foto hilang atau korup:` Sistem menandai log sebagai `needs_review` dan memberi opsi meminta unggahan ulang ke karyawan.

**Pasca Kondisi:** Konfigurasi window dan log absensi terbaru tersimpan dan terdistribusi ke seluruh admin.

**Catatan Bisnis:** Perubahan window wajib disetujui supervisor lapangan tertentu; catat nama admin pengubah untuk audit.

---

### UC-A6 Memproses Permohonan Cuti/Izin
**Aktor Utama:** Administrator  
**Stakeholder Pendukung:** HR, Supervisor Tim  
**Pemicu:** Admin membuka tab Cuti & Izin.  
**Prasyarat:** `UC-A3` selesai; admin memiliki izin modul cuti/izin.  
**Kebutuhan Data:** Koleksi `leave_requests`, profil pemohon, histori keputusan, kuota cuti.  
**Validasi:** Status permintaan (pending), kecukupan kuota, bentrok tanggal, kewenangan admin terhadap tim.  
**Integrasi Sistem:** Firestore, Cloud Functions untuk penghitungan kuota dan notifikasi, integrasi kalender.

**Alur Utama:**
1. Sistem menampilkan kalender fokus dengan highlight tanggal permohonan.
2. Admin menelusuri tab daftar pending atau riwayat dengan filter status/tanggal.
3. Admin membuka permohonan, meninjau detail profil, lampiran, dan histori keputusan.
4. Admin memilih tindakan approve/reject dan menambahkan catatan keputusan.
5. Sistem memperbarui status, mencatat admin pemutus, menyesuaikan kuota, dan mengirim notifikasi ke karyawan.

**Alur Alternatif:**
- `A6.A1 – Delegasi keputusan:` Admin meneruskan permohonan ke admin lain dengan catatan, status berubah menjadi `forwarded`.
- `A6.A2 – Permintaan revisi dokumen:` Admin mengembalikan permohonan ke status `needs_revision` agar karyawan melengkapi lampiran.

**Eksepsi Kegagalan:**
- `A6.E1 – Permohonan sudah diproses admin lain:` Sistem menampilkan status terbaru dan menolak perubahan ganda.
- `A6.E2 – Kuota tidak cukup:` Sistem menghalangi persetujuan dan memberikan opsi override bagi super admin.

**Pasca Kondisi:** Status permohonan tercatat dengan keputusan dan notifikasi terkirim.

**Catatan Bisnis:** Keputusan harus tersinkron dengan payroll; catatan alasan wajib diisi untuk menjaga jejak audit.

---

### UC-A7 Mengelola Kalender Operasional
**Aktor Utama:** Administrator  
**Stakeholder Pendukung:** Semua Divisi Operasional  
**Pemicu:** Admin membuka menu Kalender Operasional.  
**Prasyarat:** `UC-A3` selesai; admin memiliki izin modul kalender.  
**Kebutuhan Data:** Koleksi `company_events`, kategori event, lokasi, jadwal kerja, sinkronisasi ke aplikasi karyawan.  
**Validasi:** Tumpang tindih waktu/lokasi, format tanggal, kewenangan membuat event publik.  
**Integrasi Sistem:** Firestore, Cloud Functions untuk sinkronisasi, Calendar API (opsional) dan scheduler.

**Alur Utama:**
1. Sistem menampilkan kalender lintas bulan dengan highlight event harian.
2. Admin menambah event melalui dialog (kategori, lokasi, waktu mulai/selesai, deskripsi, visibilitas).
3. Sistem menyimpan event baru, membuat entri histori, dan memicu notifikasi ke pengguna terkait.
4. Admin dapat mengedit atau menghapus event; sistem memperbarui data secara real-time.

**Alur Alternatif:**
- `A7.A1 – Impor event dari file ICS:` Sistem mem-parse file dan menawarkan pratinjau sebelum menyimpan batch.
- `A7.A2 – Duplikasi event berulang:` Sistem menghasilkan event seri dengan pola mingguan/bulanan.

**Eksepsi Kegagalan:**
- `A7.E1 – Event bertabrakan dengan agenda penting lain:` Sistem menampilkan peringatan dan meminta konfirmasi override.
- `A7.E2 – Sinkronisasi ke aplikasi karyawan gagal:` Sistem menandai event `sync_pending` dan mengulangi pengiriman.

**Pasca Kondisi:** Kalender operasional terbarui dan tersinkron ke aplikasi lain.

**Catatan Bisnis:** Event penting harus dicap `mandatory` agar muncul sebagai notifikasi prioritas tinggi di aplikasi karyawan.

---

### UC-A8 Mengelola Dokumen Pemberkasan
**Aktor Utama:** Administrator  
**Stakeholder Pendukung:** HR, Legal  
**Pemicu:** Admin membuka menu Pemberkasan.  
**Prasyarat:** `UC-A3` selesai; admin memiliki izin modul dokumen.  
**Kebutuhan Data:** File dokumen (PDF, DOCX, JPG), metadata kedaluwarsa, pengingat, daftar distribusi.  
**Validasi:** Ukuran file maksimal, ekstensi yang diizinkan, tanggal berlaku, kepemilikan data.  
**Integrasi Sistem:** Firebase Storage, Firestore, Cloud Functions untuk pengingat otomatis, Cloud Scheduler.

**Alur Utama:**
1. Admin mengunggah file melalui FilePicker; sistem menampilkan progres unggahan.
2. Admin mengisi metadata (judul, kategori, tanggal kedaluwarsa, pengingat otomatis).
3. Sistem menyimpan metadata di Firestore dan menjadwalkan pengingat sesuai interval.
4. Admin mencari atau memfilter dokumen, serta dapat membuka, mengunduh, membagikan tautan, atau menghapus.

**Alur Alternatif:**
- `A8.A1 – Unggah massal:` Admin memilih beberapa file; sistem membolehkan penyalinan metadata secara batch.
- `A8.A2 – Transfer kepemilikan dokumen:` Admin memindahkan penanggung jawab dan sistem memperbarui daftar notifikasi.

**Eksepsi Kegagalan:**
- `A8.E1 – Batasan kuota Storage tercapai:` Sistem menolak unggahan dan meminta penghapusan file lama.
- `A8.E2 – File terindikasi berbahaya:` Sistem memblok unggahan dan mengirim peringatan ke tim keamanan.

**Pasca Kondisi:** Dokumen beserta pengingat aktif tersimpan dan dapat diakses sesuai izin.

**Catatan Bisnis:** Pengingat kedaluwarsa minimal dua tingkat (30 dan 7 hari sebelum jatuh tempo) untuk memastikan kepatuhan regulasi.

---

### UC-A9 Mengelola Permintaan Material
**Aktor Utama:** Administrator / Petugas Logistik  
**Stakeholder Pendukung:** Project Manager, Finance  
**Pemicu:** Admin membuka menu Permintaan Material.  
**Prasyarat:** `UC-A3` selesai; admin/logistik memiliki izin modul material.  
**Kebutuhan Data:** Koleksi `material_requests`, detail item, lampiran PDF, status logistik, histori persetujuan.  
**Validasi:** Hak akses terhadap proyek, stok tersedia, status request, penanda delivered.  
**Integrasi Sistem:** Firestore, Storage (dokumen auto-generated), Cloud Functions untuk workflow persetujuan dan notifikasi.

**Alur Utama:**
1. Sistem menampilkan ringkasan jumlah permintaan per status (pending/approved/delivered).
2. Admin membuka detail permintaan untuk melihat item, timeline, dan lampiran PDF.
3. Admin memilih aksi: approve, reject, atau tandai delivered dengan catatan.
4. Sistem memperbarui status di Firestore, menyimpan catatan, dan mengirim notifikasi ke pemohon/proyek.

**Alur Alternatif:**
- `A9.A1 – Reassign PIC logistik:` Admin memindahkan penanggung jawab; sistem memperbarui timeline dan notifikasi.
- `A9.A2 – Meminta revisi permintaan:` Admin men-set status `needs_revision` dan mengirim catatan koreksi ke karyawan.

**Eksepsi Kegagalan:**
- `A9.E1 – Status telah diubah oleh admin lain:` Sistem menampilkan status terbaru dan membatalkan aksi.
- `A9.E2 – Pembuatan PDF gagal:` Sistem memicu ulang generator dan menandai permintaan sebagai `doc_pending`.

**Pasca Kondisi:** Status permintaan material konsisten dengan tindakan terakhir dan tercatat dalam log.

**Catatan Bisnis:** Persetujuan material bernilai besar harus mengirim ringkasan ke Finance untuk cross-check anggaran.

---

### UC-A10 Manajemen Data Pengguna
**Aktor Utama:** Super Administrator / HR Administrator  
**Stakeholder Pendukung:** HR, IT Support  
**Pemicu:** Admin membuka menu Manajemen Pengguna.  
**Prasyarat:** `UC-A3` selesai; admin memiliki izin manajemen pengguna.  
**Kebutuhan Data:** Profil karyawan, status kelengkapan, role, departemen, PIN, kontak darurat, log audit.  
**Validasi:** Hak mengubah role tertentu, format data (nomor telepon, email), keunikan PIN, batas perubahan harian.  
**Integrasi Sistem:** Firestore, Cloud Functions untuk audit trail, Firebase Messaging (sinkronisasi akses), Cloud Tasks untuk propagasi perubahan.

**Alur Utama:**
1. Sistem menampilkan daftar karyawan dengan indikator kelengkapan profil dan pencarian cepat.
2. Admin memilih karyawan untuk meninjau detail profil dan histori perubahan.
3. Admin memperbarui identitas, tim, departemen, role, PIN, atau kontak darurat sesuai kebutuhan.
4. Sistem memvalidasi perubahan, menyimpan ke Firestore, memperbarui log audit, dan menyinkronkan hak akses real-time.

**Alur Alternatif:**
- `A10.A1 – Impor massal dari CSV:` Admin mengunggah file bulk update; sistem menjalankan validasi batch sebelum commit.
- `A10.A2 – Set role sementara:` Admin menetapkan role sementara dengan tanggal kedaluwarsa; sistem menjadwalkan rollback otomatis.

**Eksepsi Kegagalan:**
- `A10.E1 – Admin tidak memiliki hak menaikkan role:` Sistem menolak aksi dan memberikan pesan `insufficient_privilege`.
- `A10.E2 – Konflik data (misal PIN duplikat):` Sistem meminta PIN baru dan menyoroti input bermasalah.

**Pasca Kondisi:** Data profil dan hak akses karyawan terbarui secara konsisten dan tercatat di audit trail.

**Catatan Bisnis:** Setiap perubahan role harus dikonfirmasi melalui notifikasi email ke karyawan dan atasan langsungnya.

---

### UC-A11 Menangani Notifikasi Realtime
**Aktor Utama:** Administrator  
**Stakeholder Pendukung:** Semua pemilik modul  
**Pemicu:** Listener menerima notifikasi real-time (absensi, izin, dokumen, material).  
**Prasyarat:** `UC-A3` selesai; subscription FCM aktiv.  
**Kebutuhan Data:** Payload notifikasi, status baca, tautan modul, preferensi mute.  
**Validasi:** Hak akses modul, deduplikasi event, konsistensi status antar perangkat.  
**Integrasi Sistem:** Firebase Cloud Messaging, Firestore (`notifications`), Cloud Functions untuk dedup, Local Notification service.

**Alur Utama:**
1. Sistem menerima payload notifikasi dan menampilkan badge/overlay pada dashboard.
2. Admin membuka panel notifikasi untuk melihat daftar prioritas berdasarkan modul dan SLA.
3. Admin menandai notifikasi sebagai dibaca atau langsung menavigasi ke modul terkait.
4. Sistem menyinkronkan status baca ke Firestore dan perangkat admin lain.

**Alur Alternatif:**
- `A11.A1 – Admin mematikan notifikasi modul tertentu:` Sistem menyimpan preferensi mute dan berhenti berlangganan topik FCM terkait.
- `A11.A2 – Tandai semua dibaca:` Sistem memperbarui status seluruh notifikasi aktif dan mencatat waktu aksi.

**Eksepsi Kegagalan:**
- `A11.E1 – Listener terputus (jaringan):` Sistem menampilkan indikator offline dan melakukan re-subscribe otomatis setelah koneksi pulih.
- `A11.E2 – Payload duplikat:` Sistem mendeteksi ID yang sama dan mengabaikan notifikasi kedua sambil mencatat di log diagnostik.

**Pasca Kondisi:** Status notifikasi terbaru tersinkron dan modul terkait berhasil diakses sesuai kebutuhan.

**Catatan Bisnis:** Notifikasi dengan prioritas tinggi harus di-escalate ke email/SMS jika tidak dibuka dalam SLA yang ditentukan.

---

## Aplikasi Karyawan

### UC-E1 Autentikasi Karyawan
**Aktor Utama:** Karyawan  
**Stakeholder Pendukung:** HR, Tim Keamanan TI  
**Pemicu:** Pengguna membuka aplikasi karyawan.  
**Prasyarat:** Aplikasi memuat konfigurasi lingkungan, `Firebase.initializeApp()`, layanan notifikasi, face recognition, chat, dan prefetch kamera/lokasi.  
**Kebutuhan Data:** Email, kata sandi, metadata perangkat, flag preferensi (ingat saya, auto login).  
**Validasi:** Format email, panjang kata sandi, status verifikasi email, kepatuhan perangkat (OS minimum, versi aplikasi).  
**Integrasi Sistem:** Firebase Auth, Secure Storage/SharedPreferences, Firebase Messaging, Crashlytics.

**Alur Utama:**
1. Sistem mengecek apakah token sesi masih valid; jika tidak, menampilkan AuthView.
2. Pengguna memilih login atau registrasi dan memasukkan email serta kata sandi.
3. Sistem memvalidasi input dan mengirim permintaan autentikasi ke Firebase.
4. Jika registrasi, sistem membuat akun, mengirim email verifikasi, dan menampilkan snackbar konfirmasi.
5. Setelah email terverifikasi, sistem melakukan auto-login dan menyimpan token secara aman.
6. Sistem menentukan apakah profil sudah lengkap (`UC-E3`) atau langsung ke `UC-E4`.

**Alur Alternatif:**
- `E1.A1 – Registrasi dengan kode tim:` Pengguna memasukkan kode undangan tim; sistem memvalidasi sebelum membuat akun.
- `E1.A2 – Pengguna memilih login biometrik:` Sistem memverifikasi biometrik lokal lalu menggunakan token refresh yang disimpan.

**Eksepsi Kegagalan:**
- `E1.E1 – Autentikasi gagal (kredensial salah):` Sistem menampilkan snackbar error dan menawarkan reset (`UC-E2`).
- `E1.E2 – Firebase Auth offline:` Sistem masuk ke mode offline terbatas dan menyarankan percobaan ulang.

**Pasca Kondisi:** Sesi karyawan aktif dengan token valid.

**Catatan Bisnis:** Aplikasi membatasi maks. dua perangkat aktif per akun; percobaan berlebih memicu notifikasi ke HR.

---

### UC-E2 Reset Kata Sandi Karyawan
**Aktor Utama:** Karyawan  
**Stakeholder Pendukung:** HR, Keamanan TI  
**Pemicu:** Pengguna memilih opsi reset password di AuthView.  
**Prasyarat:** Pengguna mengetahui email terdaftar.  
**Kebutuhan Data:** Email.  
**Validasi:** Format email, batas permintaan reset per jam.  
**Integrasi Sistem:** Firebase Auth `sendPasswordResetEmail`, Logging lokal.

**Alur Utama:**
1. Pengguna memasukkan email terdaftar.
2. Sistem memvalidasi format dan memanggil API reset Firebase.
3. Firebase mengirim email pemulihan.
4. Sistem menampilkan snackbar konfirmasi dan menutup dialog reset.

**Alur Alternatif:**
- `E2.A1 – Pengguna tidak yakin email benar:` Sistem memberi link bantuan hubungi HR tanpa menampilkan status akun.

**Eksepsi Kegagalan:**
- `E2.E1 – Permintaan reset melebihi kuota:` Sistem menampilkan pesan jeda waktu.
- `E2.E2 – Koneksi buruk:` Sistem menyimpan permintaan lokal dan menawarkan retry.

**Pasca Kondisi:** Email reset terkirim; login belum aktif sampai tautan diklik.

**Catatan Bisnis:** Aktivitas reset dicatat untuk audit keamanan dan peninjauan HR.

---

### UC-E3 Melengkapi Profil Karyawan
**Aktor Utama:** Karyawan  
**Stakeholder Pendukung:** HR, Tim Operasional  
**Pemicu:** Sistem mendeteksi profil belum lengkap setelah `UC-E1`.  
**Prasyarat:** Sesi karyawan aktif.  
**Kebutuhan Data:** Foto profil, nama lengkap, tim, role, nomor kontak, PIN unik, lokasi kantor.  
**Validasi:** Rasio foto, ukuran file, format nama (tanpa karakter terlarang), keunikan PIN, kewajiban kolom wajib.  
**Integrasi Sistem:** ImagePicker + Cropper, Firebase Storage, Firestore, Cloud Functions (validasi PIN unik), Retry backoff.

**Alur Utama:**
1. Pengguna memilih atau memotret foto profil; sistem menawarkan crop sesuai rasio.
2. Pengguna mengisi form data pribadi termasuk tim, role, dan kontak darurat.
3. Pengguna membuat PIN unik via ChatPinService; sistem memverifikasi keunikan.
4. Sistem mengunggah foto ke Storage, menyimpan metadata ke Firestore, dan menandai `profileComplete=true`.
5. Sistem mengarahkan pengguna ke `UC-E4`.

**Alur Alternatif:**
- `E3.A1 – Pengguna menggunakan avatar default sementara:` Sistem menandai tugas follow-up untuk update foto.
- `E3.A2 – PIN dibuat manual oleh admin:` Sistem menunggu verifikasi admin sebelum menandai profil lengkap.

**Eksepsi Kegagalan:**
- `E3.E1 – Gagal unggah foto:` Sistem menawarkan retry dan menyimpan data tanpa foto sementara.
- `E3.E2 – PIN duplikat:` Sistem meminta PIN baru dan menampilkan daftar PIN yang tidak boleh digunakan.

**Pasca Kondisi:** Profil karyawan lengkap terpenuhi dan disinkronkan ke modul lain.

**Catatan Bisnis:** Profil lengkap merupakan syarat mengakses modul absensi dan material.

---

### UC-E4 Mengakses Dashboard Utama
**Aktor Utama:** Karyawan  
**Stakeholder Pendukung:** HR, Tim Komunikasi Internal  
**Pemicu:** Pengguna berada di tab Home setelah profil lengkap.  
**Prasyarat:** `UC-E3` selesai atau profil sudah lengkap dari awal.  
**Kebutuhan Data:** Ringkasan profil, progress kelengkapan, daftar modul, berita internal, event mendatang.  
**Validasi:** Hak akses modul, filter berita sesuai departemen, status notifikasi.  
**Integrasi Sistem:** Firestore (`user_profiles`, `news`, `events`), Cached Storage, Remote Config.

**Alur Utama:**
1. Sistem memuat kartu profil, progres kelengkapan, dan status keaktifan PIN.
2. Sistem menampilkan MenuGrid akses cepat ke modul absensi, material, pemberkasan.
3. Sistem menampilkan NewsSection dan Upcoming Events sinkron dengan kalender admin.
4. Pengguna dapat berpindah tab melalui Floating Navigation atau kartu modul.

**Alur Alternatif:**
- `E4.A1 – Pengguna menarik untuk refresh:` Sistem memuat ulang berita dan event dari server.
- `E4.A2 – Mode offline:` Sistem menampilkan data cache terakhir dan memberi indikator offline.

**Eksepsi Kegagalan:**
- `E4.E1 – Data profil gagal dimuat:` Sistem meminta retry dan mengarahkan ke `UC-E11` untuk koreksi profil.
- `E4.E2 – Modul tertentu dinonaktifkan oleh admin:` Sistem menyembunyikan shortcut dan menampilkan banner informasi.

**Pasca Kondisi:** Pengguna melihat ringkasan personal dan siap menavigasi ke modul lanjutan.

**Catatan Bisnis:** NewsSection harus dapat ditargetkan berdasarkan lokasi proyek untuk relevansi konten.

---

### UC-E5 Melakukan Absensi Masuk/Keluar
**Aktor Utama:** Karyawan  
**Stakeholder Pendukung:** HR, Supervisor Lapangan  
**Pemicu:** Pengguna memilih modul Absensi dari tab Home atau nav bawah.  
**Prasyarat:** `UC-E4` selesai; izin kamera dan lokasi diberikan; window absensi sedang terbuka.  
**Kebutuhan Data:** Foto selfie, data liveness, lokasi GPS, catatan manual (opsional), metadata perangkat.  
**Validasi:** Koordinat berada dalam geo-fence, window absensi aktif, face recognition lolos, waktu sesuai kebijakan.  
**Integrasi Sistem:** Kamera/Liveness SDK, Firebase Storage, Firestore (`attendance_logs`), Cloud Functions (validasi server), Maps API.

**Alur Utama:**
1. Sistem menampilkan status window (buka/tutup) dan tombol Check-in/Check-out.
2. Pengguna menekan tombol; sistem memicu proses face recognition dan liveness challenge.
3. Sistem memperoleh lokasi GPS terkini dan membandingkan dengan geo-fence.
4. Sistem mengambil foto, menggabungkan metadata perangkat, dan menampilkan pratinjau konfirmasi.
5. Pengguna mengonfirmasi; sistem menyimpan log ke Firestore dan mengunggah media pendukung ke Storage.
6. Sistem menampilkan ringkasan status (waktu hadir/pulang, status pending review jika perlu).

**Alur Alternatif:**
- `E5.A1 – Face recognition gagal namun lokasi valid:` Sistem menawarkan formulir manual dengan lampiran tambahan untuk persetujuan admin.
- `E5.A2 – Pengguna check-out di luar jam kerja:` Sistem meminta alasan dan menandai log sebagai `needs_validation`.

**Eksepsi Kegagalan:**
- `E5.E1 – Di luar geo-fence:` Sistem menolak, menampilkan peta, dan menyarankan pindah ke lokasi yang benar.
- `E5.E2 – Liveness gagal tiga kali:` Sistem mengunci fitur liveness sementara dan menyarankan hubungi supervisor.
- `E5.E3 – Backend absensi tidak responsif:` Sistem menyimpan log di antrean lokal untuk disinkronkan nanti.

**Pasca Kondisi:** Log absensi tercatat dengan bukti lengkap dan status awal (disetujui/pending) sesuai kebijakan.

**Catatan Bisnis:** Setiap log manual harus disetujui admin dalam 1 hari kerja agar payroll tidak tertunda.

---

### UC-E6 Mengajukan Izin dan Cuti
**Aktor Utama:** Karyawan  
**Stakeholder Pendukung:** HR, Supervisor Tim  
**Pemicu:** Pengguna membuka tab Perizinan dari modul Absensi atau navigasi.  
**Prasyarat:** `UC-E4` selesai; kuota izin/cuti masih tersedia.  
**Kebutuhan Data:** Jenis izin/cuti, tanggal mulai/akhir, alasan, lampiran bukti, informasi kontak pengganti.  
**Validasi:** Bentrok tanggal, jenis izin sesuai kebijakan, kuota cukup, lampiran wajib.  
**Integrasi Sistem:** Firestore (`leave_requests`), Storage (lampiran), Cloud Functions (perhitungan kuota, route persetujuan), Calendar sync.

**Alur Utama:**
1. Pengguna memilih jenis izin/cuti dan rentang tanggal.
2. Pengguna mengisi alasan, kontak pengganti, dan menambahkan lampiran jika diperlukan.
3. Sistem menampilkan ringkasan dan estimasi kuota tersisa.
4. Pengguna mengirim permohonan; sistem menyimpan status `pending` dan memicu notifikasi ke admin (`UC-A6`).
5. Sistem menambahkan entri ke riwayat 30 hari agar pengguna dapat memantau.

**Alur Alternatif:**
- `E6.A1 – Permintaan multi-hari dengan cuti sebagian:` Sistem memungkinkan setengah hari pada hari pertama/terakhir.
- `E6.A2 – Simpan sebagai draft:` Pengguna menyimpan permohonan tanpa mengirim; sistem menandai `draft` dan mengingatkan sebelum window kadaluarsa.

**Eksepsi Kegagalan:**
- `E6.E1 – Kuota tidak cukup:` Sistem menolak dan menampilkan pilihan menggunakan cuti lain atau hubungi HR.
- `E6.E2 – Lampiran gagal diunggah:` Sistem menahan pengiriman sampai unggahan sukses.
- `E6.E3 – Permintaan bertumpuk dengan izin lain:` Sistem meminta pengalihan tanggal atau menandai sebagai permintaan overlap.

**Pasca Kondisi:** Permohonan tercatat dan menunggu keputusan admin (`UC-A6`).

**Catatan Bisnis:** Permohonan yang tidak mendapat keputusan dalam 2 hari kerja harus di-escalate otomatis ke atasan.

---

### UC-E7 Mengelola Kalender Tim
**Aktor Utama:** Karyawan  
**Stakeholder Pendukung:** Supervisor Tim, Komunikasi Internal  
**Pemicu:** Pengguna memilih tab Kalender.  
**Prasyarat:** `UC-E4` selesai.  
**Kebutuhan Data:** Event tim, hari libur nasional (API eksternal), event admin, pengingat pribadi.  
**Validasi:** Hak membuat event tim, bentrok waktu, format tanggal dan lokasi.  
**Integrasi Sistem:** TableCalendar widget, Firestore (`team_events`), API Hari Libur Nasional, Cloud Functions (sinkronisasi ke dashboard admin), Reminder lokal.

**Alur Utama:**
1. Sistem memuat event tim dan libur nasional, kemudian merender kalender.
2. Pengguna menambahkan event baru (judul, kategori, jam, lokasi, deskripsi).
3. Sistem menyimpan event dan menandai pemilik serta daftar peserta.
4. Event otomatis muncul di dashboard admin (`UC-A7`) dan modul Home (`UC-E4`).

**Alur Alternatif:**
- `E7.A1 – Filter event berdasarkan kategori:` Pengguna menyalakan filter, sistem menampilkan subset event.
- `E7.A2 – Bagikan event ke chat tim:` Sistem membuat tautan deep-link dan membuka `UC-E10` untuk distribusi.

**Eksepsi Kegagalan:**
- `E7.E1 – API libur nasional gagal:` Sistem menampilkan pemberitahuan dan menggunakan cache terakhir.
- `E7.E2 – Pengguna mengedit event yang bukan miliknya:` Sistem menolak dan menawarkan opsi kirim permintaan perubahan ke pemilik.

**Pasca Kondisi:** Kalender tim terbarui dan sinkron lintas platform.

**Catatan Bisnis:** Event penting dapat diberi label `mandatory` sehingga muncul sebagai pengingat push.

---

### UC-E8 Mengajukan Permintaan Material
**Aktor Utama:** Karyawan  
**Stakeholder Pendukung:** Logistik, Project Manager, Finance  
**Pemicu:** Pengguna membuka tab Material.  
**Prasyarat:** `UC-E4` selesai; karyawan memiliki akses modul material.  
**Kebutuhan Data:** Detail proyek, daftar item, jumlah, satuan, kebutuhan tanggal, lampiran pendukung, catatan tambahan.  
**Validasi:** Kuantitas positif, item diperbolehkan, lampiran wajib untuk material tertentu, batas permintaan per proyek.  
**Integrasi Sistem:** Firestore (`material_requests`), Storage (PDF/DOCX auto-gen), Cloud Functions (generate dokumen & workflow), Notification service.

**Alur Utama:**
1. Pengguna memilih proyek dan mengisi form multi-item (nama bahan, jumlah, satuan, catatan).
2. Sistem menghasilkan pratinjau dokumen (DOCX/PDF) otomatis berdasarkan template.
3. Pengguna meninjau, lalu mengirim permintaan.
4. Sistem menyimpan permintaan status `pending`, mengunggah dokumen, dan mengirim notifikasi ke admin (`UC-A9`).
5. Pengguna dapat memantau status dan melihat timeline persetujuan.

**Alur Alternatif:**
- `E8.A1 – Duplikasi permintaan sebelumnya:` Pengguna memilih template existing; sistem memuat item lama untuk disesuaikan.
- `E8.A2 – Menandai permintaan delivered:` Setelah menerima material, pengguna mengunggah bukti terima dan status berubah menjadi `delivered` menunggu verifikasi admin.

**Eksepsi Kegagalan:**
- `E8.E1 – Generasi dokumen gagal:` Sistem memberi opsi retry dan menandai permintaan `doc_pending` hingga sukses.
- `E8.E2 – Validasi kuantitas gagal (0 atau negatif):` Sistem menolak input dan menyoroti baris item.

**Pasca Kondisi:** Permintaan material tercatat dan menunggu tindak lanjut admin (`UC-A9`).

**Catatan Bisnis:** Permintaan dengan nilai di atas batas tertentu otomatis mengirim ringkasan ke Finance untuk approval tambahan.

---

### UC-E9 Mengelola Dokumen Pemberkasan Karyawan
**Aktor Utama:** Karyawan  
**Stakeholder Pendukung:** HR, Legal  
**Pemicu:** Pengguna membuka tab Pemberkasan.  
**Prasyarat:** `UC-E4` selesai; akses modul pemberkasan diberikan.  
**Kebutuhan Data:** File personal (KTP, sertifikat), metadata kedaluwarsa, pengingat pribadi, status persetujuan admin.  
**Validasi:** Ukuran file, tipe file, kewajiban pengingat, kepemilikan dokumen.  
**Integrasi Sistem:** Firebase Storage, Firestore (`employee_documents`), Cloud Functions (pengingat email/push), Local notification scheduler.

**Alur Utama:**
1. Sistem menampilkan daftar dokumen dengan pencarian dan filter kedaluwarsa.
2. Pengguna mengunggah dokumen baru dan menetapkan pengingat (mis. 30/7 hari sebelum habis).
3. Sistem menyimpan file di Storage, metadata di Firestore, dan menjadwalkan pengingat.
4. Pengguna dapat membuka, mengunduh, berbagi, atau menghapus dokumen.

**Alur Alternatif:**
- `E9.A1 – Ajukan perpanjangan dokumen:` Pengguna menandai item `renewal_needed`; sistem mengirim notifikasi ke HR.
- `E9.A2 – Unduh bundel dokumen:` Sistem mengarsipkan beberapa dokumen menjadi ZIP untuk keperluan audit.

**Eksepsi Kegagalan:**
- `E9.E1 – Storage mencapai batas kuota pribadi:` Sistem menolak unggahan baru sampai pengguna menghapus atau meminta tambahan.
- `E9.E2 – File gagal diverifikasi (virus/malware):` Sistem memblok unggahan dan memberi instruksi hubungi HR.

**Pasca Kondisi:** Dokumen pribadi tersimpan dengan pengingat aktif dan dapat dipantau statusnya.

**Catatan Bisnis:** HR memerlukan akses baca untuk audit; pengguna diberi peringatan berkala sebelum dokumen kedaluwarsa.

---

### UC-E10 Menggunakan Chat & Kolaborasi
**Aktor Utama:** Karyawan  
**Stakeholder Pendukung:** Semua divisi internal  
**Pemicu:** Pengguna memilih tab Chat.  
**Prasyarat:** `UC-E4` selesai; akun memiliki izin chat.  
**Kebutuhan Data:** Daftar percakapan, pesan, status unread, lampiran, avatar kontak.  
**Validasi:** Perizinan mengakses grup, batas ukuran lampiran, filter kata tertentu (opsional).  
**Integrasi Sistem:** Firestore (`conversations`, `messages`), Firebase Storage (lampiran), Firebase Cloud Messaging, avatar caching.

**Alur Utama:**
1. Sistem memuat daftar percakapan dengan status unread/pinned/archived.
2. Pengguna membuka percakapan; sistem memuat pesan dan avatar dari cache/Storage.
3. Pengguna mengirim pesan teks atau lampiran; sistem menyimpan ke Firestore dan memicu notifikasi.
4. Pengguna dapat menandai pesan sebagai dibaca, mem-pinned, atau mengarsipkan percakapan.

**Alur Alternatif:**
- `E10.A1 – Mulai chat baru dari kontak internal:` Sistem menampilkan daftar kontak dan membuat percakapan baru.
- `E10.A2 – Mute percakapan:` Sistem menyimpan preferensi mute dan menghentikan notifikasi push untuk percakapan tersebut.

**Eksepsi Kegagalan:**
- `E10.E1 – Koneksi buruk:` Sistem masuk mode offline, menempatkan pesan baru di antrean lokal.
- `E10.E2 – Batas ukuran lampiran terlampaui:` Sistem menolak unggahan dan meminta kompresi.

**Pasca Kondisi:** Riwayat chat terbarui, status notifikasi sinkron dengan perangkat lain.

**Catatan Bisnis:** Chat inter-divisi harus menyimpan log minimal selama periode retensi perusahaan (mis. 365 hari).

---

### UC-E11 Mengelola Pengaturan Profil
**Aktor Utama:** Karyawan  
**Stakeholder Pendukung:** HR, IT Support  
**Pemicu:** Pengguna membuka tab Profil & Pengaturan.  
**Prasyarat:** `UC-E4` selesai.  
**Kebutuhan Data:** Data profil, foto, PIN, preferensi notifikasi, daftar kontak internal, status login perangkat.  
**Validasi:** Konfirmasi PIN baru, format nomor kontak, batas perubahan dalam satu hari.  
**Integrasi Sistem:** Firestore, Storage (foto), Firebase Cloud Messaging (topic), Secure Storage, Cloud Functions untuk logout multi-perangkat.

**Alur Utama:**
1. Sistem menampilkan detail profil, foto, PIN, serta daftar perangkat aktif.
2. Pengguna memperbarui foto atau data pribadi; sistem mengunggah dan menyimpan perubahan.
3. Pengguna dapat mengubah PIN melalui modal QR; sistem memvalidasi dan mensinkronkan ke admin.
4. Pengguna mengatur preferensi notifikasi (push, email) dan kontak internal.
5. Sistem menyimpan perubahan, memperbarui langganan notifikasi, dan menampilkan konfirmasi.

**Alur Alternatif:**
- `E11.A1 – Logout dari perangkat lain:` Pengguna memilih perangkat pada daftar; sistem mengirim perintah logout melalui Cloud Functions.
- `E11.A2 – Unduh kartu profil (vCard/QR):` Sistem menghasilkan file yang dapat dibagikan.

**Eksepsi Kegagalan:**
- `E11.E1 – PIN baru tidak cocok dengan konfirmasi:` Sistem menolak dan mengosongkan kolom PIN.
- `E11.E2 – Gagal memperbarui preferensi notifikasi (Firebase Messaging error):` Sistem menampilkan pesan dan menyarankan retry.

**Pasca Kondisi:** Profil, PIN, dan preferensi notifikasi terbaru tersimpan dan berlaku di seluruh perangkat.

**Catatan Bisnis:** Setiap perubahan kontak darurat harus memicu notifikasi ke HR untuk verifikasi manual.


---

### UC-A12 Audit Aktivitas Administrator
**Aktor Utama:** Super Administrator / Audit Officer  
**Stakeholder Pendukung:** Tim Keamanan TI, Compliance  
**Pemicu:** Audit berkala atau investigasi insiden membutuhkan riwayat aktivitas admin.  
**Prasyarat:** Seluruh interaksi admin ditulis ke koleksi audit.  
**Kebutuhan Data:** Log `admin_audit_trail`, metadata perangkat, IP address, hasil autentikasi, tindakan modul.  
**Validasi:** Hak akses audit-only, rentang tanggal, filter modul, status penyelidikan.  
**Integrasi Sistem:** Firestore (`admin_audit_trail`), BigQuery (sinkronisasi harian), Cloud Functions untuk redaksi data sensitif, export ke CSV/PDF.

**Alur Utama:**
1. Auditor membuka modul Audit dan memilih rentang tanggal serta modul yang ingin ditinjau.
2. Sistem menampilkan daftar aktivitas (login, perubahan data, approval) lengkap dengan detail perangkat/IP.
3. Auditor menerapkan filter tambahan (aktor, status, hasil) dan menandai temuan penting.
4. Auditor mengekspor laporan audit ke PDF/CSV untuk dokumentasi.

**Alur Alternatif:**
- `A12.A1 – Investigasi spesifik:` Auditor memasukkan ID referensi permintaan (absensi, cuti, material) dan sistem memuat histori lengkap terkait tindakan admin pada objek tersebut.
- `A12.A2 – Set bookmark:` Auditor memberi label pada entri audit untuk dibahas pada rapat atau eskalasi lanjutan.

**Eksepsi Kegagalan:**
- `A12.E1 – Data redacted:` Jika aktivitas terkait data sensitif (mis. gaji), sistem hanya menampilkan metadata dan meminta otorisasi tambahan.
- `A12.E2 – BigQuery offline:` Sistem memberi peringatan bahwa data historis >90 hari hanya tersedia setelah sinkronisasi pulih.

**Pasca Kondisi:** Laporan audit tersedia dan temuan dapat dibagikan ke pihak terkait.

**Catatan Bisnis:** Audit trail harus disimpan minimal 5 tahun dan dapat dipresentasikan kepada auditor eksternal.

---

### UC-A13 Validasi Bukti Absensi Manual
**Aktor Utama:** Administrator / Supervisor Lapangan  
**Stakeholder Pendukung:** HR, Project Manager  
**Pemicu:** Permintaan koreksi absensi masuk dari karyawan (hasil `UC-E13`).  
**Prasyarat:** Admin memiliki hak modul absensi dan log ditandai `needs_validation`.  
**Kebutuhan Data:** Log absensi, bukti foto/lokasi tambahan, alasan koreksi, histori tindakan, rekomendasi supervisor.  
**Validasi:** Kesesuaian bukti dengan kebijakan, ketersediaan jatah koreksi, status window.  
**Integrasi Sistem:** Firestore (`attendance_logs`, `attendance_corrections`), Storage (bukti tambahan), Cloud Functions (notifikasi hasil).

**Alur Utama:**
1. Admin membuka tab Koreksi Absensi dan melihat daftar permintaan pending dengan ringkasan alasan.
2. Admin meninjau bukti tambahan (foto, lokasi, lampiran supervisor).
3. Admin memilih keputusan (setujui/tolak/perlu info) dan mengisi catatan balik.
4. Sistem memperbarui log absensi, mengubah status koreksi, dan mengirim notifikasi ke karyawan.

**Alur Alternatif:**
- `A13.A1 – Eskalasi ke supervisor:` Admin meneruskan permintaan ke supervisor yang relevan sebelum membuat keputusan akhir.
- `A13.A2 – Jadwalkan wawancara:` Admin mengatur meeting/telepon via Kalender untuk klarifikasi lebih lanjut.

**Eksepsi Kegagalan:**
- `A13.E1 – Bukti tidak terbaca:` Sistem meminta karyawan mengunggah ulang; status menjadi `awaiting_resubmission`.
- `A13.E2 – Konflik jadwal shift:` Sistem meminta admin menyesuaikan shift terlebih dahulu sebelum menyetujui koreksi.

**Pasca Kondisi:** Log absensi diperbarui sesuai keputusan dan tercatat dalam audit trail.

**Catatan Bisnis:** Setiap koreksi harus selesai dalam 2 hari kerja guna menjaga akurasi payroll.

---

### UC-A14 Rekap & Ekspor Kehadiran Bulanan
**Aktor Utama:** Administrator / HR Reporter  
**Stakeholder Pendukung:** Finance, Manajemen Puncak  
**Pemicu:** Awal bulan atau kebutuhan laporan mendadak.  
**Prasyarat:** Data absensi sudah dikunci oleh admin modul.  
**Kebutuhan Data:** Rekap `attendance_summary`, daftar anomali, data koreksi, parameter periode.  
**Validasi:** Periode tidak boleh overlap dengan rekap sebelumnya, akses departemen sesuai role.  
**Integrasi Sistem:** BigQuery (agregasi), Cloud Functions (generate laporan), Storage (output PDF/CSV), Email service.

**Alur Utama:**
1. Admin memilih periode rekap (misal bulan berjalan) dan memilih format output.
2. Sistem menghitung rekap kehadiran per divisi/tim beserta statistik keterlambatan dan izin.
3. Sistem menambahkan lampiran anomali (koreksi pending, log manual).
4. Laporan diekspor ke PDF/CSV dan didistribusikan ke daftar email yang dipilih.

**Alur Alternatif:**
- `A14.A1 – Custom field:` Admin menambah kolom tambahan (mis. jam lembur); sistem menarik data dari modul lain bila tersedia.
- `A14.A2 – Branding laporan:` Admin memilih template (logo, warna perusahaan) sebelum ekspor.

**Eksepsi Kegagalan:**
- `A14.E1 – Agregasi gagal:` Sistem menampilkan status `processing` dan memberi opsi pemberitahuan via email saat siap.
- `A14.E2 – Periode belum dikunci:` Sistem meminta admin mengunci data absensi terlebih dahulu untuk mencegah perubahan setelah rekap.

**Pasca Kondisi:** Laporan kehadiran bulanan tersedia dan siap digunakan untuk payroll atau presentasi manajemen.

**Catatan Bisnis:** Arsip laporan wajib tersimpan dan dapat diakses pada portal manajemen untuk audit.

---

### UC-A15 Kelola Template Dokumen Pemberkasan
**Aktor Utama:** Administrator / Legal Officer  
**Stakeholder Pendukung:** HR, Divisi Legal  
**Pemicu:** Perubahan format dokumen perusahaan atau penambahan template baru.  
**Prasyarat:** Admin memiliki izin modul pemberkasan.  
**Kebutuhan Data:** Template dokumen (DOCX, PDF), metadata template (jenis, versi, tanggal berlaku), daftar pengguna template.  
**Validasi:** Versi baru harus lebih tinggi, file bebas malware, kewenangan pengunggah.  
**Integrasi Sistem:** Storage (folder template), Firestore (`document_templates`), Cloud Functions (versi dan distribusi), layanan pemindaian virus.

**Alur Utama:**
1. Admin membuka manajemen template dan melihat daftar template aktif/belum aktif.
2. Admin mengunggah template baru atau memperbarui versi template eksisting.
3. Sistem memvalidasi file, menjalankan virus scan, dan menetapkan status `draft`.
4. Admin meninjau pratinjau, menentukan tanggal berlaku, lalu memublikasikan template.
5. Sistem memberitahu admin lain/karyawan yang menggunakan template terkait perubahan versi.

**Alur Alternatif:**
- `A15.A1 – Rollback versi:` Admin mengembalikan ke versi sebelumnya jika ditemukan masalah; sistem menandai alasan rollback.
- `A15.A2 – Template khusus departemen:` Admin menetapkan visibilitas template untuk departemen tertentu saja.

**Eksepsi Kegagalan:**
- `A15.E1 – File gagal melewati virus scan:` Sistem menolak dan meminta unggahan ulang dengan sumber terpercaya.
- `A15.E2 – Konflik tanggal berlaku:` Sistem menolak jika dua template tipe sama memiliki tanggal aktif bersamaan.

**Pasca Kondisi:** Template pemberkasan terbaru tersedia dan terdistribusi sesuai kebijakan.

**Catatan Bisnis:** Setiap perubahan template harus disetujui Legal dan dicatat dalam register kebijakan perusahaan.

---

### UC-A16 Eskalasi Dokumen Kadaluarsa
**Aktor Utama:** Administrator / HR Compliance  
**Stakeholder Pendukung:** Legal, Atasan Karyawan  
**Pemicu:** Pengingat dokumen akan kedaluwarsa (hasil `UC-A8` dan notifikasi otomatis).  
**Prasyarat:** Jadwal pengingat aktif; dokumen memiliki tanggal kedaluwarsa.  
**Kebutuhan Data:** Metadata dokumen, status pengingat, kontak karyawan, eskalasi level 2/3.  
**Validasi:** Level eskalasi sesuai SOP, status dokumen belum diperbarui, tracking email/push.  
**Integrasi Sistem:** Firestore (`document_expiry_tasks`), Cloud Functions (scheduler & escalation), Email/SMS gateway.

**Alur Utama:**
1. Sistem mengelompokkan dokumen yang akan kedaluwarsa (30/7/1 hari sebelum) dan menampilkan daftar tugas eskalasi.
2. HR Compliance menghubungi karyawan via email/push dari modul dan mencatat tindak lanjut.
3. Jika tidak ada respons, sistem otomatis mengirim eskalasi ke atasan dan menandai status `escalated`.
4. Setelah dokumen diperbarui, HR menutup tugas eskalasi dengan status `resolved`.

**Alur Alternatif:**
- `A16.A1 – Penjadwalan ulang:` HR memberikan pengecualian dengan menetapkan tanggal kedaluwarsa baru sementara.
- `A16.A2 – Dokumen tidak lagi diperlukan:` HR menandai `waived` dengan alasan resmi dan sistem menghentikan pengingat.

**Eksepsi Kegagalan:**
- `A16.E1 – Gateway email/SMS gagal:` Sistem mencoba ulang dan menampilkan banner peringatan di dashboard HR.
- `A16.E2 – Dokumen diperbarui tetapi metadata tidak sinkron:` Sistem menawarkan sinkron manual untuk memaksa refresh metadata.

**Pasca Kondisi:** Status dokumen kedaluwarsa tercatat, dan eskalasi terdokumentasi untuk audit.

**Catatan Bisnis:** Proses eskalasi wajib menunjukkan bukti kontak saat presentasi kepatuhan kepada auditor.

---

### UC-A17 Rekonsiliasi Permintaan Material & Stok
**Aktor Utama:** Administrator Logistik / Finance Controller  
**Stakeholder Pendukung:** Gudang, Project Manager, Finance  
**Pemicu:** Penutupan periode proyek atau permintaan audit stok.  
**Prasyarat:** Data permintaan material dan stok gudang tersedia.  
**Kebutuhan Data:** `material_requests`, data penerimaan gudang, stok tersisa, nilai pengadaan, lampiran bukti.  
**Validasi:** Permintaan delivered memiliki bukti penerimaan, selisih stok dalam toleransi, hak akses modul finance.  
**Integrasi Sistem:** Firestore, ERP/Gudang API (jika tersedia), Cloud Functions (rekonsiliasi), generator Spreadsheet/PDF.

**Alur Utama:**
1. Admin logistik memilih proyek/periodisasi untuk direkonsiliasi.
2. Sistem menampilkan daftar permintaan material dengan status delivered serta stok yang tercatat.
3. Admin memverifikasi bukti penerimaan gudang dan menandai selisih jika ada.
4. Sistem menghasilkan laporan rekonsiliasi yang dapat dibagikan ke Finance.

**Alur Alternatif:**
- `A17.A1 – Sinkron data gudang:` Admin menjalankan sinkron manual dari ERP untuk menarik data stok terbaru.
- `A17.A2 – Buat jurnal koreksi:` Jika terdapat selisih, admin membuat jurnal koreksi yang akan dikirim ke modul Finance.

**Eksepsi Kegagalan:**
- `A17.E1 – Data gudang tidak tersedia:` Sistem menandai status `awaiting_external_sync` dan memberi instruksi menghubungi admin gudang.
- `A17.E2 – Permintaan belum ditandai delivered:` Sistem meminta admin memastikan status di `UC-A9` sebelum melanjutkan.

**Pasca Kondisi:** Laporan rekonsiliasi lengkap dengan bukti siap untuk presentasi atau audit internal.

**Catatan Bisnis:** Rekonsiliasi berkala membantu menyiapkan bahan presentasi kepada dosen/auditor mengenai kontrol internal rantai pasok.

---

### UC-E12 Lihat Riwayat Absensi & Status
**Aktor Utama:** Karyawan  
**Stakeholder Pendukung:** HR, Supervisor Tim  
**Pemicu:** Pengguna ingin memeriksa histori absensi pribadi.  
**Prasyarat:** `UC-E5` sudah menghasilkan log absensi.  
**Kebutuhan Data:** Log `attendance_logs`, status koreksi, catatan admin, filter tanggal.  
**Validasi:** Akses hanya untuk data pribadi, rentang tanggal <= 3 bulan (default).  
**Integrasi Sistem:** Firestore, lokal cache, export PDF/CSV generator.

**Alur Utama:**
1. Pengguna membuka Riwayat Absensi dari modul Absensi.
2. Sistem menampilkan daftar hadir/pulang dengan filter status (disetujui, pending, ditolak).
3. Pengguna menerapkan filter tanggal atau status dan melihat detail (foto, lokasi, catatan admin).
4. Pengguna dapat mengekspor riwayat menjadi PDF/CSV untuk diserahkan ke HR atau dosen pembimbing.

**Alur Alternatif:**
- `E12.A1 – Tandai entri bermasalah:` Pengguna menandai log tertentu untuk diajukan koreksi (`UC-E13`).
- `E12.A2 – Mode offline:` Sistem menampilkan data cache dan memberi penanda bahwa data mungkin belum terbaru.

**Eksepsi Kegagalan:**
- `E12.E1 – Riwayat kosong:` Sistem menampilkan pesan dan tautan cepat untuk melakukan absensi.
- `E12.E2 – Gagal ekspor:` Sistem menyarankan ulangi ekspor atau menghubungi admin.

**Pasca Kondisi:** Pengguna mengetahui status absensi dan memiliki bukti bila dibutuhkan.

**Catatan Bisnis:** Fitur ini memudahkan penyusunan bukti kehadiran saat presentasi tugas akhir.

---

### UC-E13 Ajukan Koreksi Absensi
**Aktor Utama:** Karyawan  
**Stakeholder Pendukung:** Supervisor Tim, HR  
**Pemicu:** Pengguna menemukan log absensi yang salah pada `UC-E12`.  
**Prasyarat:** `UC-E5` mencatat log; periode koreksi masih dibuka.  
**Kebutuhan Data:** Log yang dipersoalkan, bukti tambahan (foto, lokasi), alasan koreksi, rekomendasi supervisor (opsional).  
**Validasi:** Batas waktu koreksi (misal maks. 3 hari setelah kejadian), format alasan, ukuran bukti.  
**Integrasi Sistem:** Firestore (`attendance_corrections`), Storage, notifikasi ke admin (`UC-A13`).

**Alur Utama:**
1. Pengguna memilih log yang ingin dikoreksi dan menekan tombol Ajukan Koreksi.
2. Sistem meminta jenis kesalahan (lupa check-in, salah lokasi, dsb) serta alasan rinci.
3. Pengguna mengunggah bukti tambahan seperti foto lokasi atau surat tugas.
4. Sistem menyimpan permohonan dengan status `pending_validation` dan mengirim notifikasi ke admin.

**Alur Alternatif:**
- `E13.A1 – Tambah rekomendasi supervisor:` Pengguna meminta supervisor memberikan catatan pendukung sebelum mengirim.
- `E13.A2 – Simpan draft:` Pengguna menyimpan pengajuan untuk melengkapi bukti di lain waktu.

**Eksepsi Kegagalan:**
- `E13.E1 – Batas koreksi terlewat:` Sistem menolak dengan pesan dan menyarankan menghubungi HR langsung.
- `E13.E2 – Bukti gagal diunggah:` Sistem menyimpan permohonan tanpa bukti dan menandai sebagai `needs_attachment`.

**Pasca Kondisi:** Permohonan koreksi tersimpan dan menunggu validasi admin (`UC-A13`).

**Catatan Bisnis:** Jumlah koreksi per karyawan dibatasi; statistiknya bisa dipakai dalam presentasi evaluasi kinerja.

---

### UC-E14 Lihat Jadwal Shift & Penugasan
**Aktor Utama:** Karyawan  
**Stakeholder Pendukung:** Supervisor Lapangan, HR  
**Pemicu:** Pengguna membuka tab Jadwal/Shift.  
**Prasyarat:** Admin telah mengunggah jadwal melalui modul HR atau integrasi eksternal.  
**Kebutuhan Data:** Jadwal shift mingguan/bulanan, lokasi penugasan, status penugasan (aktif, dipindahtugaskan).  
**Validasi:** Hak melihat jadwal tim sendiri, data sinkron.  
**Integrasi Sistem:** Firestore (`shift_assignments`), Calendar sync, Notifications.

**Alur Utama:**
1. Sistem menampilkan kalender shift dengan kode warna (pagi, siang, malam, libur).
2. Pengguna melihat detail shift termasuk lokasi, supervisor, dan catatan khusus (mis. perlengkapan wajib).
3. Pengguna mengunduh jadwal ke kalender pribadi atau membagikannya via chat.

**Alur Alternatif:**
- `E14.A1 – Tukar shift:` Pengguna mengajukan permintaan tukar shift dengan rekan; sistem mengirim notifikasi ke supervisor.
- `E14.A2 – Lihat shift historis:` Pengguna memeriksa catatan shift sebelumnya untuk pelaporan ke dosen.

**Eksepsi Kegagalan:**
- `E14.E1 – Jadwal belum dipublikasikan:` Sistem menampilkan pesan menunggu rilis dan memberi notifikasi ketika tersedia.
- `E14.E2 – Konflik sinkronisasi:` Sistem meminta refresh dan menampilkan data terakhir yang valid.

**Pasca Kondisi:** Pengguna memahami jadwal kerja dan dapat merencanakan kegiatan lainnya.

**Catatan Bisnis:** Jadwal shift menjadi bukti keterlibatan proyek saat presentasi atau magang.

---

### UC-E15 Bagikan Event Kalender ke Rekan
**Aktor Utama:** Karyawan  
**Stakeholder Pendukung:** Rekan Tim, Supervisor  
**Pemicu:** Pengguna ingin mengundang rekan lain ke event tim (`UC-E7`).  
**Prasyarat:** Event sudah dibuat dan pengguna punya hak mengundang.  
**Kebutuhan Data:** Event ID, daftar kontak internal, opsi RSVP, catatan undangan.  
**Validasi:** Hak mengundang (pemilik event atau diizinkan), jumlah undangan dalam batas.  
**Integrasi Sistem:** Firestore (`team_events_invites`), modul Chat (`UC-E10`), layanan email.

**Alur Utama:**
1. Pengguna membuka detail event dan memilih opsi Bagikan/Undang.
2. Sistem menampilkan daftar kontak internal; pengguna memilih rekan dan menambahkan pesan.
3. Sistem mengirim undangan via chat push serta (opsional) email.
4. Status RSVP rekan tercatat dan dapat dipantau oleh pembuat event.

**Alur Alternatif:**
- `E15.A1 – Bagikan tautan publik internal:` Sistem membuat deep-link sehingga rekan dapat langsung membuka event.
- `E15.A2 – Tambah ke grup chat:` Sistem otomatis mengirim ringkasan event ke grup chat terkait.

**Eksepsi Kegagalan:**
- `E15.E1 – Kontak tidak aktif:` Sistem memberi tahu pengguna dan menyarankan hubungi supervisor.
- `E15.E2 – Batas undangan tercapai:` Sistem menolak undangan tambahan dan menyarankan membuat event terpisah.

**Pasca Kondisi:** Rekan menerima undangan event dan status RSVP tercatat.

**Catatan Bisnis:** Bukti kolaborasi tim melalui event dapat ditunjukkan pada presentasi proyek kepada dosen.

---

### UC-E16 Laporkan Masalah Aplikasi
**Aktor Utama:** Karyawan  
**Stakeholder Pendukung:** Tim IT Support, HR  
**Pemicu:** Pengguna mengalami bug atau kendala penggunaan modul.  
**Prasyarat:** Sesi aktif; modul Feedback tersedia.  
**Kebutuhan Data:** Deskripsi masalah, langkah reproduksi, screenshot/log, prioritas, kategori modul.  
**Validasi:** Panjang deskripsi minimal, ukuran lampiran, pemilihan kategori.  
**Integrasi Sistem:** Firestore (`app_support_tickets`), Storage (lampiran), Cloud Functions (routing ticket), integrasi dengan Jira/Trello (opsional).

**Alur Utama:**
1. Pengguna membuka menu Bantuan & Dukungan dan memilih Laporkan Masalah.
2. Pengguna mengisi formulir deskripsi, modul terkait, level urgensi, serta melampirkan screenshot.
3. Sistem menyimpan tiket, memberikan nomor referensi, dan mengirim notifikasi ke tim IT support.
4. Pengguna dapat memantau status tiket (open, in progress, resolved) dan menerima update via push.

**Alur Alternatif:**
- `E16.A1 – Chat langsung dengan admin:` Sistem memulai percakapan di `UC-E10` dengan bot/agent support.
- `E16.A2 – Lampirkan log otomatis:` Sistem menawarkan untuk mengirim log aplikasi (crash data) bersama tiket.

**Eksepsi Kegagalan:**
- `E16.E1 – Unggahan screenshot gagal:` Sistem menyimpan tiket tanpa lampiran dan meminta pengguna mengunggah ulang.
- `E16.E2 – Tidak ada koneksi:` Sistem menyimpan tiket di antrean lokal dan mengirim saat online.

**Pasca Kondisi:** Tiket support tercatat dan ditangani tim IT, memudahkan pelacakan masalah aplikasi.

**Catatan Bisnis:** Statistik tiket dapat digunakan sebagai bahan evaluasi kualitas aplikasi saat presentasi.

---

### UC-E17 Kelola Perangkat Aktif
**Aktor Utama:** Karyawan  
**Stakeholder Pendukung:** HR, Tim Keamanan TI  
**Pemicu:** Pengguna membuka tab Keamanan pada Profil & Pengaturan (`UC-E11`).  
**Prasyarat:** Multi-perangkat login diizinkan maksimal dua perangkat.  
**Kebutuhan Data:** Daftar perangkat aktif (nama, jenis, lokasi terakhir, waktu login), status kepercayaan perangkat.  
**Validasi:** Pengguna hanya dapat menghapus perangkat miliknya, batas perangkat minimal 1.  
**Integrasi Sistem:** Firestore (`user_devices`), Cloud Functions (force logout), push notification.

**Alur Utama:**
1. Sistem menampilkan daftar perangkat yang sedang login bersama detail lokasi terakhir.
2. Pengguna menandai perangkat sebagai terpercaya atau menghapus perangkat yang tidak dikenali.
3. Jika menghapus, sistem mengirim perintah force logout ke perangkat tersebut dan mencatat alasan.
4. Sistem mengirim konfirmasi dan, jika perlu, notifikasi ke HR untuk tindakan keamanan.

**Alur Alternatif:**
- `E17.A1 – Aktifkan verifikasi dua langkah:` Pengguna menyalakan toggle 2FA sehingga login berikutnya memerlukan OTP/email.
- `E17.A2 – Nama perangkat kustom:` Pengguna mengganti nama perangkat untuk memudahkan identifikasi.

**Eksepsi Kegagalan:**
- `E17.E1 – Force logout gagal:` Sistem menandai `pending` dan akan mencoba ulang; pengguna menerima pemberitahuan.
- `E17.E2 – Upaya menghapus perangkat terakhir:` Sistem menolak agar tetap ada satu perangkat aktif.

**Pasca Kondisi:** Daftar perangkat ter-update, meningkatkan keamanan akun.

**Catatan Bisnis:** Log pengelolaan perangkat dapat menjadi bahan presentasi mengenai kontrol keamanan pengguna akhir.

---
