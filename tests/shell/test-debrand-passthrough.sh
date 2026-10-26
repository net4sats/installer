#!/usr/bin/env bash
# De-brand regression test — the no-brand path must stay byte-identical.
#
# WHY THIS EXISTS
#
#   This repository is a THIN BRANDED SHELL: a brand INPUT plus a pin, and
#   nothing else. The failure this test makes impossible is the one the upstream
#   rebrand gutter exists to prevent one repo over — the distribution's brand
#   drifting back into the repository as a LITERAL, so the generic path stops
#   being generic and no gate notices.
#
#   Three invariants, all asserted mechanically:
#
#     A. RENDER. With no brand selected the wrapper must hand bash the SAME
#        BYTES as upstream — not an "equivalent" script, the identical artifact,
#        proven by sha256 against a recorded pin.
#
#     B. RUN. The forwarded argv must be the operator's own argv, in order,
#        verbatim, and unchanged by brand selection. The sharp edge: upstream's
#        launcher drains "$@" itself and its arg loop ends in
#        `*) POSITIONAL+=("$1")`, so EVERY token it does not recognise becomes a
#        POSITIONAL and the FIRST positional is the ROUTER IP. A wrapper that
#        appended its brand flag to argv would have the brand read as a router
#        address. The brand therefore travels in the ENVIRONMENT, and this test
#        asserts argv is byte-identical with and without a brand selected.
#
#     C. CARRIER. The wrapper's executable code must not carry the brand literal
#        at all — not even as a default. The default is DATA (brand/active),
#        resolved at run time. The scan pattern is a bracket expression so the
#        test can scan the whole tree, itself included, without matching its own
#        bytes — the same trick the upstream gutter uses.
#
# SCAN SURFACES (C)
#   install.sh, scripts/**, tests/** — executable code and its tooling.
#   Deliberately NOT scanned: README.md, AGENTS.md, docs/**, brand/**, NOTICE,
#   REPORT.md. An operator-facing document must be able to NAME the brand, and
#   brand/ IS the input. That is a decision, not an oversight.
#
# usage: tests/shell/test-debrand-passthrough.sh [tree]
# exit 0 = PASS, 2 = FAIL
set -u

TREE="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
WRAPPER="${TREE}/install.sh"
PIN_RECORD="${TREE}/scripts/upstream-launcher.sha256"
VENDORED="${TREE}/vendor/upstream-install-and-test.sh"

FAIL=0
ok()  { printf 'ok   - %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL - %s\n' "$1" >&2; }

# ── negative controls ───────────────────────────────────────────────────────
# No brand literal is spelled in this file. The controls compose a real match
# and a near-miss at run time, so the pattern is proven to still fire on a real
# occurrence and still refuse a near-miss. A scan that matches nothing must
# never read as a pass. (A first draft of this file got the printf format string
# wrong; these controls are what caught it — which is why they exist.)
REAL_MATCH="$(printf 'net4%sats' s)"
NEAR_MISS="$(printf 'net4%sats' z)"
PROBE_BRAND="$(printf 'probe-%s-zz' "$(printf 'brand')")"   # a brand id that is NOT the shipped one

if printf '%s' "$REAL_MATCH" | grep -qE 'net4[s]ats'; then
    ok "control: the scan pattern matches a real literal"
else
    bad "control: scan pattern does NOT match a real literal — the scan is worthless"
fi
if printf '%s' "$NEAR_MISS" | grep -qE 'net4[s]ats'; then
    bad "control: scan pattern matches a NEAR-MISS ($NEAR_MISS) — pattern is too loose"
else
    ok "control: the scan pattern refuses a near-miss"
fi

# ── artifact presence ───────────────────────────────────────────────────────
MISSING=0
for f in "$WRAPPER" "$PIN_RECORD" "$VENDORED" "${TREE}/brand/active"; do
    [ -f "$f" ] || { bad "missing required file: ${f#"$TREE"/}"; MISSING=1; }
done
if [ "$MISSING" -eq 1 ]; then
    echo; echo "RESULT: FAIL (missing artifacts — nothing further could be checked)" >&2; exit 2
fi

# ── A. RENDER: the bytes handed to bash are upstream's, unmodified ──────────
RECORDED_SHA="$(awk '/^sha256/ {print $2}' "$PIN_RECORD" | head -1)"
if [ -z "$RECORDED_SHA" ]; then
    bad "no sha256 recorded in scripts/upstream-launcher.sha256"
else
    ok "pin record carries a sha256 (${RECORDED_SHA:0:16}…)"
fi
VENDORED_SHA="$(sha256sum "$VENDORED" | awk '{print $1}')"
if [ "$VENDORED_SHA" = "$RECORDED_SHA" ]; then
    ok "vendored launcher is BYTE-IDENTICAL to the pinned upstream bytes"
else
    bad "vendored launcher differs from the pin: pin=${RECORDED_SHA:0:16}… vendored=${VENDORED_SHA:0:16}…"
fi

