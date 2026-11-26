#!/usr/bin/env bash
# Dijalankan di dalam android-emulator-runner (emulator Android sudah menyala).
# Emulator Firebase (auth 9099, firestore 8080, storage 9199) dijalankan oleh `firebase emulators:exec`
# memakai integration_test/firebase.integration.json; dari emulator Android diakses lewat 10.0.2.2.
# Kegagalan uji tidak menggagalkan langkah; hasil tetap diunggah.
set -uo pipefail
mkdir -p tools_ci/out
firebase emulators:exec --project demo-cvm \
  --config integration_test/firebase.integration.json \
  --only auth,firestore,storage \
  "bash tools_ci/flutter_integration_dalam_emulator.sh" \
  > tools_ci/out/ui_firebase_emulator.log 2>&1
echo "firebase emulators:exec selesai dengan kode $?"
exit 0
