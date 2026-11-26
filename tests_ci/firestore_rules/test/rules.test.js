/**
 * Black Box test aturan keamanan Firestore (firestore.rules) - PT Cipta Vera Mandiri.
 * Penamaan: "BB-xx" = ID kasus pada Hasil_Pengujian.xlsx (sheet Black Box); "RULE-xx" = klaim keamanan tambahan.
 * Tanda [TEMUAN] = harapan AMAN yang diperkirakan GAGAL pada aturan saat ini (kegagalan = temuan nyata).
 */
const {createEnv, seed, dbAs, ts, now, assertSucceeds, assertFails} = require("./helpers");

let env;
beforeAll(async () => { env = await createEnv(); });
afterAll(async () => { await env.cleanup(); });

const as = (uid) => dbAs(env, uid);
const baseSeed = (extra) => () => seed(env, extra);

// ---------------------------------------------------------------- users
describe("users/{uid} (profil, PIN, peran)", () => {
  beforeEach(baseSeed());

  test("BB-10 pemilik melengkapi profil (nama, divisi, foto, PIN) pada dokumennya sendiri", async () => {
    await assertSucceeds(as("kantor").doc("users/kantor").update({
      name: "Rina Finance", role: "Finance", photoUrl: "https://example.test/rina.jpg",
      pin: "A1B2C3", chatPin: "A1B2C3", profileCompleted: true, updatedAt: now(),
    }));
  });

  test("BB-10 pengguna baru membuat dokumen profil miliknya (signup)", async () => {
    const db = env.authenticatedContext("baru", {email: "baru@cvm.test"}).firestore();
    await assertSucceeds(db.doc("users/baru").set({
      email: "baru@cvm.test", name: "Pegawai Baru", profileCompleted: false, createdAt: now(),
    }));
  });

  test("BB-30 pemilik mengganti foto profil", async () => {
    await assertSucceeds(as("lapangan").doc("users/lapangan").update({photoUrl: "https://example.test/baru.jpg"}));
  });

  test("BB-25 / BB-27 pengguna login dapat membaca profil pegawai lain (pencarian kontak)", async () => {
    await assertSucceeds(as("lapangan").doc("users/kantor").get());
  });

  test("RULE-01 pegawai tidak dapat mengubah profil pegawai lain", async () => {
    await assertFails(as("lain").doc("users/kantor").update({name: "Diretas"}));
  });

  test("RULE-02 pengguna tanpa login tidak dapat membaca profil", async () => {
    await assertFails(as(null).doc("users/kantor").get());
  });

  test("RULE-03 pengguna tanpa login tidak dapat mengubah profil", async () => {
    await assertFails(as(null).doc("users/kantor").update({name: "Anon"}));
  });

  test("RULE-04 [TEMUAN] pemilik TIDAK boleh menaikkan peran dirinya menjadi superAdmin", async () => {
    await assertFails(as("kantor").doc("users/kantor").update({roles: {superAdmin: true}}));
  });

  test("RULE-05 [TEMUAN] pemilik TIDAK boleh menambah peran modul (attendance) untuk dirinya sendiri", async () => {
    await assertFails(as("lapangan").doc("users/lapangan").update({"roles.attendance": true}));
  });

  test("RULE-06 [TEMUAN] pengguna baru TIDAK boleh membuat dokumen profil sendiri berisi roles.superAdmin=true", async () => {
    const db = env.authenticatedContext("penyusup", {email: "p@cvm.test"}).firestore();
    await assertFails(db.doc("users/penyusup").set({email: "p@cvm.test", roles: {superAdmin: true}}));
  });

  test("BB-66 Super Admin mengubah nama dan divisi pengguna lain", async () => {
    await assertSucceeds(as("superAdmin").doc("users/kantor").update({name: "Rina Baru", role: "Administrations"}));
  });

  test("BB-68 Super Admin memberi peran modul (attendance) kepada pegawai", async () => {
    await assertSucceeds(as("superAdmin").doc("users/lapangan").update({roles: {attendance: true}}));
  });

  test("BB-69 (sisi aturan) admin peran 'users' non-Super Admin tidak dapat mengubah peran orang lain", async () => {
    await assertFails(as("adminUsers").doc("users/lapangan").update({roles: {superAdmin: true}}));
  });

  test("RULE-07 [TEMUAN] admin peran 'users' dapat mengubah nama/PIN pengguna lain (fitur tab Pengguna)", async () => {
    // fakta_proyek 3.2: peran 'users' = lihat/edit profil dan PIN pengguna. Aturan hanya mengizinkan admin/superAdmin.
    await assertSucceeds(as("adminUsers").doc("users/lapangan").update({name: "Budi Diubah Admin"}));
  });

  test("RULE-08 hanya admin/superAdmin yang dapat menghapus dokumen pengguna", async () => {
    await assertFails(as("lain").doc("users/kantor").delete());
    await assertSucceeds(as("superAdmin").doc("users/kantor").delete());
  });

  test("BB-27 pemilik mengelola daftar kontaknya; pegawai lain tidak dapat membaca/menulisnya", async () => {
    await assertSucceeds(as("lapangan").doc("users/lapangan/contacts/kantor").set({uid: "kantor", addedAt: now()}));
    await assertFails(as("lain").doc("users/lapangan/contacts/kantor").get());
    await assertFails(as("lain").doc("users/lapangan/contacts/x").set({uid: "x"}));
  });
});

