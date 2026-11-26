import {resetDb, state, functions, snapshotOf, sentTokens, USERS} from "./helpers";

// Pemicu Firestore v2 dipanggil lewat handler mentah (fn.run). firebase-functions-test.wrap() untuk
// pemicu Firestore memerlukan kelas DocumentSnapshot asli dari firebase-admin yang di sini di-mock.
const wrap = (fn: any) => (event: any) => fn.run(event);

beforeEach(() => resetDb({users: USERS}));

const docEvent = (data: any, documentId = "doc1") => ({
  data: snapshotOf(data),
  params: {documentId},
});

describe("onDocumentCreatedNotification (employee_documents)", () => {
  const run = (data: any) => wrap(functions.onDocumentCreatedNotification)(docEvent(data));
  const base = {
    uid: "u_pegawai_kantor",
    title: "Kontrak Kerja",
    originalFileName: "kontrak.pdf",
    divisions: ["all"],
  };

  test("BB-44 pemilik mengunggah sendiri (createdBy == uid): tidak ada notifikasi", async () => {
    await run({...base, createdBy: "u_pegawai_kantor"});
    expect(state.sent).toHaveLength(0);
    expect(state.reads).not.toContain("users/u_pegawai_kantor"); // berhenti sebelum membaca pengguna
  });

  test("BB-60 admin mengunggah untuk pegawai (createdBy != uid): notifikasi ke token pemilik", async () => {
    await run({...base, createdBy: "u_admin_dok"});
    expect(state.sent).toHaveLength(1);
    const m = state.sent[0];
    expect([...m.tokens].sort()).toEqual(["tok-rina-1", "tok-rina-2"]);
    expect(m.notification.title).toBe("Dokumen baru ditambahkan");
    expect(m.notification.body).toBe('Admin menambahkan dokumen "Kontrak Kerja" (kontrak.pdf) ke akun Anda.');
    expect(m.data.type).toBe("document");
    expect(m.data.documentId).toBe("doc1");
  });

  test("BB-60 createdBy 'admin-dashboard' (cadangan UI admin) tetap dianggap dari admin", async () => {
    await run({...base, createdBy: "admin-dashboard"});
    expect(state.sent).toHaveLength(1);
  });

  test("BB-60 divisions tertentu: token pemilik + semua pengguna divisi sasaran, tidak termasuk divisi lain", async () => {
    await run({...base, createdBy: "u_admin_dok", divisions: ["finance", "purchasing_logistik"]});
    expect(state.sent).toHaveLength(1);
    expect([...state.sent[0].tokens].sort()).toEqual(["tok-rina-1", "tok-rina-2", "tok-sari"]);
    expect(state.sent[0].notification.body).toBe(
      'Admin menambahkan dokumen "Kontrak Kerja" untuk divisi Finance, Purchasing & Logistik.');
    expect(sentTokens()).not.toContain("tok-budi"); // Project Officer
    expect(sentTokens()).not.toContain("tok-adm");  // Administrations
  });

  test("BB-60 divisions 'all': hanya pemilik dokumen (tidak broadcast ke semua pegawai)", async () => {
    await run({...base, createdBy: "u_admin_dok", divisions: ["all"]});
    expect([...state.sent[0].tokens].sort()).toEqual(["tok-rina-1", "tok-rina-2"]);
  });

  test("BB-60 pemilik tanpa token dan tanpa divisi sasaran: tidak ada pengiriman", async () => {
    await run({...base, uid: "u_tanpa_token", createdBy: "u_admin_dok"});
    expect(state.sent).toHaveLength(0);
  });

  test("BB-60 token pemilik dicari lewat email bila dokumen pengguna tidak memilikinya", async () => {
    resetDb({users: {
      uid_baru: {email: "Rina@CVM.test", role: "Finance"},
      uid_lama: {email: "rina@cvm.test", fcmToken: "tok-lama"},
    }});
    await run({...base, uid: "uid_baru", createdBy: "u_admin_dok"});
    expect(sentTokens()).toEqual(["tok-lama"]);
  });

  test("RULE-F03 event tanpa data: fungsi selesai tanpa error dan tanpa kirim", async () => {
    await wrap(functions.onDocumentCreatedNotification)({data: undefined, params: {documentId: "x"}});
    expect(state.sent).toHaveLength(0);
  });

  test("RULE-F04 [TEMUAN] dokumen untuk divisi 'Heavy Equipment' (ada di daftar profil) semestinya sampai ke pengguna divisi itu", async () => {
    // 'Heavy Equipment' ada di Lengkapi Profil tetapi tidak dikenali normalizeDivision/DIVISION_LABELS,
    // sehingga divisions ["Heavy Equipment"] menjadi "all" dan token pengguna Heavy Equipment tidak disertakan.
    resetDb({users: {
      alat: {role: "Heavy Equipment", fcmToken: "tok-alat"},
      kantor: USERS.u_pegawai_kantor,
    }});
    await run({...base, uid: "kantor", createdBy: "adm", divisions: ["Heavy Equipment"]});
    expect(sentTokens()).toContain("tok-alat"); // diperkirakan GAGAL pada kode saat ini
  });
});

