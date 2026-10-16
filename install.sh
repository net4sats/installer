#!/bin/sh
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

# Resolve where our supporting files live.
#
# FROM DISK: they sit next to this script, so $0 gives us the directory.
# FROM STDIN (`curl ... | sh`): $0 is the shell itself, not this file, so there is
# no disk layout to use and we must FETCH the launcher instead. Without this branch
# `dirname "$0"` silently resolves ROOT to the CALLER'S cwd, the script finds no
# vendor/, and it exits 0 with no output — a silent no-op under the exact shape the
# README advertises.
if [ -f "$0" ] && [ -r "$0" ]; then
    ROOT="$(cd "$(dirname "$0")" && pwd)"
    LAUNCHER="${ROOT}/vendor/upstream-install-and-test.sh"
    PIN_FILE="${ROOT}/scripts/upstream-launcher.sha256"
else
    ROOT=""
    LAUNCHER=""
    PIN_FILE=""
    # Where to fetch the launcher from when we were piped in. Taken from the
    # environment so this script carries NO brand literal: the de-brand invariant
    # says the brand is DATA (brand/active), never spelled into executable code.
    # The slug is DATA: it lives in the brand descriptor (brand/<id>.json) or in
    # N4S_REPO_SLUG. Piped callers get it from the descriptor we can fetch first,
    # so this script never spells a brand into executable code.
    _SLUG="${N4S_REPO_SLUG:-}"
    if [ -z "$_SLUG" ]; then
        _SLUG="${N4S_DEFAULT_SLUG:-}"
    fi
    if [ -z "$_SLUG" ]; then
        printf 'ERROR: piped install needs N4S_REPO_SLUG=<owner>/<repo> (or N4S_REPO_URL).\n' >&2
        printf '       e.g.  curl -sL https://raw.githubusercontent.com/<owner>/<repo>/main/install.sh | N4S_REPO_SLUG=<owner>/<repo> sh\n' >&2
        printf '       Or run the script from a clone, where vendor/ is present locally.\n' >&2
        exit 1
    fi
    _RAW_BASE="${N4S_REPO_URL:-https://raw.githubusercontent.com/${_SLUG}/main}"
fi

BRAND_DIR="${ROOT:+${ROOT}/brand}"
BRAND_OFF_SENTINEL="none"

# Visible attribution, printed on EVERY invocation — including the introspection
# modes below, so that a probe of stderr is a real probe of the notice. GPL-3.0
# obliges a redistribution to carry its notice, and a NOTICE file nobody reads
# does not discharge that. "built on TollGate" is spelled exactly as in NOTICE.md
# and README.md so the licence gate can assert all three.
printf 'Built on TollGate — Copyright (C) the OpenTollGate contributors. GPL-3.0. See LICENSE and NOTICE.\n' >&2

# POSIX-safe single-quoting, so forwarded args survive the shell round trip.
_posix_quote() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\''/g")"; }

brand_id() {
    if [ "${TOLLGATE_NO_BRAND:-0}" = "1" ]; then printf '%s' "$BRAND_OFF_SENTINEL"; return; fi
    if [ -n "${TOLLGATE_BRAND:-}" ]; then printf '%s' "$TOLLGATE_BRAND"; return; fi
    if [ -f "${BRAND_DIR}/active" ]; then tr -d '\n\r' < "${BRAND_DIR}/active"; return; fi
    printf '%s' "$BRAND_OFF_SENTINEL"
}

# The recorded launcher digest. When we have a repo on disk it lives in
# scripts/upstream-launcher.sha256; when piped, it is embedded below so the pin is
# enforced identically in both cases (the value is asserted equal to the file's by
# tests/shell/test-posix-invocation.sh, so the two can never drift silently).
LAUNCHER_SHA_EMBEDDED="7cd397a4102dd9cc522fdecc13292aad5c00ae290b5148187451c350c6453e21"

resolve_launcher() {
    # Piped case: fetch the pinned launcher, still checksum-verified.
    if [ -z "$LAUNCHER" ]; then
        _tmp="$(mktemp)"
        trap 'rm -f "$_tmp"' EXIT INT TERM
        curl -fsSL "${_RAW_BASE}/vendor/upstream-install-and-test.sh" -o "$_tmp" \
            || { printf 'ERROR: could not fetch the pinned launcher from %s\n' "$_RAW_BASE" >&2; exit 1; }
        LAUNCHER="$_tmp"
    fi
}

verify_launcher() {
    resolve_launcher
    [ -f "$LAUNCHER" ] || { printf 'ERROR: pinned launcher missing: %s\n' "$LAUNCHER" >&2; exit 1; }
    if [ -n "$PIN_FILE" ] && [ -f "$PIN_FILE" ]; then
        want="$(awk '/^sha256/ {print $2; exit}' "$PIN_FILE")"
    else
        want="$LAUNCHER_SHA_EMBEDDED"
    fi
    got="$(sha256sum "$LAUNCHER" | awk '{print $1}')"
    [ "$want" = "$got" ] || { printf 'ERROR: launcher checksum mismatch (pin %s, got %s)\n' "$want" "$got" >&2; exit 1; }
    printf '%s' "$want" > "${TMPDIR:-/tmp}/.n4s-pin.$$"
}

# --- one pass over argv: consume this shell's own flags, forward the rest -----
# The introspection flags below are read-only, take no network, and exist so the
# regression test can assert the pass-through PROPERTIES rather than diff text.
MODE=""; BRAND="$(brand_id)"; ARGS=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --print-launcher-path) MODE="path";  shift ;;
        --print-brand-mode)    MODE="mode";  shift ;;
        --print-command)       MODE="cmd";   shift ;;
        --brand)
            [ -n "${2:-}" ] || { printf 'ERROR: --brand needs an id, or `--brand none`.\n' >&2; exit 1; }
            BRAND="$2"; shift 2 ;;
        *) ARGS="$ARGS $(_posix_quote "$1")"; shift ;;
    esac
done

case "$MODE" in
    path)
        verify_launcher
        # When piped, $LAUNCHER is a verified temp copy; also report the canonical
        # repo path so a caller can pin against something stable.
        if [ -n "$ROOT" ]; then printf '%s\n' "$LAUNCHER"
        else printf '%s\n' "${_RAW_BASE}/vendor/upstream-install-and-test.sh"; fi
        exit 0 ;;
    mode)
        if [ "$BRAND" = "$BRAND_OFF_SENTINEL" ]; then printf 'brand=%s descriptor=%s\n' "$BRAND" "$BRAND_OFF_SENTINEL"
        else printf 'brand=%s descriptor=%s\n' "$BRAND" "${BRAND_DIR}/${BRAND}.json"; fi
        exit 0 ;;
    cmd)
        verify_launcher
        printf 'bash\n%s\n' "$LAUNCHER"
        eval "for a in $ARGS; do printf '%s\\n' \"\$a\"; done"
        exit 0 ;;
esac

verify_launcher
# (the attribution notice was printed at the top of this script, on every path)
if [ "$BRAND" = "$BRAND_OFF_SENTINEL" ]; then
    printf 'Brand:  (none — upstream default naming)\n' >&2
    TOLLGATE_NO_BRAND=1 eval "exec bash \"$LAUNCHER\" $ARGS"
fi
printf 'Brand:  %s\n' "$BRAND" >&2
TOLLGATE_BRAND="$BRAND" eval "exec bash \"$LAUNCHER\" $ARGS"
