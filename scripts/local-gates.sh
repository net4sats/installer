#!/usr/bin/env bash
# Local gate runner — used during development to run both gates and report.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.."
echo "=== GATE 1: de-brand passthrough ==="
bash tests/shell/test-debrand-passthrough.sh > /tmp/g1.log 2>&1
echo "RC=$?"
grep '^FAIL' /tmp/g1.log || true
tail -2 /tmp/g1.log
echo "ok count: $(grep -c '^ok' /tmp/g1.log)"
echo
echo "=== GATE 2: licence attribution ==="
bash tests/shell/test-licence-attribution.sh > /tmp/g2.log 2>&1
echo "RC=$?"
grep '^FAIL' /tmp/g2.log || true
tail -2 /tmp/g2.log
echo "ok count: $(grep -c '^ok' /tmp/g2.log)"
echo
echo "=== live run-time notice (stderr on an introspection mode) ==="
bash install.sh --print-launcher-path 2>&1 >/dev/null | head -3
echo
echo "=== live run: --help reaches upstream ==="
bash install.sh --help 2>&1 | head -4
