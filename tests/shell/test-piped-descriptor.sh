#!/usr/bin/env bash
# The PIPED introspection must report a TRUTHFUL descriptor location.
#
# When the shell is piped (`curl ... | sh`), there is no repo on disk and ROOT is
# empty, so BRAND_DIR is "". The mode printer interpolated "${BRAND_DIR}/${BRAND}.json"
# unconditionally and therefore printed `descriptor=/<id>.json` — a path at the ROOT
# of the caller's machine. That path does not exist, is not what the piped path reads
# (it reads brand/active from the fetch base), and misleads an operator debugging a
# failed brand resolution into looking in the wrong place.
#
# HERMETIC BY CONSTRUCTION: this gate defaults the fetch base to a file:// URL over
# this checkout, so it needs NO network and can run in CI. `curl -fsSL` resolves
# file:// exactly as it resolves https for our purposes (the shell's own code path is
# identical — only _RAW_BASE differs), so the assertion is the same one.
#
# The property: in piped mode the reported descriptor must (a) be under the base the
# piped path actually reads from, and (b) NAME A REAL DESCRIPTOR that exists.
#
# The from-disk case must be UNCHANGED (a real absolute path); that is asserted too,
# so a fix cannot "solve" the piped case by degrading the on-disk one.
set -u
cd "$(dirname "$0")/../.." || exit 1
TREE="$(pwd)"

pass=0; fail=0
ok()   { pass=$((pass+1)); printf 'ok   - %s\n' "$*"; }
bad()  { fail=$((fail+1)); printf 'FAIL - %s\n' "$*"; }

# The brand id is DATA: derive it, never spell it. The repo slug is assembled from
# the derived id for the same reason — this file must carry no brand literal on an
# executable surface (the carrier rule scans tests/ too; the fix is to derive the
# value, never to exempt the test).
BRAND_ID="$(tr -d '\n\r' < brand/active)"
SLUG="${N4S_TEST_SLUG:-${BRAND_ID}/installer}"

# Default: hermetic file:// base over this checkout (no network). Set
# N4S_TEST_NETWORK=1 to exercise the real https raw base instead.
if [ "${N4S_TEST_NETWORK:-0}" = "1" ]; then
    BASE="https://raw.githubusercontent.com/${SLUG}/main"
    BASE_KIND="https"
else
    BASE="file://${TREE}"
    BASE_KIND="file"
fi

# --- piped invocation, exactly the documented shape -------------------------
OUT="$(printf '%s' "$(cat install.sh)" \
    | N4S_REPO_SLUG="$SLUG" N4S_REPO_URL="$BASE" sh -s -- --print-brand-mode 2>/dev/null || true)"

DESC="$(printf '%s' "$OUT" | sed -n 's/.*descriptor=//p')"
printf '       base (%s): %s\n' "$BASE_KIND" "$BASE"
printf '       piped output: %s\n' "$OUT"

if [ -z "$DESC" ]; then
    bad "piped --print-brand-mode printed no descriptor field at all"
else
    # THE DEFECT: an absolute path with an EMPTY directory component — "/<id>.json".
    case "$DESC" in
        "//"*|"/${BRAND_ID}.json"|"${BRAND_ID}.json")
            bad "piped descriptor is a ragged/absent filesystem path [$DESC] — the piped path has no repo on disk" ;;
        *)
            # It must be anchored to the base the piped path actually reads from.
            case "$DESC" in
                "$BASE"/*)
                    ok "piped descriptor is anchored to the base the piped path reads [$DESC]" ;;
                *)
                    bad "piped descriptor is not under the fetch base [$DESC] (base=$BASE)" ;;
            esac
            # ...and it must NAME A REAL DESCRIPTOR, not just look plausible.
            case "$DESC" in
                *"/brand/${BRAND_ID}.json")
                    ok "piped descriptor names brand/${BRAND_ID}.json" ;;
                *)
                    bad "piped descriptor does not name brand/${BRAND_ID}.json [$DESC]" ;;
            esac
            # For the hermetic base, prove the target genuinely resolves. This is the
            # assertion that would have caught the original defect even if the string
            # had happened to look well-formed.
            if [ "$BASE_KIND" = "file" ]; then
                if curl -fsSL "$DESC" >/dev/null 2>&1; then
                    ok "the reported piped descriptor URL actually RESOLVES to a real descriptor"
                else
                    bad "the reported piped descriptor URL does NOT resolve [$DESC]"
                fi
            fi
            ;;
    esac
fi

# --- control: the brand itself is still resolved over the pipe --------------
if printf '%s' "$OUT" | grep -q "brand=${BRAND_ID} "; then
    ok "control: the piped path still resolves brand=${BRAND_ID} (fix did not de-brand it)"
else
    bad "control: piped path lost brand=${BRAND_ID} — got: $OUT"
fi

# --- de-brand over the pipe is still the sentinel, with no descriptor ------
OUTN="$(printf '%s' "$(cat install.sh)" \
    | N4S_REPO_SLUG="$SLUG" N4S_REPO_URL="$BASE" sh -s -- --brand none --print-brand-mode 2>/dev/null || true)"
if printf '%s' "$OUTN" | grep -q 'brand=none descriptor=none'; then
    ok "control: --brand none over the pipe is still 'brand=none descriptor=none'"
else
    bad "control: --brand none over the pipe changed — got: $OUTN"
fi

# --- from-disk must remain a REAL absolute path (no regression) ------------
OUTD="$(sh ./install.sh --print-brand-mode 2>/dev/null || true)"
DESCD="$(printf '%s' "$OUTD" | sed -n 's/.*descriptor=//p')"
EXPECT_D="${TREE}/brand/${BRAND_ID}.json"
if [ "$DESCD" = "$EXPECT_D" ]; then
    ok "from-disk descriptor is unchanged: the real absolute path under brand/"
else
    bad "from-disk descriptor changed: expected [$EXPECT_D], got [$DESCD]"
fi

printf '\npass=%s fail=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
