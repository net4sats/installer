#!/usr/bin/env bash
# RED: the README's advertised piped one-liner must install BRANDED, not de-branded.
#
# `curl ... install.sh | N4S_REPO_SLUG=<owner>/<repo> sh` is the documented
# install path (README "Quick start"). But when piped, $0 is the shell, ROOT is
# empty, and BRAND_DIR becomes "" — so brand_id() can never read brand/active
# and falls through to the "none" sentinel. A customer running the documented
# command got a DE-BRANDED router.
#
# This test pipes the real script through sh exactly as the README shows and
# asserts the brand resolves to the repo's own brand/active, not the none sentinel.
set -u
cd "$(dirname "$0")/../.." || exit 1

pass=0; fail=0
say()  { printf '%s\n' "$*"; }
ok()   { pass=$((pass+1)); say "ok   - $*"; }
not_ok(){ fail=$((fail+1)); say "not_ok - $*"; }

BRAND_EXPECTED="$(tr -d '\n\r' < brand/active)"

# The exact README shape. N4S_REPO_SLUG points at THIS repo so the launcher
# fetch resolves to the same checkout we are testing.
OUT="$(printf '%s' "$(cat install.sh)" | N4S_REPO_SLUG="${N4S_TEST_SLUG:-${BRAND_EXPECTED}/installer}" sh -s -- --print-brand-mode 2>/dev/null || true)"

if printf '%s' "$OUT" | grep -q "brand=${BRAND_EXPECTED} "; then
    ok "the piped one-liner resolves brand=${BRAND_EXPECTED}"
else
    not_ok "the piped one-liner must resolve brand=${BRAND_EXPECTED}, got: ${OUT}"
fi

say ""
say "pass=${pass} fail=${fail}"
[ "$fail" -eq 0 ]