// ---------------------------------------------------------------- chat
describe("chats dan messages", () => {
  const chat = {members: ["lapangan", "kantor"], createdBy: "lapangan", memberInfo: {lapangan: {name: "Budi"}, kantor: {name: "Rina"}}};
  beforeEach(baseSeed(async (db) => { await db.doc("chats/c1").set(chat); }));

  test("BB-29 pegawai membuat chat grup (dirinya termasuk anggota)", async () => {
    await assertSucceeds(as("lapangan").doc("chats/c_grup").set({
      type: "group", name: "Tim Proyek A", members: ["lapangan", "kantor", "lain"], createdBy: "lapangan", createdAt: now(),
    }));
  });

  test("BB-28 anggota chat mengirim pesan; anggota lain dapat membacanya", async () => {
    await assertSucceeds(as("lapangan").doc("chats/c1/messages/m1").set({senderId: "lapangan", text: "Halo Rina", createdAt: now()}));
    await assertSucceeds(as("kantor").doc("chats/c1/messages/m2").set({senderId: "kantor", text: "Halo Budi", createdAt: now()}));
    await assertSucceeds(as("kantor").doc("chats/c1/messages/m1").get());
  });

  test("RULE-09 non-anggota tidak dapat membaca maupun mengirim pesan pada chat orang lain", async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      ctx.firestore().doc("chats/c1/messages/m0").set({senderId: "kantor", text: "rahasia", createdAt: now()}));
    await assertFails(as("lain").doc("chats/c1/messages/m0").get());
    await assertFails(as("lain").doc("chats/c1/messages/m9").set({senderId: "lain", text: "nyelonong", createdAt: now()}));
  });

  test("RULE-09b pengirim tidak dapat memalsukan senderId pegawai lain", async () => {
    await assertFails(as("lapangan").doc("chats/c1/messages/m5").set({senderId: "kantor", text: "palsu", createdAt: now()}));
  });

  test("RULE-10 [TEMUAN] non-anggota TIDAK boleh membaca dokumen chat (metadata, daftar anggota) milik orang lain", async () => {
    await assertFails(as("lain").doc("chats/c1").get());
  });

  test("RULE-11 non-anggota tidak dapat mengubah dokumen chat orang lain", async () => {
    await assertFails(as("lain").doc("chats/c1").update({members: ["lain"]}));
  });

  test("RULE-11b pengguna tanpa login tidak dapat membuat chat", async () => {
    await assertFails(as(null).doc("chats/cx").set({members: ["a"], createdBy: "a"}));
  });
});

