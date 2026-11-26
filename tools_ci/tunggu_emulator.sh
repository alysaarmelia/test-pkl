#!/usr/bin/env bash
# Menunggu port emulator Firebase terbuka (maks 120 detik). Pemakaian: tunggu_emulator.sh 8080 9199 9099
for port in "$@"; do
  ok=0
  for i in $(seq 1 60); do
    if (echo > /dev/tcp/127.0.0.1/"$port") 2>/dev/null; then ok=1; break; fi
    sleep 2
  done
  [ "$ok" = 1 ] && echo "port $port siap" || { echo "port $port TIDAK siap"; exit 1; }
done
