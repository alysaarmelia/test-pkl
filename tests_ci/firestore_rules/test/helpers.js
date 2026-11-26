const fs = require("fs");
const path = require("path");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const firebase = require("firebase/compat/app");
require("firebase/compat/firestore");
const Timestamp = firebase.firestore.Timestamp; // context.firestore() bertipe compat -> pakai Timestamp compat

const PROJECT_ID = "demo-cvm"; // project palsu: tidak menyentuh Firebase sungguhan
const ROOT = path.resolve(__dirname, "..", "..", "..");

/** Pengguna uji. Divisi disimpan di users/{uid}.role; peran admin di users/{uid}.roles (map). */
const USERS = {
  pegawai:   {name: "Dewi Pegawai",    email: "dewi@cvm.test",   role: "Administrations", profileCompleted: true},
  lapangan:  {name: "Budi Lapangan",   email: "budi@cvm.test",   role: "Project Officer", profileCompleted: true},
  kantor:    {name: "Rina Finance",    email: "rina@cvm.test",   role: "Finance",         profileCompleted: true},
  lain:      {name: "Joko Lain",       email: "joko@cvm.test",   role: "Heavy Equipment", profileCompleted: true},
  adminAbsen:   {name: "Admin Absensi",  email: "abs@cvm.test",  role: "Administrations", roles: {attendance: true}},
  adminCuti:    {name: "Admin Cuti",     email: "cuti@cvm.test", role: "Administrations", roles: {requests: true}},
  adminKalender:{name: "Admin Kalender", email: "kal@cvm.test",  role: "Administrations", roles: {calendar: true}},
  adminDok:     {name: "Admin Dokumen",  email: "dok@cvm.test",  role: "Finance",         roles: {documents: true}},
  adminMaterial:{name: "Admin Logistik", email: "mat@cvm.test",  role: "Purchasing and Logistik", roles: {material: true}},
  adminUsers:   {name: "Admin Pengguna", email: "usr@cvm.test",  role: "Administrations", roles: {users: true}},
  admin:        {name: "Admin Umum",     email: "adm@cvm.test",  role: "Administrations", roles: {admin: true}},
  superAdmin:   {name: "Super Admin",    email: "sa@cvm.test",   role: "Head Officer",    roles: {superAdmin: true}},
};

async function createEnv() {
  return initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {rules: fs.readFileSync(path.join(ROOT, "firestore.rules"), "utf8")},
    storage: {rules: fs.readFileSync(path.join(ROOT, "storage.rules"), "utf8")},
  });
}

/** Mengosongkan data lalu mengisi seed dengan aturan dinonaktifkan. extra(db) boleh menambah data. */
async function seed(env, extra) {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [uid, data] of Object.entries(USERS)) {
      await db.doc(`users/${uid}`).set(data);
    }
    if (extra) await extra(db);
  });
}

/** Firestore untuk pengguna tertentu (uid = kunci USERS) atau tanpa login (null). */
const dbAs = (env, uid) =>
  (uid ? env.authenticatedContext(uid, {email: USERS[uid].email, email_verified: true}) : env.unauthenticatedContext()).firestore();

const ts = (iso) => Timestamp.fromDate(new Date(iso));
const now = () => Timestamp.now();

module.exports = {PROJECT_ID, USERS, createEnv, seed, dbAs, ts, now, assertSucceeds, assertFails};