// ---------------------------------------------------------------- attendance
describe("users/{uid}/attendance dan attendance_feed (presensi)", () => {
  const rec = () => ({
    uid: "lapangan", userUid: "lapangan", userName: "Budi Lapangan", userEmail: "budi@cvm.test",
    type: "checkin", status: "Hadir", date: ts("2026-11-23T08:40:00+08:00"), createdAt: ts("2026-11-23T08:40:00+08:00"),
    time: 1795480800000, latitude: -3.3194, longitude: 114.5908, project: "Proyek Jembatan A",
    locationPhotoUrl: "https://example.test/lokasi.jpg",
  });
  const feed = () => ({
    uid: "lapangan", userName: "Budi Lapangan", type: "checkin", status: "Hadir", project: "Proyek Jembatan A",
    source: "mobile", date: ts("2026-11-23T08:40:00+08:00"), createdAt: ts("2026-11-23T08:40:00+08:00"),
    time: 1795480800000, latitude: -3.3194, longitude: 114.5908,
  });
  beforeEach(baseSeed(async (db) => { await db.doc("users/lapangan/attendance/a1").set(rec()); }));

  test("BB-14 pegawai menyimpan check-in tepat waktu pada subkoleksi miliknya", async () => {
    await assertSucceeds(as("kantor").doc("users/kantor/attendance/a2").set({...rec(), uid: "kantor", userUid: "kantor"}));
  });

  test("BB-14 pegawai menulis salinan feed presensinya (attendance_feed)", async () => {
    await assertSucceeds(as("lapangan").doc("attendance_feed/f1").set(feed()));
  });

  test("BB-16 check-in terlambat dengan alasan (note) tersimpan", async () => {
    await assertSucceeds(as("lapangan").doc("users/lapangan/attendance/a3").set({...rec(), status: "Terlambat", note: "Ban bocor di jalan"}));
  });

  test("RULE-12 pegawai tidak dapat menulis presensi atas nama pegawai lain", async () => {
    await assertFails(as("lain").doc("users/lapangan/attendance/a4").set(rec()));
    await assertFails(as("lain").doc("attendance_feed/f2").set(feed())); // uid pada feed != uid login
  });

  test("RULE-13 dokumen presensi dengan field di luar daftar yang diizinkan ditolak", async () => {
    await assertFails(as("lapangan").doc("users/lapangan/attendance/a5").set({...rec(), isAdminOverride: true}));
  });

  test("RULE-14 pemilik tidak dapat mengubah atau menghapus rekaman presensinya setelah tersimpan", async () => {
    await assertFails(as("lapangan").doc("users/lapangan/attendance/a1").update({status: "Hadir (diubah)"}));
    await assertFails(as("lapangan").doc("users/lapangan/attendance/a1").delete());
  });

  test("BB-19 pemilik membaca riwayat presensinya sendiri", async () => {
    await assertSucceeds(as("lapangan").doc("users/lapangan/attendance/a1").get());
  });

  test("RULE-15 pegawai tidak dapat membaca presensi pegawai lain", async () => {
    await assertFails(as("lain").doc("users/lapangan/attendance/a1").get());
  });

  test("BB-53 admin peran attendance membaca detail rekaman presensi pegawai", async () => {
    await assertSucceeds(as("adminAbsen").doc("users/lapangan/attendance/a1").get());
  });

  test("BB-54 admin peran attendance mengoreksi status presensi menjadi Izin (manual)", async () => {
    await assertSucceeds(as("adminAbsen").doc("users/lapangan/attendance/a1").update({
      type: "izin", status: "Izin", manualByAdmin: true, adminStatus: "izin", source: "admin",
    }));
  });

  test("RULE-16 pengguna tanpa login tidak dapat membaca/menulis presensi", async () => {
    await assertFails(as(null).doc("users/lapangan/attendance/a1").get());
    await assertFails(as(null).doc("attendance_feed/f3").set(feed()));
  });

  test("RULE-17 feed presensi hanya dibaca admin/peran attendance, bukan pegawai biasa", async () => {
    await env.withSecurityRulesDisabled((ctx) => ctx.firestore().doc("attendance_feed/f9").set(feed()));
    await assertFails(as("lain").doc("attendance_feed/f9").get());
    await assertSucceeds(as("adminAbsen").doc("attendance_feed/f9").get());
  });
});

