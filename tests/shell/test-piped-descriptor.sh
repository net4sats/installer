#!/usr/bin/env bash
# RED-first: the PIPED introspection must report a TRUTHFUL descriptor location.
#
# When the shell is piped (`curl ... | sh`), there is no repo on disk and ROOT is
# empty, so BRAND_DIR is "". The mode printer interpolated "${BRAND_DIR}/${BRAND}.json"
# unconditionally and therefore printed `descriptor=/<id>.json` — a filesystem
# path at the ROOT of the caller's machine. That path does not exist, is not what the
# piped path reads (it fetches brand/active from the raw base), and misleads an
# operator debugging a failed brand resolution into looking in the wrong place.
#
# The property asserted here: in piped mode the descriptor must be reported as the
# URL the piped path actually uses — never a bare/ragged filesystem path.
#
# The from-disk case must be UNCHANGED (a real absolute path); that is asserted too,
# so a fix cannot "solve" the piped case by degrading the on-disk one.
set -u
cd "$(dirname "$0")/../.." || exit 1

pass=0; fail=0
ok()   { pass=$((pass+1)); printf 'ok   - %s\n' "$*"; }
bad()  { fail=$((fail+1)); printf 'FAIL - %s\n' "$*"; }

# The brand id is DATA: derive it, never spell it. The repo slug is assembled the
# same way (owner from the derived id), so this test file carries no brand literal
# on an executable surface — the carrier rule scans tests/ too, and the right fix
# is to derive the value, never to exempt the test.
BRAND_ID="$(tr -d '\n\r' < brand/active)"
SLUG="${N4S_TEST_SLUG:-${BRAND_ID}/installer}"

# --- piped invocation, exactly the documented shape -------------------------
OUT="$(printf '%s' "$(cat install.sh)" \
    | N4S_REPO_SLUG="$SLUG" sh -s -- --print-brand-mode 2>/dev/null || true)"

DESC="$(printf '%s' "$OUT" | sed -n 's/.*descriptor=//p')"
printf '       piped output: %s\n' "$OUT"

if [ -z "$DESC" ]; then
    bad "piped --print-brand-mode printed no descriptor field at all"
else
    # The defect: an absolute filesystem path with an EMPTY directory component.
    case "$DESC" in
        "//"*|"/${BRAND_ID}.json"|"${BRAND_ID}.json")
            bad "piped descriptor is a ragged/absent filesystem path [$DESC] — the piped path has no repo on disk"
            ;;
        http://*|https://*)
            case "$DESC" in
                *"/brand/${BRAND_ID}.json")
                    ok "piped descriptor is the URL the piped path actually reads [$DESC]" ;;
                *)
                    bad "piped descriptor URL does not name brand/${BRAND_ID}.json [$DESC]" ;;
            esac
            ;;
        /*)
            # An absolute path is only legitimate if it really exists on disk.
            if [ -f "$DESC" ]; then
                ok "piped descriptor is an absolute path that exists [$DESC]"
            else
                bad "piped descriptor is an absolute path that does NOT exist [$DESC]"
            fi
            ;;
        *)
            bad "piped descriptor is neither a URL nor an existing absolute path [$DESC]" ;;
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
    | N4S_REPO_SLUG="$SLUG" sh -s -- --brand none --print-brand-mode 2>/dev/null || true)"
if printf '%s' "$OUTN" | grep -q 'brand=none descriptor=none'; then
    ok "control: --brand none over the pipe is still 'brand=none descriptor=none'"
else
    bad "control: --brand none over the pipe changed — got: $OUTN"
fi

# --- from-disk must remain a REAL absolute path (no regression) ------------
OUTD="$(sh ./install.sh --print-brand-mode 2>/dev/null || true)"
DESCD="$(printf '%s' "$OUTD" | sed -n 's/.*descriptor=//p')"
EXPECT_D="$(cd "$(dirname "$0")/../.." && pwd)/brand/${BRAND_ID}.json"
if [ "$DESCD" = "$EXPECT_D" ]; then
    ok "from-disk descriptor is unchanged: the real absolute path under brand/"
else
    bad "from-disk descriptor changed: expected [$EXPECT_D], got [$DESCD]"
fi

printf '\npass=%s fail=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
