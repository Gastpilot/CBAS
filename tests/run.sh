#!/bin/bash
# Lua-Mock-Tests (lupa). Aufruf aus dem Repo-Wurzelordner: bash tests/run.sh [nummer ...]
# Benötigt: pip install lupa --break-system-packages
cd "$(dirname "$0")/.." || exit 1
cp tests/stub.lua tests/uimock.lua /tmp/
for f in tests/test*.py; do cp "$f" /tmp/; done
nums=${@:-"9 10 19 22 24 25 26 27 28 30 31 33 34 35 36"}
for n in $nums; do
  out=$(timeout 180 python3 /tmp/test$n.py 2>&1)
  err=$(echo "$out" | grep -ciE "traceback|attempt to|FEHLER")
  echo "test$n: $err Fehlerzeilen"
done