// ---------------------------------------------------------------- attendance_windows & admin_signals
describe("attendance_windows dan admin_signals (jadwal absen manual)", () => {
  const win = () => ({
    openAt: ts("2026-11-23T08:30:00+08:00"), closeAt: ts("2026-11-23T09:30:00+08:00"),
    lateGraceMinutes: 30, updatedAt: ts("2026-11-23T06:00:00+08:00"),
  });
  const signal = (uid) => ({
    type: "attendance_open", adminUid: uid, adminEmail: `${uid}@cvm.test`,
    createdAt: ts("2026-11-23T08:30:00+08:00"), issuedAt: ts("2026-11-23T08:30:00+08:00"),
  });
  beforeEach(baseSeed(async (db) => { await db.doc("attendance_windows/2026-11-24").set(win()); }));

  test("BB-11 pegawai dapat membaca jadwal absen hari ini", async () => {
    await assertSucceeds(as("lapangan").doc("attendance_windows/2026-11-24").get());
  });

  test("RULE-18 pengguna tanpa login tidak dapat membaca jadwal absen", async () => {
    await assertFails(as(null).doc("attendance_windows/2026-11-24").get());
  });

  test("BB-50 Super Admin membuat/mengatur jadwal absen manual", async () => {
    await assertSucceeds(as("superAdmin").doc("attendance_windows/2026-11-23").set(win()));
  });

  test("BB-50 [TEMUAN] admin peran 'attendance' (Admin Divisi Administrasi) dapat membuka absensi (jadwal tersimpan)", async () => {
    // Skenario BB-50 aktor = Admin Divisi Administrasi (roles.attendance). Aturan hanya mengizinkan isAdmin() (admin/superAdmin).
    await assertSucceeds(as("adminAbsen").doc("attendance_windows/2026-11-23").set(win()));
  });

  test("BB-50 [TEMUAN] admin peran 'attendance' dapat menulis sinyal admin_signals (pemicu notifikasi)", async () => {
    await assertSucceeds(as("adminAbsen").doc("admin_signals/s1").set(signal("adminAbsen")));
  });

  test("BB-50 Super Admin menulis sinyal attendance_open", async () => {
    await assertSucceeds(as("superAdmin").doc("admin_signals/s2").set(signal("superAdmin")));
  });

  test("BB-51 Super Admin menutup absensi (hapus jadwal)", async () => {
    await assertSucceeds(as("superAdmin").doc("attendance_windows/2026-11-24").delete());
  });

  test("BB-51 [TEMUAN] admin peran 'attendance' dapat menghapus jadwal absen (tutup absensi)", async () => {
    await assertSucceeds(as("adminAbsen").doc("attendance_windows/2026-11-24").delete());
  });

  test("RULE-19 pegawai biasa tidak dapat membuat, mengubah, atau menghapus jadwal absen", async () => {
    await assertFails(as("lapangan").doc("attendance_windows/2026-11-23").set(win()));
    await assertFails(as("lapangan").doc("attendance_windows/2026-11-24").update({lateGraceMinutes: 600}));
    await assertFails(as("lapangan").doc("attendance_windows/2026-11-24").delete());
    await assertFails(as(null).doc("attendance_windows/2026-11-24").delete());
  });

  test("RULE-20 jadwal dengan field di luar daftar atau tipe salah ditolak (admin)", async () => {
    await assertFails(as("superAdmin").doc("attendance_windows/2026-11-25").set({...win(), extra: 1}));
    await assertFails(as("superAdmin").doc("attendance_windows/2026-11-25").set({...win(), lateGraceMinutes: "30"}));
  });

  test("RULE-21 pegawai biasa tidak dapat menulis atau membaca admin_signals; sinyal tidak dapat diubah", async () => {
    await assertFails(as("lapangan").doc("admin_signals/s3").set(signal("lapangan")));
    await assertFails(as("lapangan").doc("admin_signals/s3").get());
    await env.withSecurityRulesDisabled((ctx) => ctx.firestore().doc("admin_signals/s4").set(signal("superAdmin")));
    await assertFails(as("superAdmin").doc("admin_signals/s4").update({type: "attendance_close"}));
  });

  test("BB-07 (sisi aturan) akun tanpa roles tidak dapat menulis modul admin mana pun", async () => {
    await assertFails(as("kantor").doc("attendance_windows/2026-11-26").set(win()));
    await assertFails(as("kantor").doc("leave_requests/lr_x").update({status: "approved"}));
  });
});

