# test-pkl

Salinan proyek **Sistem Informasi Manajemen Operasional PT Cipta Vera Mandiri** (Flutter + Firebase)
khusus untuk build APK dan pengujian otomatis lewat GitHub Actions. Repository asal tidak diubah.

## Workflow
| Workflow | Fungsi | Hasil (tab Actions → run → Artifacts) |
|---|---|---|
| **Build APK** | `flutter build apk --release` | `apk-release` |
| **Pengujian Otomatis** | White Box (`flutter test`), Black Box server (aturan Firestore/Storage + Cloud Functions di emulator), Black Box UI (integration_test di emulator Android), rekap | `rekap` (rekap.json + Hasil_Pengujian_terisi.xlsx) |

## Rahasia (GitHub Secrets)
Berkas konfigurasi asli **tidak** ada di repository ini. Isi di *Settings → Secrets and variables → Actions*:

| Nama secret | Isi (base64 dari berkas) |
|---|---|
| `ENV_FILE_B64` | `.env` |
| `GOOGLE_SERVICES_JSON_B64` | `android/app/google-services.json` |
| `FIREBASE_OPTIONS_DART_B64` | `lib/firebase_options.dart` |

Membuat nilai base64: Linux/macOS `base64 -w0 .env` (macOS: `base64 -i .env`);
Windows PowerShell `[Convert]::ToBase64String([IO.File]::ReadAllBytes(".env"))`.

Tanpa secret, build tetap berjalan memakai konfigurasi palsu (`demo-cvm`): APK terpasang tetapi tidak terhubung ke Firebase asli.
Pengujian selalu memakai konfigurasi palsu dan Firebase Emulator, tidak menyentuh data produksi.

Rincian pengujian: `tools_ci/README_CI.md`, `integration_test/README_integration.md`.
