#!/usr/bin/env bash
# RED: platform detection must survive a busybox tr (OpenWrt) environment.
#
# busybox tr does NOT support character classes. `tr '[:upper:]' '[:lower:]'` maps the
# literal character SET {[, :, u, p, e, r} pairwise onto {[, :, l, o, w, e} — so the
# 'u' in "Linux" becomes 'l' and the platform string is "Linlx-arm64". Every
# OpenWrt/busybox user hits this: the installer then 404s on a release asset that
# does not exist (tollgate-installer-Linlx-arm64).
#
# This test emulates the busybox behaviour exactly (sed-based lowercase would also
# work; the point is the SCRIPT must not depend on tr character-class support).
set -u
cd "$(dirname "$0")/../.." || exit 1

pass=0; fail=0
say()   { printf '%s\n' "$*"; }
ok()    { pass=$((pass+1)); say "ok   - $*"; }
not_ok(){ fail=$((fail+1)); say "not_ok - $*"; }

# Extract the detect_platform function from the vendored launcher and run it with a
# hostile uname+tr, asserting the PLATFORM it composes.
VENDOR=vendor/upstream-install-and-test.sh
[ -f "$VENDOR" ] || { say "missing $VENDOR"; exit 1; }

# busybox-shaped tr: reproduce the observed mangling (classes unsupported -> pairwise set map)
BBTR="$(mktemp)"
cat > "$BBTR" <<'EOF'
#!/bin/sh
# busybox: '[:upper:]'/'[:lower:]' are literal char sets, mapped pairwise
[ "$1" = "[:upper:]" ] && [ "$2" = "[:lower:]" ] && exec sed -e 's/u/l/g'
exec /usr/bin/tr "$@"
EOF
chmod +x "$BBTR"

SANDBOX="$(mktemp -d)"
cp "$(command -v uname)" "$SANDBOX/uname" 2>/dev/null || true
# fake uname that reports like OpenWrt busybox: Linux / aarch64
cat > "$SANDBOX/uname" <<'EOF'
#!/bin/sh
[ "$1" = "-s" ] && { echo Linux; exit 0; }
[ "$1" = "-m" ] && { echo aarch64; exit 0; }
exec /usr/bin/uname "$@"
EOF
chmod +x "$SANDBOX/uname"

# pull ONLY detect_platform out of the vendor script and source it
sed -n '/^detect_platform()/,/^}/p' "$VENDOR" > "$SANDBOX/dp.sh"

OUT="$(cd "$SANDBOX" && PATH="$SANDBOX:$PATH" TR="$BBTR" sh -c '
  tr() { "$TR" "$@"; }
  . "$0/dp.sh"
  detect_platform
  printf "%s" "$PLATFORM"
' "$SANDBOX" 2>&1)"

if [ "$OUT" = "linux-arm64" ]; then
    ok "busybox tr yields linux-arm64 (got: $OUT)"
else
    not_ok "busybox tr yields linux-arm64 (got: '$OUT' — asset would 404)"
fi

say ""
say "pass=${pass} fail=${fail}"
[ "$fail" -eq 0 ]