// ---------------------------------------------------------------- leave_requests
describe("leave_requests (cuti dan izin)", () => {
  const cuti = (uid = "kantor") => ({
    uid, kind: "cuti", reason: "Keperluan keluarga", status: "pending",
    startAt: ts("2026-12-01T00:00:00+08:00"), endAt: ts("2026-12-03T00:00:00+08:00"),
    createdAt: ts("2026-11-26T10:00:00+08:00"), requesterName: "Rina Finance", requesterEmail: "rina@cvm.test",
    daySpan: 3, attachments: [{name: "surat.pdf", url: "https://example.test/surat.pdf"}],
  });
  const izin = () => ({
    uid: "lapangan", kind: "izin", reason: "Mengurus SIM", status: "pending",
    startAt: ts("2026-12-02T09:00:00+08:00"), endAt: ts("2026-12-02T12:00:00+08:00"),
    createdAt: ts("2026-11-26T10:00:00+08:00"), startTimeText: "09:00", endTimeText: "12:00",
  });
  beforeEach(baseSeed(async (db) => { await db.doc("leave_requests/lr1").set(cuti()); }));

  test("BB-21 pegawai mengajukan cuti lengkap dengan lampiran (status pending)", async () => {
    await assertSucceeds(as("kantor").doc("leave_requests/lr2").set(cuti()));
  });

  test("BB-22 [TEMUAN] pengajuan cuti dengan alasan kosong ditolak server (validasi bukan hanya di klien)", async () => {
    await assertFails(as("kantor").doc("leave_requests/lr3").set({...cuti(), reason: ""}));
  });

  test("BB-22 pengajuan cuti tanpa field alasan sama sekali ditolak", async () => {
    const {reason, ...tanpaAlasan} = cuti();
    await assertFails(as("kantor").doc("leave_requests/lr4").set(tanpaAlasan));
  });

  test("BB-23 pegawai mengajukan izin lengkap (status pending)", async () => {
    await assertSucceeds(as("lapangan").doc("leave_requests/lr5").set(izin()));
  });

  test("BB-24 [TEMUAN] pengajuan izin dengan alasan kosong ditolak server", async () => {
    await assertFails(as("lapangan").doc("leave_requests/lr6").set({...izin(), reason: ""}));
  });

  test("RULE-22 pegawai tidak dapat mengajukan atas nama pegawai lain, langsung berstatus approved, atau dengan jenis tak dikenal", async () => {
    await assertFails(as("lain").doc("leave_requests/lr7").set(cuti("kantor")));
    await assertFails(as("kantor").doc("leave_requests/lr8").set({...cuti(), status: "approved"}));
    await assertFails(as("kantor").doc("leave_requests/lr9").set({...cuti(), kind: "sakit"}));
  });

  test("BB-19 pemilik dan admin peran requests dapat membaca pengajuan; pegawai lain tidak", async () => {
    await assertSucceeds(as("kantor").doc("leave_requests/lr1").get());
    await assertSucceeds(as("adminCuti").doc("leave_requests/lr1").get());
    await assertFails(as("lain").doc("leave_requests/lr1").get());
    await assertFails(as(null).doc("leave_requests/lr1").get());
  });

  test("BB-56 admin peran requests menyetujui pengajuan (nama pemutus tercatat)", async () => {
    await assertSucceeds(as("adminCuti").doc("leave_requests/lr1").update({
      status: "approved", decisionAt: now(), decisionBy: "adminCuti", decisionByEmail: "cuti@cvm.test", decisionByName: "Admin Cuti",
    }));
  });

  test("BB-57 admin peran requests menolak pengajuan", async () => {
    await assertSucceeds(as("adminCuti").doc("leave_requests/lr1").update({status: "rejected", decisionAt: now(), decisionBy: "adminCuti"}));
  });

  test("RULE-23 pemilik tidak dapat menyetujui sendiri atau menghapus pengajuannya; admin peran lain (attendance) tidak dapat memutus", async () => {
    await assertFails(as("kantor").doc("leave_requests/lr1").update({status: "approved"}));
    await assertFails(as("kantor").doc("leave_requests/lr1").delete());
    await assertFails(as("adminAbsen").doc("leave_requests/lr1").update({status: "approved"}));
  });
});

