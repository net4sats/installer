#!/usr/bin/env bash
# ============================================================================
#  Branded installer shell over upstream TollGate.
#
#  This script does exactly two things and no third: it selects a brand, and it
#  hands the operator's own command line to UPSTREAM's pinned launcher. It
#  contains no business logic — no discovery, SSH/trust, deploy, feed
#  resolution, flashing, identity derivation or pricing. All of that lives
#  upstream (OpenTollGate/tollgate-installer) and is consumed here as a pinned,
#  byte-verified artifact.
#
#  Usage (upstream's own usage, plus one optional flag):
#      curl -fsSL <this repo>/install.sh | sh
#      curl -fsSL <this repo>/install.sh | sh -s -- --brand none
#      ./install.sh <ROUTER_IP> <ROUTER_PASSWORD> <LIGHTNING_ADDRESS>
#
#  WHY THE BRAND IS AN ENVIRONMENT INPUT AND NOT A FORWARDED ARGUMENT
#  -----------------------------------------------------------------
#  Upstream's launcher drains "$@" itself, and its argument loop ends in
#  `*) POSITIONAL+=("$1")`. Every token it does not recognise therefore becomes
#  a POSITIONAL, and the FIRST positional is the ROUTER IP. A wrapper that
#  appended `--brand foo` to the forwarded argv would have `foo` read as a
#  router address — a silently wrong target, which is worse than a loud
#  failure. So the brand is exported in the environment (which the launcher
#  inherits and the binary it starts reads) and the forwarded argv stays
#  byte-identical to what the operator typed.
#
#  `--brand <id>` is accepted here and CONSUMED here — it is never forwarded.
#  `--brand none` is the de-branded path: upstream's default naming, with no
#  brand input set at all.
#
#  The launcher is pinned in vendor/ and verified against
#  scripts/upstream-launcher.sha256 on every run; a mismatch aborts rather than
#  executing unverified bytes. Bump the pin deliberately (see docs/PINS.md).
#
#  TollGate is GPL-3.0. See LICENSE and NOTICE.
# ============================================================================
set -eu

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCHER="${ROOT}/vendor/upstream-install-and-test.sh"
PIN_FILE="${ROOT}/scripts/upstream-launcher.sha256"
BRAND_DIR="${ROOT}/brand"
BRAND_OFF_SENTINEL="none"

# Visible attribution, printed on EVERY invocation — including the introspection
# modes below, so that a probe of stderr is a real probe of the notice. GPL-3.0
# obliges a redistribution to carry its notice, and a NOTICE file nobody reads
# does not discharge that. "built on TollGate" is spelled exactly as in NOTICE.md
# and README.md so the licence gate can assert all three.
printf 'Built on TollGate — Copyright (C) the OpenTollGate contributors. GPL-3.0. See LICENSE and NOTICE.\n' >&2

brand_id() {
    if [ "${TOLLGATE_NO_BRAND:-0}" = "1" ]; then printf '%s' "$BRAND_OFF_SENTINEL"; return; fi
    if [ -n "${TOLLGATE_BRAND:-}" ]; then printf '%s' "$TOLLGATE_BRAND"; return; fi
    if [ -f "${BRAND_DIR}/active" ]; then tr -d '\n\r' < "${BRAND_DIR}/active"; return; fi
    printf '%s' "$BRAND_OFF_SENTINEL"
}

verify_launcher() {
    [ -f "$LAUNCHER" ] || { printf 'ERROR: pinned launcher missing: %s\n' "$LAUNCHER" >&2; exit 1; }
    want="$(awk '/^sha256/ {print $2; exit}' "$PIN_FILE")"
    got="$(sha256sum "$LAUNCHER" | awk '{print $1}')"
    [ "$want" = "$got" ] || { printf 'ERROR: launcher checksum mismatch (pin %s, got %s)\n' "$want" "$got" >&2; exit 1; }
}

# --- one pass over argv: consume this shell's own flags, forward the rest -----
# The introspection flags below are read-only, take no network, and exist so the
# regression test can assert the pass-through PROPERTIES rather than diff text.
MODE=""; BRAND="$(brand_id)"; ARGS=()
while [ "$#" -gt 0 ]; do
    case "$1" in
        --print-launcher-path) MODE="path";  shift ;;
        --print-brand-mode)    MODE="mode";  shift ;;
        --print-command)       MODE="cmd";   shift ;;
        --brand)
            [ -n "${2:-}" ] || { printf 'ERROR: --brand needs an id, or `--brand none`.\n' >&2; exit 1; }
            BRAND="$2"; shift 2 ;;
        *) ARGS+=("$1"); shift ;;
    esac
done

case "$MODE" in
    path) printf '%s\n' "$LAUNCHER"; exit 0 ;;
    mode)
        if [ "$BRAND" = "$BRAND_OFF_SENTINEL" ]; then printf 'brand=%s descriptor=%s\n' "$BRAND" "$BRAND_OFF_SENTINEL"
        else printf 'brand=%s descriptor=%s\n' "$BRAND" "${BRAND_DIR}/${BRAND}.json"; fi
        exit 0 ;;
    cmd)
        printf 'bash\n%s\n' "$LAUNCHER"
        for a in ${ARGS[@]+"${ARGS[@]}"}; do printf '%s\n' "$a"; done
        exit 0 ;;
esac

verify_launcher
# (the attribution notice was printed at the top of this script, on every path)
if [ "$BRAND" = "$BRAND_OFF_SENTINEL" ]; then
    printf 'Brand:  (none — upstream default naming)\n' >&2
    TOLLGATE_NO_BRAND=1 exec bash "$LAUNCHER" ${ARGS[@]+"${ARGS[@]}"}
fi
printf 'Brand:  %s\n' "$BRAND" >&2
TOLLGATE_BRAND="$BRAND" exec bash "$LAUNCHER" ${ARGS[@]+"${ARGS[@]}"}
