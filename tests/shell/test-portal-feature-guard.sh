#!/usr/bin/env bash
# The portal the shell ships must still contain the features a customer uses.
#
# WHY THIS EXISTS HERE, IN THE SHELL
#
#   This repository does not build the portal - it applies a brand overlay to a portal
#   checkout and ships the result. That means the shell is the last place a broken portal
#   can be caught before it reaches a router: the portal project's own tests cannot see
#   what this shell staged, and its e2e suite does not run green upstream, so it cannot
#   prove anything either way.
#
#   So the guard exists in both places with the same four markers: the portal repo checks
#   its build, and this repo checks any build it is about to ship.
#
# WHAT IS ASSERTED
#
#     lightning-invoice  the Lightning tab asks the backend for an invoice   (portal bundle)
#     paste-ecash        the Cashu tab has a field to paste an ecash token   (portal bundle)
#     balance-page       the standalone balance page renders                 (balance bundle)
#     balance-copy       the balance page carries its own copy               (balance bundle)
#
#   Bundle scoping is deliberate: a marker that migrated to the wrong page still fails,
#   which a single grep over the whole tree would miss.
#
# usage: bash tests/shell/test-portal-feature-guard.sh
# exit 0 = PASS, 2 = FAIL
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$here"

ok=0; fail=0
pass() { ok=$((ok+1)); echo "ok   - $1"; }
bad()  { fail=$((fail+1)); echo "FAIL - $1" >&2; }

GUARD="scripts/check-portal-features.sh"
if [ ! -f "$GUARD" ]; then
    echo "FAIL - $GUARD is missing; the shell cannot detect a portal that lost a feature" >&2
    exit 2
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# A minimal but realistic build tree: portal bundle, balance bundle, both html entries.
make_build() { # $1=dir  $2=portal-invoice  $3=portal-cashu  $4=balance-page  $5=balance-copy
    mkdir -p "$1/assets"
    printf '/* portal */ %s %s \n' "$2" "$3" > "$1/assets/index-aaa111.js"
    printf '/* balance */ %s %s \n' "$4" "$5" > "$1/assets/balance-bbb222.js"
    printf '<html><head><title>P</title></head></html>\n' > "$1/index.html"
    printf '<html><head><title>B</title></head></html>\n' > "$1/balance.html"
}

# ── 1. a complete build passes ───────────────────────────────────────────────
B="$work/complete"
make_build "$B" ln-invoice cashu-token tollgate-captive-portal-balance-page balance_page_title
if bash "$GUARD" "$B" >"$work/o1" 2>&1; then
    pass "a build carrying all four features passes"
else
    bad "a complete build was rejected: $(head -3 "$work/o1" | tr '\n' ' ')"
fi

# ── 2. each feature, removed in turn, fails ──────────────────────────────────
check_fails() { # $1=label  $2..=make_build args
    local label="$1"; shift
    local d="$work/$label"
    make_build "$d" "$@"
    if bash "$GUARD" "$d" >"$work/o-$label" 2>&1; then
        bad "$label: the guard did not notice the missing feature"
    else
        pass "$label: rejected"
    fi
}

check_fails no-invoice   invoice-renamed cashu-token tollgate-captive-portal-balance-page balance_page_title
check_fails no-cashu     ln-invoice cashu-field-renamed tollgate-captive-portal-balance-page balance_page_title
check_fails no-balance   ln-invoice cashu-token renamed-root-class balance_page_title
check_fails no-balcopy   ln-invoice cashu-token tollgate-captive-portal-balance-page copy-renamed

# ── 3. locality: a balance marker in the PORTAL bundle does not count ───────
B="$work/local"
make_build "$B" ln-invoice cashu-token renamed-root-class copy-renamed
printf '/* portal */ ln-invoice cashu-token tollgate-captive-portal-balance-page balance_page_title\n' \
    > "$B/assets/index-aaa111.js"
if bash "$GUARD" "$B" >"$work/o3" 2>&1; then
    bad "locality: a balance marker found only in the portal bundle was accepted"
else
    pass "locality: markers must live in the bundle that serves them"
fi

# ── 4. a missing balance page fails even if its bundle has the markers ──────
B="$work/nopage"
make_build "$B" ln-invoice cashu-token tollgate-captive-portal-balance-page balance_page_title
rm -f "$B/balance.html"
if bash "$GUARD" "$B" >"$work/o4" 2>&1; then
    bad "a build with no balance.html was accepted"
else
    pass "a build with no balance page is rejected"
fi

# ── 5. absence of a build must never read as success ────────────────────────
if bash "$GUARD" "$work/does-not-exist" >"$work/o5" 2>&1; then
    bad "a non-existent build directory was accepted — the gate would be vacuous"
else
    pass "a missing build directory is rejected, not silently skipped"
fi

# ── 6. the failure message names what the customer lost, not just a marker ──
B="$work/message"
make_build "$B" invoice-renamed cashu-token tollgate-captive-portal-balance-page balance_page_title
bash "$GUARD" "$B" >"$work/o6" 2>&1 || true
if grep -qi 'invoice' "$work/o6"; then
    pass "the failure names the feature in customer terms"
else
    bad "the failure message does not say which feature broke"
fi

echo
if [ "$fail" -eq 0 ]; then
    echo "PASS — the portal feature guard rejects every way a customer-facing feature can vanish ($ok checks)"
    exit 0
fi
echo "RESULT: FAIL — ${fail} assertion(s) failed, ${ok} passed" >&2
exit 2