// ---------------------------------------------------------------- material_requests
describe("material_requests (order bahan)", () => {
  const items = [
    {name: "Semen 50kg", qty: 40, unit: "sak", status: "pending"},
    {name: "Besi beton 10mm", qty: 100, unit: "batang", status: "pending"},
  ];
  const mr = (over = {}) => ({
    requesterUid: "lapangan", requesterName: "Budi Lapangan", companyName: "PT Cipta Vera Mandiri", projectName: "Proyek Jembatan A",
    requestDate: "2026-11-24", items, status: "pending", createdAt: ts("2026-11-24T09:00:00+08:00"), updatedAt: ts("2026-11-24T09:00:00+08:00"),
    approverName: null, approvedBy: null, approvedByUid: null, approvedAt: null,
    receivedBy: null, receivedByUid: null, receivedAt: null, ...over,
  });
  const approved = () => mr({status: "approved", approverName: "Sari", approvedBy: "Sari Logistik", approvedByUid: "adminMaterial", approvedAt: ts("2026-11-25T10:00:00+08:00")});
  const deliver = () => ({
    status: "delivered", receivedBy: "Budi Lapangan", receivedByUid: "lapangan",
    receivedAt: ts("2026-11-26T08:00:00+08:00"), updatedAt: ts("2026-11-26T08:00:00+08:00"),
  });
  beforeEach(baseSeed(async (db) => {
    await db.doc("material_requests/mr_pending").set(mr());
    await db.doc("material_requests/mr_approved").set(approved());
  }));

  test("BB-36 Pegawai Lapangan membuat permintaan material (status pending)", async () => {
    await assertSucceeds(as("lapangan").doc("material_requests/mr_baru").set(mr()));
  });

  test("RULE-24 permintaan material tidak dapat dibuat atas nama pegawai lain atau tanpa login", async () => {
    await assertFails(as("lain").doc("material_requests/mr_x").set(mr()));
    await assertFails(as(null).doc("material_requests/mr_y").set(mr()));
  });

  test("BB-39 [TEMUAN] pegawai divisi kantor (Finance) TIDAK boleh membuat permintaan material (pembatasan di server)", async () => {
    // Pembatasan divisi hanya ada di UI (menu_grid_view_model); aturan Firestore tidak membedakan divisi.
    await assertFails(as("kantor").doc("material_requests/mr_kantor").set(mr({requesterUid: "kantor", requesterName: "Rina Finance"})));
  });

  test("BB-40 pemohon membaca permintaan miliknya", async () => {
    await assertSucceeds(as("lapangan").doc("material_requests/mr_pending").get());
  });

  test("RULE-25 pegawai lain tidak dapat membaca (get) permintaan material milik orang lain", async () => {
    await assertFails(as("kantor").doc("material_requests/mr_pending").get());
  });

  test("RULE-26 [TEMUAN] pegawai biasa TIDAK boleh me-list seluruh permintaan material milik orang lain", async () => {
    await assertFails(as("kantor").collection("material_requests").get());
  });

  test("BB-42 pemohon menandai barang diterima dari status approved (delivered + penerima + waktu)", async () => {
    await assertSucceeds(as("lapangan").doc("material_requests/mr_approved").update(deliver()));
  });

  test("BB-43 pemohon tidak dapat menandai diterima saat status masih pending", async () => {
    await assertFails(as("lapangan").doc("material_requests/mr_pending").update(deliver()));
  });

  test("RULE-27 pegawai lain tidak dapat menandai diterima pada permintaan orang lain", async () => {
    await assertFails(as("kantor").doc("material_requests/mr_approved").update(deliver()));
  });

  test("RULE-28 pemohon tidak dapat menyetujui permintaannya sendiri atau mengubah item", async () => {
    await assertFails(as("lapangan").doc("material_requests/mr_pending").update({status: "approved", approvedBy: "Budi", updatedAt: now()}));
    await assertFails(as("lapangan").doc("material_requests/mr_approved").update({...deliver(), items: []}));
  });

  test("BB-63 admin peran material menyetujui sebagian item (status tetap pending)", async () => {
    await assertSucceeds(as("adminMaterial").doc("material_requests/mr_pending").update({
      items: [{...items[0], status: "approved"}, items[1]], approverName: "Sari Logistik", updatedAt: now(),
    }));
  });

  test("BB-64 admin peran material menyetujui seluruh item (status approved, penyetuju tercatat)", async () => {
    await assertSucceeds(as("adminMaterial").doc("material_requests/mr_pending").update({
      status: "approved", approvedBy: "Sari Logistik", approvedByUid: "adminMaterial", approvedAt: now(), updatedAt: now(),
    }));
  });

  test("RULE-29 admin peran lain (documents) tidak dapat menyetujui permintaan material", async () => {
    await assertFails(as("adminDok").doc("material_requests/mr_pending").update({status: "approved"}));
  });

  test("RULE-30 hanya peran material yang dapat menghapus permintaan; pemohon tidak", async () => {
    await assertFails(as("lapangan").doc("material_requests/mr_pending").delete());
    await assertSucceeds(as("adminMaterial").doc("material_requests/mr_pending").delete());
  });
});

