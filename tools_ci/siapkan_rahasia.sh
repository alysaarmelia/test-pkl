#!/usr/bin/env bash
# Menyiapkan 3 berkas rahasia di workspace CI (tidak pernah di-commit).
#   .env                              <- secret ENV_FILE_B64
#   android/app/google-services.json  <- secret GOOGLE_SERVICES_JSON_B64
#   lib/firebase_options.dart         <- secret FIREBASE_OPTIONS_DART_B64
# Bila secret kosong, dipakai pengganti PALSU (proyek demo-cvm) sehingga build
# tetap berhasil, tetapi aplikasi tidak terhubung ke Firebase asli.
# Pemakaian: bash tools_ci/siapkan_rahasia.sh [asli|dummy]
#   asli  (default) : pakai secret bila ada, selain itu fallback
#   dummy           : selalu pakai pengganti palsu (untuk pengujian)
set -euo pipefail
MODE="${1:-asli}"
cd "$(dirname "${BASH_SOURCE[0]}")/.."
STATUS=()

tulis() { # $1=nama secret  $2=tujuan
  local val="${!1:-}"
  if [ "$MODE" = "asli" ] && [ -n "$val" ]; then
    mkdir -p "$(dirname "$2")"
    printf '%s' "$val" | base64 -d > "$2"
    STATUS+=("$2: dari secret $1")
    return 0
  fi
  return 1
}

tulis ENV_FILE_B64 .env || { bash tools_ci/buat_env_dummy.sh demo-cvm >/dev/null; STATUS+=(".env: PALSU (demo-cvm)"); }
tulis GOOGLE_SERVICES_JSON_B64 android/app/google-services.json || { cp integration_test/ci/google-services.demo-cvm.json android/app/google-services.json; STATUS+=("google-services.json: PALSU (demo-cvm)"); }
tulis FIREBASE_OPTIONS_DART_B64 lib/firebase_options.dart || { cp tools_ci/firebase_options.template.dart lib/firebase_options.dart; STATUS+=("firebase_options.dart: templat tersanitasi"); }

for s in "${STATUS[@]}"; do echo "[rahasia] $s"; done
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  { echo "### Sumber konfigurasi Firebase"; for s in "${STATUS[@]}"; do echo "- $s"; done; } >> "$GITHUB_STEP_SUMMARY"
fi
