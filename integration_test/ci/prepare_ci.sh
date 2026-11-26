#!/usr/bin/env bash
# Persiapan build integration test di CI (TIDAK mengubah file di repo yang
# di-commit; dijalankan di working copy runner sebelum `flutter test`).
#
#   1. android/app/google-services.json  -> versi demo (project "demo-cvm")
#      supaya Firebase default app di APK uji BUKAN project produksi.
#   2. android/app/src/debug/AndroidManifest.xml -> usesCleartextTraffic=true
#      supaya SDK Firebase boleh memakai HTTP (bukan HTTPS) ke emulator di
#      10.0.2.2 (Android 9+ memblokir cleartext secara default).
#   3. .env -> dibuat kosong bila tidak ada (pubspec mendaftarkannya sebagai
#      asset; tes tidak membaca nilainya).
#
# Pemakaian (dari root repo):  bash integration_test/ci/prepare_ci.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

cp integration_test/ci/google-services.demo-cvm.json android/app/google-services.json
echo "[prepare_ci] google-services.json diganti dengan versi demo-cvm"

MANIFEST="android/app/src/debug/AndroidManifest.xml"
if ! grep -q 'usesCleartextTraffic' "$MANIFEST"; then
  python3 - "$MANIFEST" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
s = s.replace("</manifest>",
              '    <application android:usesCleartextTraffic="true"/>\n</manifest>')
open(p, "w", encoding="utf-8").write(s)
PY
  echo "[prepare_ci] usesCleartextTraffic=true ditambahkan ke manifest debug"
fi

if [ ! -f .env ]; then
  : > .env
  echo "[prepare_ci] .env kosong dibuat"
fi
