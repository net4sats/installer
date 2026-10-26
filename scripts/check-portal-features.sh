#!/usr/bin/env bash
# Refuse to ship a portal that lost a customer-facing feature.
#
# WHY THIS EXISTS
#
#   This repository does not build the portal; it applies a brand overlay to a portal
#   checkout and ships the result. That makes it the LAST place a broken portal can be
#   caught before it reaches a router — the portal project's tests cannot see what this
#   shell staged, and its e2e suite does not run green upstream, so it proves nothing
#   either way. Branding is exactly the kind of step that can drop a page: it rewrites
#   html entries, the PWA manifest and locale strings, and it restores sources afterwards.
#
# WHAT IS CHECKED
#
#   Four markers, each looked for ONLY in the bundle that must serve it:
#
#     lightning-invoice  the Lightning tab can request an invoice    portal bundle
#     paste-ecash        the Cashu tab has a field to paste a token  portal bundle
#     balance-page       the standalone balance page renders         balance bundle + balance.html
#     balance-copy       the balance page carries its own copy       balance bundle
#
#   Scoping is the point: one grep over the whole tree would pass a marker that had
#   migrated to the wrong page, and the page a customer needs would still be broken.
#
#   A missing build directory is a FAILURE, never a skip. A gate that silently skips is a
#   gate that reports success on nothing.
#
# usage: bash scripts/check-portal-features.sh <build-dir>
# exit 0 = every feature present, 2 = at least one missing, 3 = bad usage
set -uo pipefail

build="${1:-}"
if [ -z "$build" ]; then
    echo "usage: $0 <build-dir>" >&2
    exit 3
fi
if [ ! -d "$build" ]; then
    echo "check-portal-features: not a build directory: $build" >&2
    echo "A build that cannot be found has not been checked; refusing to report success." >&2
    exit 2
fi
if [ ! -d "$build/assets" ]; then
    echo "check-portal-features: $build/assets is missing — that is not a portal build" >&2
    exit 2
fi

ok=0; fail=0
missing=""

# Marker present in ANY of the given files.
grep_any() { # $1=marker  $2..=files
    local marker="$1"; shift
    local f
    for f in "$@"; do
        [ -f "$f" ] || continue
        grep -qF -- "$marker" "$f" 2>/dev/null && return 0
    done
    return 1
}

# Split the bundles: balance-*.js serves the standalone page, everything else serves the
# portal. Shell globbing keeps this dependency-free, which matters on a build host that
# may not have node.
portal_files=( "$build/index.html" )
balance_files=( "$build/balance.html" )
for f in "$build"/assets/*; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in
        balance-*) balance_files+=( "$f" ) ;;
        *)         portal_files+=( "$f" ) ;;
    esac
done

check() { # $1=id  $2=customer text  $3=marker  $4=scope
    local id="$1" text="$2" marker="$3" scope="$4"
    local -a files
    if [ "$scope" = "balance" ]; then files=( "${balance_files[@]}" ); else files=( "${portal_files[@]}" ); fi
    if grep_any "$marker" "${files[@]}"; then
        ok=$((ok+1)); printf 'ok   - %s: %s\n' "$id" "$text"
    else
        fail=$((fail+1))
        printf 'FAIL - %s: %s\n' "$id" "$text" >&2
        printf '       marker "%s" not found in the %s bundle\n' "$marker" "$scope" >&2
        missing="$missing $id"
    fi
}

check lightning-invoice "the Lightning tab can request an invoice"     'ln-invoice'                           portal
check paste-ecash       "the Cashu tab has a field to paste a token"    'cashu-token'                          portal
check balance-page      "the standalone balance page renders"           'tollgate-captive-portal-balance-page' balance
check balance-copy      "the balance page carries its own copy"         'balance_page_title'                   balance

# A page cannot render without its entry point, even if its bundle still carries the
# markup: `balance.html` missing means a customer opening the page gets a 404.
if [ ! -f "$build/balance.html" ]; then
    fail=$((fail+1))
    printf 'FAIL - balance-page: the standalone balance page is not served (balance.html absent)\n' >&2
    missing="$missing balance.html"
fi

echo
if [ "$fail" -eq 0 ]; then
    echo "PASS — all $ok customer-facing features present in $build"
    exit 0
fi
echo "check-portal-features: $fail customer-facing feature(s) missing from $build:$missing" >&2
echo "This guard exists because branding rewrites these pages; a feature lost here reaches a customer. Fix the build, do not delete the check." >&2
exit 2
