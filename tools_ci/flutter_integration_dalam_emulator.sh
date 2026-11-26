#!/usr/bin/env bash
# Dipanggil oleh `firebase emulators:exec` (lihat jalankan_integration.sh).
set -uo pipefail
flutter test integration_test --machine \
  > tools_ci/out/ui_black_box.jsonl 2> tools_ci/out/ui_black_box.stderr.txt
echo $? > tools_ci/out/ui_black_box.exitcode
exit 0
