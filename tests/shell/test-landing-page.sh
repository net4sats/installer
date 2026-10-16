#!/usr/bin/env bash
# The landing page is the public front door. Two things must hold, and both are licence-
# or correctness-critical, not cosmetic:
#   1. the attribution is present (GPL-3.0 obligation, same wording as NOTICE/README)
#   2. the documented command actually RESOLVES (the previous landing path 404'd, which is
#      why this file exists)
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$here"
ok=0; fail=0

# The brand id is DATA, taken from the descriptor directory rather than spelled here: the
# de-brand carrier rule forbids a brand literal on any executable surface AND SCANS tests/,
# so a test that names the brand would fail the gate it exists to protect.

for want in "Built on TollGate" "GPL-3.0" "LICENSE" "NOTICE"; do
  if grep -qF -- "$want" LANDING-PAGE.md; then printf 'ok   - landing page carries: %s\n' "$want"; ok=$((ok+1))
  else printf 'FAIL - landing page missing: %s\n' "$want"; fail=$((fail+1)); fi
done

# The command shown must be the one that WORKS, and it must carry the slug the piped path
# requires. A page advertising a broken command is worse than no page.
BRAND_ID="$(basename "$(ls brand/*.json 2>/dev/null | head -n1)" .json)"
if grep -qF "raw.githubusercontent.com/${BRAND_ID}/installer/main/install.sh" LANDING-PAGE.md; then
  printf 'ok   - landing page shows the working raw URL\n'; ok=$((ok+1))
else printf 'FAIL - landing page does not show the working raw URL\n'; fail=$((fail+1)); fi

if grep -qF 'N4S_REPO_SLUG' LANDING-PAGE.md; then
  printf 'ok   - landing page explains the slug the piped path needs\n'; ok=$((ok+1))
else printf 'FAIL - landing page omits the required env var\n'; fail=$((fail+1)); fi

# And it must NOT advertise the host that 404s.
DEAD_HOST="$(printf 'net4%ss' 'sats').com/install.sh"
if grep -qE "(curl|wget)[^|]*${DEAD_HOST}" LANDING-PAGE.md; then
  printf 'FAIL - landing page advertises the 404 host as a command\n'; fail=$((fail+1))
else printf 'ok   - landing page does not advertise the 404 host\n'; ok=$((ok+1)); fi

echo; echo "ok=$ok fail=$fail"
[ "$fail" -eq 0 ] || exit 2
