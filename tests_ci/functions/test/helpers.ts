/* eslint-disable @typescript-eslint/no-var-requires */
const adminMock = require("./adminMock.js");
const fft = require("firebase-functions-test")(); // mode offline: tanpa project/credential
// functions/src/index.ts dimuat apa adanya (tidak diubah); firebase-admin sudah di-mock lewat moduleNameMapper.
const fns = require("../../../functions/src/index");

export const state = adminMock.__state;
export const resetDb = (data: Record<string, Record<string, unknown>> = {}) =>
  adminMock.__reset(data);
export const functions = fns;
export const wrap = (fn: unknown) => fft.wrap(fn);

/** Waktu sistem = tanggal/jam WITA (UTC+8) yang diberikan, mis. "2026-11-23T06:00:00". */
export const setWita = (isoLocal: string) =>
  jest.setSystemTime(new Date(`${isoLocal}+08:00`));

export const endpoint = (fn: any) => fn.__endpoint;

export const snapshotOf = (data: unknown) => ({data: () => data});

export const sentTokens = (): string[] =>
  state.sent.flatMap((m: any) => m.tokens);

// Seed pengguna realistis (divisi disimpan di users/{uid}.role)
export const USERS = {
  u_pegawai_kantor: {
    name: "Rina Finance",
    email: "rina@cvm.test",
    role: "Finance",
    fcmTokens: ["tok-rina-1", "tok-rina-2"],
  },
  u_pegawai_lapangan: {
    name: "Budi Lapangan",
    email: "budi@cvm.test",
    role: "Project Officer",
    fcmToken: "tok-budi",
  },
  u_logistik: {
    name: "Sari Logistik",
    email: "sari@cvm.test",
    role: "Purchasing and Logistik",
    fcmTokens: {"tok-sari": true},
  },
  u_admin_dok: {
    name: "Admin Administrasi",
    email: "adm@cvm.test",
    role: "Administrations",
    fcmTokens: ["tok-adm"],
  },
  u_tanpa_token: {name: "Tanpa Token", email: "x@cvm.test", role: "Finance"},
};
