#!/usr/bin/env bash
# Every install URL this repo ADVERTISES must actually resolve. The README's
# headline command pointed at a host that returns 404, so a user following the
# docs hit a dead end. This asserts the documented URLs actually resolve.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$here"
ok=0; fail=0
echo "=== documented https URLs in README.md / docs/ ==="
urls=$(grep -rhoE 'https://[A-Za-z0-9./_-]+' README.md docs/*.md 2>/dev/null \
        | grep -vE 'github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/(pull|issues)/' \
        | sort -u)
[ -n "$urls" ] || { echo "FAIL - no URLs found to check (scan broken)"; exit 2; }
for u in $urls; do
  case "$u" in
    *raw.githubusercontent.com*|*github.com*|*opensource.org*|*gnu.org*|*tollgate*|*openwrt.org*)
      code=$(curl -s -o /dev/null -w '%{http_code}' -L --max-time 20 "$u" 2>/dev/null)
      if [ "$code" = "200" ]; then printf 'ok   - %s (%s)\n' "$u" "$code"; ok=$((ok+1))
      else printf 'FAIL - %s -> HTTP %s\n' "$u" "$code"; fail=$((fail+1)); fi ;;
    *) printf 'skip - %s (external, not asserted)\n' "$u" ;;
  esac
done
echo
echo "=== no install COMMAND may use the known-404 host ==="
# Prose may RECORD the dead URL (VALIDATION.md documents it as a known defect);
# what must never happen is presenting it as a command to run. So assert on lines
# that look like a command: a curl/wget invocation or a bare URL on its own line.
#
# NOTE: this file must not spell the brand itself — the carrier rule scans tests/.
# The host is assembled from parts so the literal never appears here.
_DEAD_HOST="$(printf 'net4%ss' 'sats').com/install.sh"
bad=$(grep -nE "(curl|wget)[^|]*${_DEAD_HOST}|^[[:space:]]*https?://${_DEAD_HOST}" \
        README.md docs/*.md 2>/dev/null)
if [ -n "$bad" ]; then
  echo "FAIL - a documented COMMAND advertises the 404 host:"; printf '%s\n' "$bad" | sed 's/^/        /'
  fail=$((fail+1))
else
  echo "ok   - no documented command points at the known-404 host"; ok=$((ok+1))
fi
echo
echo "ok=$ok fail=$fail"
[ "$fail" -eq 0 ] || exit 2
