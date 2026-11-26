import {resetDb, state, functions, wrap, setWita, endpoint, USERS} from "./helpers";

beforeAll(() => jest.useFakeTimers());
afterAll(() => jest.useRealTimers());
beforeEach(() => resetDb({users: USERS}));

describe("Definisi jadwal (cron + zona waktu)", () => {
  const cases: Array<[string, string, string]> = [
    ["scheduleDailyAttendanceWindow", "0 6 * * *", "BB-52"],
    ["broadcastAttendanceOpeningSoon", "0 8 * * *", "BB-35"],
    ["broadcastAttendanceOpen", "30 8 * * *", "BB-35"],
    ["broadcastAttendanceClosingSoon", "20 9 * * *", "BB-35"],
  ];
  test.each(cases)("%s berjalan pada '%s' zona Asia/Makassar (WITA) [%s]", (name, cron) => {
    const ep = endpoint((functions as any)[name]);
    expect(ep.scheduleTrigger.schedule).toBe(cron);
    expect(ep.scheduleTrigger.timeZone).toBe("Asia/Makassar");
  });
});

describe("BB-52 scheduleDailyAttendanceWindow (06.00 WITA)", () => {
  const run = () => wrap(functions.scheduleDailyAttendanceWindow)({});

  test("BB-52 Senin: membuat attendance_windows/{yyyy-MM-dd} 08:30-09:30 WITA, toleransi 30 menit", async () => {
    setWita("2026-11-23T06:00:00"); // Senin
    await run();
    expect(state.writes).toHaveLength(1);
    const w = state.writes[0];
    expect(w.collection).toBe("attendance_windows");
    expect(w.id).toBe("2026-11-23");
    expect(w.opts).toEqual({merge: true});
    expect(w.data.openAt.__timestamp.getTime()).toBe(new Date("2026-11-23T08:30:00+08:00").getTime());
    expect(w.data.closeAt.__timestamp.getTime()).toBe(new Date("2026-11-23T09:30:00+08:00").getTime());
    expect(w.data.lateGraceMinutes).toBe(30);
    expect(w.data.updatedAt).toBe("SERVER_TIMESTAMP");
    expect(Object.keys(w.data).sort()).toEqual(["closeAt", "lateGraceMinutes", "openAt", "updatedAt"]);
  });

  test("BB-52 Sabtu: tetap membuat jadwal (hanya Minggu yang dilewati)", async () => {
    setWita("2026-11-21T06:00:00"); // Sabtu
    await run();
    expect(state.writes.map((w: any) => w.id)).toEqual(["2026-11-21"]);
  });

  test("BB-52 Minggu: tidak membuat jadwal", async () => {
    setWita("2026-11-22T06:00:00"); // Minggu
    await run();
    expect(state.writes).toHaveLength(0);
  });

  test("BB-52 Tanggal ada di koleksi holidays: jadwal dilewati", async () => {
    resetDb({users: USERS, holidays: {"2026-11-25": {isHoliday: true, name: "Cuti Bersama (uji)"}}});
    setWita("2026-11-25T06:00:00");
    await run();
    expect(state.writes).toHaveLength(0);
    expect(state.reads).toContain("holidays/2026-11-25");
  });

  test("BB-52 Zona waktu: pukul 06.00 WITA = 22.00 UTC hari sebelumnya tetap memakai tanggal WITA", async () => {
    jest.setSystemTime(new Date("2026-11-23T22:00:00Z")); // = Selasa 24 Nov 06:00 WITA
    await run();
    expect(state.writes[0].id).toBe("2026-11-24");
  });

  test("RULE-F01 holidays/{tanggal} berisi isHoliday:false (tanpa name) tidak dianggap libur", async () => {
    resetDb({holidays: {"2026-11-24": {isHoliday: false}}});
    setWita("2026-11-24T06:00:00");
    await run();
    expect(state.writes).toHaveLength(1);
  });

  test("RULE-F02 [TEMUAN] isHoliday:false DENGAN name semestinya bukan libur (kode: (isHoliday !== false || name))", async () => {
    resetDb({holidays: {"2026-11-24": {isHoliday: false, name: "Bukan libur"}}});
    setWita("2026-11-24T06:00:00");
    await run();
    expect(state.writes).toHaveLength(1); // harapan aman/benar; kode saat ini melewati jadwal -> diperkirakan GAGAL
  });
});

describe("BB-35 Notifikasi terjadwal 08.00 / 08.30 / 09.20 (FCM broadcast)", () => {
  const specs: Array<[string, string, string, string]> = [
    ["broadcastAttendanceOpeningSoon", "08:00:00", "Absensi dibuka 30 menit lagi", "08:30 WITA"],
    ["broadcastAttendanceOpen", "08:30:00", "Absensi sudah dibuka", "09:30 WITA"],
    ["broadcastAttendanceClosingSoon", "09:20:00", "Absensi ditutup 10 menit lagi", "09:30 WITA"],
  ];

  describe.each(specs)("%s", (name, jam, title, bodyHint) => {
    const run = () => wrap((functions as any)[name])({});

    test(`BB-35 hari kerja ${jam} WITA: kirim ke semua token unik (string/array/map), judul "${title}"`, async () => {
      setWita(`2026-11-23T${jam}`);
      await run();
      expect(state.sent).toHaveLength(1);
      const msg = state.sent[0];
      expect(msg.notification.title).toBe(title);
      expect(msg.notification.body).toContain(bodyHint);
      expect(msg.data.type).toBe("attendance");
      expect([...msg.tokens].sort()).toEqual(["tok-adm", "tok-budi", "tok-rina-1", "tok-rina-2", "tok-sari"]);
    });

    test("BB-35 Minggu: tidak mengirim", async () => {
      setWita(`2026-11-22T${jam}`);
      await run();
      expect(state.sent).toHaveLength(0);
    });

    test("BB-35 Hari libur (holidays): tidak mengirim", async () => {
      resetDb({users: USERS, holidays: {"2026-11-23": {isHoliday: true}}});
      setWita(`2026-11-23T${jam}`);
      await run();
      expect(state.sent).toHaveLength(0);
    });

    test("BB-35 Tanpa token terdaftar: tidak memanggil FCM", async () => {
      resetDb({users: {a: USERS.u_tanpa_token}});
      setWita(`2026-11-23T${jam}`);
      await run();
      expect(state.sent).toHaveLength(0);
    });

    test("BB-35 Token ganda antar pengguna hanya dikirim sekali; >450 token dipecah per batch 450", async () => {
      const many: Record<string, unknown> = {};
      for (let i = 0; i < 1000; i++) many[`u${i}`] = {fcmTokens: [`t${i}`, "dup"]};
      resetDb({users: many});
      setWita(`2026-11-23T${jam}`);
      await run();
      const all = state.sent.flatMap((m: any) => m.tokens);
      expect(new Set(all).size).toBe(1001);
      expect(all).toHaveLength(1001);
      expect(state.sent.map((m: any) => m.tokens.length)).toEqual([450, 450, 101]);
    });
  });

  test("BB-35 Sabtu 08.30 WITA tetap mengirim (Senin-Sabtu)", async () => {
    setWita("2026-11-21T08:30:00");
    await wrap(functions.broadcastAttendanceOpen)({});
    expect(state.sent).toHaveLength(1);
  });
});