// ---------------------------------------------------------------- employee_documents
describe("employee_documents (pemberkasan)", () => {
  const dok = (uid = "kantor", createdBy = uid) => ({
    uid, title: "Kontrak Kerja 2026", storagePath: `employee_documents/${uid}/kontrak.pdf`,
    downloadUrl: "https://example.test/kontrak.pdf", divisions: ["all"], createdBy, originalFileName: "kontrak.pdf",
    notes: "Asli ditandatangani", expiresAt: ts("2027-06-30T00:00:00+08:00"), reminderIntervalDays: 30,
    createdAt: ts("2026-11-20T09:00:00+08:00"), updatedAt: ts("2026-11-20T09:00:00+08:00"),
  });
  beforeEach(baseSeed(async (db) => { await db.doc("employee_documents/d1").set(dok()); }));

  test("BB-44 pegawai mengunggah dokumen miliknya sendiri (dengan kedaluwarsa dan pengingat)", async () => {
    await assertSucceeds(as("lapangan").doc("employee_documents/d2").set(dok("lapangan")));
  });

  test("BB-60 admin peran documents mengunggah dokumen untuk pegawai", async () => {
    await assertSucceeds(as("adminDok").doc("employee_documents/d3").set(dok("kantor", "adminDok")));
  });

  test("RULE-31 pegawai tanpa peran documents tidak dapat membuat dokumen atas nama pegawai lain", async () => {
    await assertFails(as("lain").doc("employee_documents/d4").set(dok("kantor", "lain")));
  });

  test("RULE-32 dokumen dengan field tidak dikenal atau tanpa title ditolak", async () => {
    await assertFails(as("kantor").doc("employee_documents/d5").set({...dok(), sharedPublicly: true}));
    await assertFails(as("kantor").doc("employee_documents/d6").set({...dok(), title: ""}));
  });

  test("BB-45 pemilik dan admin peran documents dapat membaca dokumen; pegawai lain dan anonim tidak", async () => {
    await assertSucceeds(as("kantor").doc("employee_documents/d1").get());
    await assertSucceeds(as("adminDok").doc("employee_documents/d1").get());
    await assertFails(as("lain").doc("employee_documents/d1").get());
    await assertFails(as(null).doc("employee_documents/d1").get());
  });

  test("BB-44 pemilik memperbarui catatan dokumennya", async () => {
    await assertSucceeds(as("kantor").doc("employee_documents/d1").update({notes: "Diperbarui", updatedAt: now()}));
  });

  test("RULE-33 pemilik tidak dapat memindahkan kepemilikan dokumen ke pegawai lain", async () => {
    await assertFails(as("kantor").doc("employee_documents/d1").update({uid: "lain", updatedAt: now()}));
  });

  test("BB-46 pemilik menghapus dokumen miliknya", async () => {
    await assertSucceeds(as("kantor").doc("employee_documents/d1").delete());
  });

  test("BB-62 admin peran documents menghapus dokumen pegawai", async () => {
    await assertSucceeds(as("adminDok").doc("employee_documents/d1").delete());
  });

  test("RULE-34 pegawai lain tidak dapat menghapus atau mengubah dokumen orang lain", async () => {
    await assertFails(as("lain").doc("employee_documents/d1").delete());
    await assertFails(as("lain").doc("employee_documents/d1").update({notes: "x", updatedAt: now()}));
  });
});

