#!/usr/bin/env bash
# RED: the launcher checksum must verify on macOS, which does not ship sha256sum.
#
# macOS has `shasum -a 256` (perl) and `openssl dgst -sha256`, but NOT coreutils'
# sha256sum. install.sh calls sha256sum unconditionally, so a piped install on a Mac
# fails INSIDE verify_launcher with "sha256sum: command not found" — and because the
# failure happens inside a $( ), the script's own error handling shows only a confusing
# checksum mismatch, not the real cause.
#
# This test creates a PATH where sha256sum is ABSENT and asserts verification still
# succeeds through a fallback.
set -u
cd "$(dirname "$0")/../.." || exit 1

pass=0; fail=0
say()   { printf '%s\n' "$*"; }
ok()    { pass=$((pass+1)); say "ok   - $*"; }
not_ok(){ fail=$((fail+1)); say "not_ok - $*"; }

# Build a restricted PATH with core tools but NO sha256sum. We provide shasum as a
# stand-in for the macOS tool (same output format as sha256sum for the first field).
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT INT TERM
for tool in sh bash cat curl tr awk grep sed mktemp printf dirname; do
    src="$(command -v "$tool" 2>/dev/null)" && ln -sf "$src" "$SANDBOX/$tool"
done
# macOS-shaped shasum: print "<hash>  <file>" exactly like sha256sum
real_shasum="$(command -v shasum 2>/dev/null || true)"
if [ -n "$real_shasum" ]; then
    ln -sf "$real_shasum" "$SANDBOX/shasum"
else
    # no shasum on this Linux box: emulate it with sha256sum (same output shape)
    real_sum="$(command -v sha256sum)"
    printf '#!/bin/sh\nexec %s "$@"\n' "$real_shasum" > "$SANDBOX/shasum"
    chmod +x "$SANDBOX/shasum"
fi

# sanity: sha256sum really is absent in the sandbox
if PATH="$SANDBOX" command -v sha256sum >/dev/null 2>&1; then
    not_ok "sandbox still exposes sha256sum — test is vacuous"
    say ""; say "pass=${pass} fail=${fail}"; exit 1
else
    ok "sandbox hides sha256sum (macOS-like PATH)"
fi

OUT="$(cd . && PATH="$SANDBOX" bash ./install.sh --print-launcher-path 2>&1 || true)"
if printf '%s' "$OUT" | grep -q 'vendor/upstream-install-and-test.sh'; then
    ok "verification succeeds without sha256sum (fallback engaged)"
else
    not_ok "verification failed on a macOS-like PATH: $(printf '%s' "$OUT" | tail -1)"
fi

say ""
say "pass=${pass} fail=${fail}"
[ "$fail" -eq 0 ]
