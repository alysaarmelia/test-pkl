#!/usr/bin/env bash
# Menambahkan dev_dependency `integration_test: sdk: flutter` ke pubspec.yaml DI WORKSPACE CI SAJA
# (tidak di-commit), lalu menjalankan flutter pub get. Aman dijalankan berulang.
set -euo pipefail
python3 - <<'PY'
import re
p = "pubspec.yaml"
s = open(p, encoding="utf-8").read()
if re.search(r"^\s+integration_test:\s*$", s, re.M):
    print("integration_test sudah ada di pubspec.yaml")
else:
    tambah = "dev_dependencies:\n  integration_test:\n    sdk: flutter\n"
    s, n = re.subn(r"^dev_dependencies:[ \t]*\r?\n", tambah, s, count=1, flags=re.M)
    if n != 1:
        raise SystemExit("bagian dev_dependencies tidak ditemukan di pubspec.yaml")
    open(p, "w", encoding="utf-8").write(s)
    print("integration_test ditambahkan ke dev_dependencies (workspace CI)")
PY
flutter pub get
