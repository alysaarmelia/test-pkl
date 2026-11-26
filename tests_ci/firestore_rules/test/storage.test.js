/**
 * Black Box test aturan Firebase Storage (storage.rules).
 * storage.rules saat ini "allow read, write: if true" (default pengembangan). Harapan AMAN ditulis apa adanya;
 * pengujian bertanda [TEMUAN] diperkirakan GAGAL dan kegagalannya adalah temuan nyata.
 */
const {createEnv, assertSucceeds, assertFails} = require("./helpers");

let env;
const bytes = () => new Uint8Array([37, 80, 68, 70, 45]); // "%PDF-"
const DOC_PATH = "employee_documents/kantor/kontrak.pdf";
const FOTO_PATH = "profile_pictures/kantor.jpg";

beforeAll(async () => { env = await createEnv(); });
afterAll(async () => { await env.cleanup(); });
beforeEach(async () => {
  if (env.clearStorage) await env.clearStorage();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.storage().ref(DOC_PATH).put(bytes(), {contentType: "application/pdf"});
    await ctx.storage().ref(FOTO_PATH).put(bytes(), {contentType: "image/jpeg"});
  });
});

const storageAs = (uid) =>
  (uid ? env.authenticatedContext(uid, {email: `${uid}@cvm.test`}) : env.unauthenticatedContext()).storage();
const put = (st, path) => Promise.resolve(st.ref(path).put(bytes(), {contentType: "application/pdf"}));
const meta = (st, path) => Promise.resolve(st.ref(path).getMetadata());

describe("Storage rules", () => {
  test("BB-44 pegawai login mengunggah berkas dokumen miliknya", async () => {
    await assertSucceeds(put(storageAs("kantor"), "employee_documents/kantor/ijazah.pdf"));
  });

  test("BB-30 pegawai login mengunggah/mengganti foto profil", async () => {
    await assertSucceeds(put(storageAs("kantor"), "profile_pictures/kantor.jpg"));
  });

  test("BB-41 pegawai login dapat membuka/mengunduh berkas miliknya (PDF/dokumen)", async () => {
    await assertSucceeds(meta(storageAs("kantor"), DOC_PATH));
  });

  test("RULE-S01 [TEMUAN] pengguna tanpa login TIDAK boleh membaca berkas dokumen pegawai", async () => {
    await assertFails(meta(storageAs(null), DOC_PATH));
  });

  test("RULE-S02 [TEMUAN] pengguna tanpa login TIDAK boleh mengunggah berkas", async () => {
    await assertFails(put(storageAs(null), "employee_documents/penyusup/malware.pdf"));
  });

  test("RULE-S03 [TEMUAN] pegawai TIDAK boleh menimpa berkas dokumen milik pegawai lain", async () => {
    await assertFails(put(storageAs("lain"), DOC_PATH));
  });

  test("RULE-S04 [TEMUAN] pegawai TIDAK boleh membaca berkas dokumen pegawai lain", async () => {
    await assertFails(meta(storageAs("lain"), DOC_PATH));
  });
});
