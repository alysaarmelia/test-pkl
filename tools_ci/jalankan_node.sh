#!/usr/bin/env bash
# Menjalankan satu folder uji Node di bawah tests_ci/ (dipanggil dari emulators:exec).
# Pemakaian: tools_ci/jalankan_node.sh <folder>   contoh: tests_ci/firestore_rules
# Selalu keluar dengan kode asli npm test; hasil JUnit diharapkan ke tests_ci/results/.
set -uo pipefail
DIR="$1"
if [ ! -f "$DIR/package.json" ]; then
  echo "::warning::$DIR/package.json tidak ada; folder dilewati."
  exit 0
fi
mkdir -p tests_ci/results
cd "$DIR"
npm test