// ---------------------------------------------------------------- calendar_events
describe("calendar_events (kalender)", () => {
  const ev = (createdBy) => ({
    title: "Rapat Divisi Finance", date: ts("2026-12-05T00:00:00+08:00"), category: "rapat", description: "Evaluasi akhir tahun",
    location: "Kantor Pusat", time: "09:00", createdBy, divisions: ["finance"],
    createdAt: ts("2026-11-26T10:00:00+08:00"), updatedAt: ts("2026-11-26T10:00:00+08:00"),
  });
  beforeEach(baseSeed(async (db) => { await db.doc("calendar_events/e1").set(ev("adminKalender")); }));

  test("BB-25 pegawai login dapat membaca acara kalender; anonim tidak", async () => {
    await assertSucceeds(as("kantor").doc("calendar_events/e1").get());
    await assertFails(as(null).doc("calendar_events/e1").get());
  });

  test("BB-58 admin peran calendar membuat acara untuk divisi sasaran", async () => {
    await assertSucceeds(as("adminKalender").doc("calendar_events/e2").set(ev("adminKalender")));
  });

  test("BB-26 pegawai menambah acara pribadi (createdBy = dirinya)", async () => {
    await assertSucceeds(as("kantor").doc("calendar_events/e3").set(ev("kantor")));
  });

  test("RULE-35 pegawai tidak dapat membuat acara atas nama orang lain atau tanpa judul", async () => {
    await assertFails(as("kantor").doc("calendar_events/e4").set(ev("adminKalender")));
    await assertFails(as("kantor").doc("calendar_events/e5").set({...ev("kantor"), title: ""}));
  });

  test("BB-59 admin peran calendar mengubah judul lalu menghapus acara", async () => {
    await assertSucceeds(as("adminKalender").doc("calendar_events/e1").update({title: "Rapat Divisi (revisi)", updatedAt: now()}));
    await assertSucceeds(as("adminKalender").doc("calendar_events/e1").delete());
  });

  test("RULE-36 pegawai tanpa peran calendar tidak dapat mengubah/menghapus acara", async () => {
    await assertFails(as("kantor").doc("calendar_events/e1").update({title: "Diubah"}));
    await assertFails(as("kantor").doc("calendar_events/e1").delete());
    await assertFails(as("adminCuti").doc("calendar_events/e1").delete());
  });
});

// ---------------------------------------------------------------- publik, default deny
describe("Company profile (publik) dan aturan default", () => {
  beforeEach(baseSeed(async (db) => {
    await db.doc("company_profiles/main").set({name: "PT Cipta Vera Mandiri"});
    await db.doc("company_landing_content/hero").set({title: "Selamat datang"});
  }));

  test("RULE-37 konten company profile dapat dibaca publik tanpa login", async () => {
    await assertSucceeds(as(null).doc("company_profiles/main").get());
    await assertSucceeds(as(null).doc("company_landing_content/hero").get());
  });

  test("RULE-38 konten company profile hanya dapat diubah admin/superAdmin", async () => {
    await assertFails(as("kantor").doc("company_profiles/main").update({name: "X"}));
    await assertFails(as(null).doc("company_landing_content/hero").update({title: "X"}));
    await assertSucceeds(as("superAdmin").doc("company_profiles/main").update({name: "PT CVM (diperbarui)"}));
  });

  test("RULE-39 koleksi yang tidak terdaftar ditolak untuk semua pengguna, termasuk superAdmin", async () => {
    await assertFails(as("superAdmin").doc("koleksi_liar/x").set({a: 1}));
    await assertFails(as("kantor").doc("koleksi_liar/x").get());
    await assertFails(as(null).doc("holidays/2026-12-25").get());
  });
});