describe("onChatMessageCreated (notifikasi chat)", () => {
  const run = (data: any, chatId = "c1") =>
    wrap(functions.onChatMessageCreated)({data: snapshotOf(data), params: {chatId, messageId: "m1"}});

  const chat1to1 = {
    members: ["u_pegawai_kantor", "u_pegawai_lapangan"],
    memberInfo: {u_pegawai_kantor: {name: "Rina Finance"}, u_pegawai_lapangan: {name: "Budi Lapangan"}},
  };

  test("BB-28 pesan 1-1: terkirim ke token lawan bicara saja, judul = nama pengirim, isi = teks", async () => {
    resetDb({users: USERS, chats: {c1: chat1to1}});
    await run({senderId: "u_pegawai_kantor", text: "Halo Budi", type: "text"});
    expect(state.sent).toHaveLength(1);
    const m = state.sent[0];
    expect(m.tokens).toEqual(["tok-budi"]);
    expect(m.notification).toEqual({title: "Rina Finance", body: "Halo Budi"});
    expect(m.data.type).toBe("chat");
    expect(m.data.isGroup).toBe("false");
    expect(m.android.notification.channelId).toBe("direct_messages");
  });

  test("BB-29 pesan grup (>2 anggota): judul = nama grup, token semua anggota selain pengirim", async () => {
    resetDb({users: USERS, chats: {c1: {
      type: "group", groupName: "Tim Proyek A",
      members: ["u_pegawai_kantor", "u_pegawai_lapangan", "u_logistik"],
    }}});
    await run({senderId: "u_pegawai_kantor", text: "Rapat jam 9"});
    const m = state.sent[0];
    expect([...m.tokens].sort()).toEqual(["tok-budi", "tok-sari"]);
    expect(m.notification.title).toBe("Tim Proyek A");
    expect(m.data.isGroup).toBe("true");
    expect(m.android.notification.channelId).toBe("group_messages");
  });

  test("BB-28 pesan foto/file tanpa teks memakai isi bawaan", async () => {
    resetDb({users: USERS, chats: {c1: chat1to1}});
    await run({senderId: "u_pegawai_kantor", type: "image"});
    expect(state.sent[0].notification.body).toBe("Mengirim foto");
    resetDb({users: USERS, chats: {c1: chat1to1}});
    await run({senderId: "u_pegawai_kantor", type: "file", fileName: "spek.pdf"});
    expect(state.sent[0].notification.body).toBe("Mengirim file spek.pdf");
  });

  test("BB-28 pesan silent, tanpa senderId, chat tidak ada, atau tanpa token: tidak mengirim", async () => {
    resetDb({users: USERS, chats: {c1: chat1to1}});
    await run({senderId: "u_pegawai_kantor", text: "x", silent: true});
    await run({text: "tanpa pengirim"});
    await run({senderId: "u_pegawai_kantor", text: "x"}, "tidak-ada");
    resetDb({users: {a: USERS.u_tanpa_token, b: USERS.u_pegawai_kantor}, chats: {c1: {members: ["a", "b"]}}});
    await run({senderId: "b", text: "x"});
    expect(state.sent).toHaveLength(0);
  });
});

describe("onAdminAttendanceOpened (admin_signals)", () => {
  const run = (data: any) =>
    wrap(functions.onAdminAttendanceOpened)({data: snapshotOf(data), params: {signalId: "s1"}});

  test("BB-33 / BB-50 sinyal attendance_open: notifikasi 'Admin membuka absensi' ke semua token", async () => {
    await run({type: "attendance_open", adminUid: "u_admin_dok", adminEmail: "adm@cvm.test"});
    expect(state.sent).toHaveLength(1);
    const m = state.sent[0];
    expect(m.notification.title).toBe("Admin membuka absensi");
    expect(m.data).toMatchObject({type: "attendance", event: "open", adminUid: "u_admin_dok"});
    expect([...m.tokens].sort()).toEqual(["tok-adm", "tok-budi", "tok-rina-1", "tok-rina-2", "tok-sari"]);
  });

  test("BB-51 sinyal attendance_close: notifikasi 'Admin menutup absensi'", async () => {
    await run({type: "attendance_close"});
    expect(state.sent[0].notification.title).toBe("Admin menutup absensi");
    expect(state.sent[0].data.event).toBe("close");
  });

  test("RULE-F05 tipe sinyal lain diabaikan", async () => {
    await run({type: "something_else"});
    expect(state.sent).toHaveLength(0);
  });
});