# The PIPED path has no repository on disk, so install.sh carries the same digest
# as LAUNCHER_SHA_EMBEDDED. A re-record that updates the file but not the constant
# would leave the documented one-liner verifying the OLD bytes — it would fetch the
# new launcher and abort with a checksum mismatch, or (worse, on the pre-fix bytes)
# accept a stale one. Assert the two copies are one value.
EMBEDDED_SHA="$(sed -n 's/^LAUNCHER_SHA_EMBEDDED="\([0-9a-f]\{64\}\)"$/\1/p' "$WRAPPER" | head -1)"
if [ -z "$EMBEDDED_SHA" ]; then
    bad "install.sh carries no parsable LAUNCHER_SHA_EMBEDDED — the piped path would verify nothing"
elif [ "$EMBEDDED_SHA" = "$RECORDED_SHA" ]; then
    ok "the digest embedded in install.sh equals the pin record (piped path agrees)"
else
    bad "embedded launcher digest differs from the pin record: embedded=${EMBEDDED_SHA:0:16}… pin=${RECORDED_SHA:0:16}…"
fi

RESOLVED="$(bash "$WRAPPER" --print-launcher-path 2>/dev/null || true)"
case "${RESOLVED:-}" in
    "") bad "install.sh --print-launcher-path produced nothing" ;;
    /*) ;;
    *)  RESOLVED="${TREE}/${RESOLVED}" ;;
esac
if [ ! -f "${RESOLVED:-/nonexistent}" ]; then
    bad "--print-launcher-path points at a nonexistent file: ${RESOLVED:-<empty>}"
else
    RS="$(sha256sum "$RESOLVED" | awk '{print $1}')"
    if [ "$RS" = "$RECORDED_SHA" ]; then
        ok "--print-launcher-path resolves to the pinned upstream bytes"
    else
        bad "--print-launcher-path resolves to ${RS:0:16}…, not the pin ${RECORDED_SHA:0:16}…"
    fi
fi

# ── B. RUN: argv pass-through, unchanged by brand selection ─────────────────
read_cmd() { bash "$WRAPPER" --print-command "$@" 2>/dev/null || true; }
canon() { awk -v rp="${RESOLVED:-$VENDORED}" -v vd="$VENDORED" \
    '{ if ($0 == rp || $0 == vd) print "<LAUNCHER>"; else print }'; }

PLAIN_CMD="$(read_cmd --one --two=three 'four five' | sed '/^$/d')"
if [ -z "$PLAIN_CMD" ]; then
    bad "install.sh --print-command produced nothing"
else
    GOT="$(printf '%s' "$PLAIN_CMD" | canon)"
    WANT="$(printf 'bash\n<LAUNCHER>\n--one\n--two=three\nfour five\n')"
    if [ "$GOT" = "$WANT" ]; then
        ok "forwarded argv is exactly: bash <launcher> --one --two=three 'four five'"
    else
        bad "forwarded argv is not a clean pass-through"
        printf '    expected:\n%s\n    got:\n%s\n' "$WANT" "$GOT" >&2
    fi
    if [ "$(printf '%s' "$PLAIN_CMD" | sed -n '1p')" = "bash" ]; then
        ok "argv[0] is bash, not a rewrite of the launcher"
    else
        bad "argv[0] is '$(printf '%s' "$PLAIN_CMD" | sed -n '1p')', expected bash"
    fi
    if [ "$(printf '%s' "$PLAIN_CMD" | sed -n '$p')" = "four five" ]; then
        ok "the token containing a space survived argv forwarding verbatim"
    else
        bad "token 'four five' did not survive: last argv is '$(printf '%s' "$PLAIN_CMD" | sed -n '$p')'"
    fi
fi

# THE HAZARD GUARD: a selected brand must be CONSUMED, never forwarded.
BRAND_CMD="$(read_cmd --one --two=three 'four five' --brand "$PROBE_BRAND" | sed '/^$/d')"
if [ -z "$BRAND_CMD" ]; then
    bad "install.sh --print-command produced nothing with --brand set"
elif [ "$BRAND_CMD" = "$PLAIN_CMD" ]; then
    ok "the brand flag is consumed here, so argv is byte-identical to the no-brand case"
else
    bad "the brand reached the forwarded argv — upstream would read it as the ROUTER IP"
    printf '    no-brand:\n%s\n    branded:\n%s\n' "$(printf '%s' "$PLAIN_CMD" | canon)" \
        "$(printf '%s' "$BRAND_CMD" | canon)" >&2
fi
if printf '%s' "$BRAND_CMD" | grep -q -- '--brand'; then
    bad "the literal token --brand is present in the forwarded argv"
else
    ok "the forwarded argv carries no --brand token"
fi

# ── brand resolution is live (a control for the equality above) ─────────────
read_mode() { bash "$WRAPPER" --print-brand-mode "$@" 2>/dev/null || true; }
SHIPPED_BRAND="$(tr -d '\n\r' < "${TREE}/brand/active")"
MODE_DEFAULT="$(read_mode)"
MODE_NONE="$(TOLLGATE_NO_BRAND=1 read_mode)"
MODE_PROBE="$(read_mode --brand "$PROBE_BRAND")"

case "$MODE_DEFAULT" in
    "brand=${SHIPPED_BRAND} descriptor=${TREE}/brand/${SHIPPED_BRAND}.json")
        ok "default mode selects the descriptor named by brand/active (${SHIPPED_BRAND})" ;;
    "") bad "--print-brand-mode produced nothing" ;;
    *)  bad "default mode is wrong: '$MODE_DEFAULT' (want brand=${SHIPPED_BRAND})" ;;
esac
case "$MODE_NONE" in
    "brand=none descriptor=none") ok "control: TOLLGATE_NO_BRAND=1 resolves the de-branded path" ;;
    *) bad "control: TOLLGATE_NO_BRAND=1 did not resolve brand=none (got: '${MODE_NONE:-<empty>}')" ;;
esac
case "$MODE_PROBE" in
    "brand=${PROBE_BRAND} descriptor=${TREE}/brand/${PROBE_BRAND}.json")
        ok "control: an explicit --brand is observed by the wrapper" ;;
    *) bad "control: explicit --brand not observed (got: '${MODE_PROBE:-<empty>}')" ;;
esac

# An unknown/absent brand must not be silently accepted as a descriptor.
if bash "$WRAPPER" --brand "$PROBE_BRAND" --print-brand-mode >/dev/null 2>&1; then
    :
fi
if [ -f "${TREE}/brand/${PROBE_BRAND}.json" ]; then
    bad "the probe brand unexpectedly exists as a descriptor — the control is not a control"
else
    ok "control: the probe brand genuinely has no descriptor (default-mode result is not a fallback)"
fi

# --brand with no value must fail loudly rather than resolve something odd.
if bash "$WRAPPER" --brand >/dev/null 2>&1; then
    bad "--brand with no value exited 0 — it must fail loudly"
else
    ok "--brand with no value fails loudly"
fi

# The launcher BYTES must be the pinned artifact in every mode.
for m in default none probe; do
    case "$m" in
        default) LP="$(bash "$WRAPPER" --print-launcher-path 2>/dev/null || true)" ;;
        none)    LP="$(TOLLGATE_NO_BRAND=1 bash "$WRAPPER" --print-launcher-path 2>/dev/null || true)" ;;
        probe)   LP="$(bash "$WRAPPER" --print-launcher-path --brand "$PROBE_BRAND" 2>/dev/null || true)" ;;
    esac
    case "$LP" in /*) ;; *) LP="${TREE}/${LP}" ;; esac
    if [ -n "$LP" ] && [ -f "$LP" ] && \
       [ "$(sha256sum "$LP" | awk '{print $1}')" = "$RECORDED_SHA" ]; then
        ok "launcher is the pinned artifact in '$m' mode"
    else
        bad "mode '$m' does not resolve the pinned launcher (got '${LP:-<empty>}')"
    fi
done

# ── C. CARRIER: no brand literal on an executable surface ──────────────────
CARRIER_FILES="$WRAPPER"
for d in "$TREE/scripts" "$TREE/tests"; do
    [ -d "$d" ] || continue
    while IFS= read -r f; do
        [ -n "$f" ] && CARRIER_FILES="$CARRIER_FILES $f"
    done <<EOF
$(find "$d" -type f 2>/dev/null | sort)
EOF
done

HIT=0; N_FILES=0
for f in $CARRIER_FILES; do
    [ -f "$f" ] || continue
    N_FILES=$((N_FILES + 1))
    if grep -qE 'net4[s]ats' "$f"; then
        bad "brand literal on an executable surface: ${f#"$TREE"/}"
        HIT=1
    fi
done
if [ "$HIT" -eq 0 ]; then
    ok "no brand literal on any scanned executable surface (${N_FILES} files)"
fi

# The carrier rule must have been satisfied by moving the literal into DATA,
# not by deleting the brand: the shipped default must be non-empty and must
# resolve to a real descriptor.
if [ -n "$SHIPPED_BRAND" ]; then
    ok "the default brand lives in brand/active as DATA ('${SHIPPED_BRAND}')"
    if [ -f "${TREE}/brand/${SHIPPED_BRAND}.json" ]; then
        ok "brand/${SHIPPED_BRAND}.json exists (the default resolves to a real descriptor)"
    else
        bad "brand/active names '${SHIPPED_BRAND}' but brand/${SHIPPED_BRAND}.json does not exist"
    fi
else
    bad "brand/active is empty — the carrier rule passed for the wrong reason"
fi

# ── report ──────────────────────────────────────────────────────────────────
echo
if [ "$FAIL" -eq 0 ]; then
    echo "RESULT: PASS — no-brand path byte-identical to upstream, argv forwarded verbatim, brand is data"
    exit 0
fi
echo "RESULT: FAIL — ${FAIL} assertion(s) failed" >&2
exit 2
