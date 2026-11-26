#!/usr/bin/env bash
# Membuat .env berisi nilai PALSU untuk CI (menimpa .env di workspace CI saja).
# Aset .env wajib ada karena terdaftar di pubspec.yaml; nilai aslinya tidak dipakai.
set -euo pipefail
PROJECT="${1:-demo-cvm}"
cat > .env <<EOF
WEB_API_KEY=dummy-api-key
WEB_APP_ID=1:000000000000:web:0000000000000000
WEB_MESSAGING_SENDER_ID=000000000000
WEB_PROJECT_ID=${PROJECT}
WEB_AUTH_DOMAIN=${PROJECT}.firebaseapp.com
WEB_STORAGE_BUCKET=${PROJECT}.appspot.com
WEB_MEASUREMENT_ID=G-0000000000
ANDROID_API_KEY=dummy-api-key
ANDROID_APP_ID=1:000000000000:android:0000000000000000
ANDROID_MESSAGING_SENDER_ID=000000000000
ANDROID_PROJECT_ID=${PROJECT}
ANDROID_STORAGE_BUCKET=${PROJECT}.appspot.com
IOS_API_KEY=dummy-api-key
IOS_APP_ID=1:000000000000:ios:0000000000000000
IOS_MESSAGING_SENDER_ID=000000000000
IOS_PROJECT_ID=${PROJECT}
IOS_STORAGE_BUCKET=${PROJECT}.appspot.com
IOS_BUNDLE_ID=com.example.dummy
EOF
echo ".env dummy dibuat (tanpa nilai asli)."
