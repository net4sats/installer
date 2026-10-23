#!/usr/bin/env bash
# Local gate runner — used during development to run every gate and report.
#
# The tests are BASH, not POSIX: running them under `sh` produces spurious
# failures ("Bad substitution") because several use bash-only constructs. CI
# invokes them with `bash`; so does this runner.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

rc_all=0
for t in tests/shell/test-*.sh; do
    log="$(mktemp)"
    bash "$t" > "$log" 2>&1
    rc=$?
    [ "$rc" -ne 0 ] && rc_all=1
    printf '%-42s rc=%-2s ok=%-3s FAIL=%-2s\n' \
        "$(basename "$t")" "$rc" \
        "$(grep -c '^ok' "$log")" "$(grep -c '^FAIL' "$log")"
    grep '^FAIL' "$log" || true
done

echo
echo "=== live run-time notice (stderr on an introspection mode) ==="
bash install.sh --print-launcher-path 2>&1 >/dev/null | head -3
echo
echo "=== live run: --help reaches upstream ==="
bash install.sh --help 2>&1 | head -4

exit "$rc_all"
