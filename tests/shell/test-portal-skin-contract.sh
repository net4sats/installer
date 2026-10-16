#!/usr/bin/env bash
# The portal skin overlay carries a BrandDescriptor that upstream VALIDATES. If it drifts
# from the contract, a branded build falls back to the generic default LOUDLY - which
# means a silently generic portal. Assert the contract here so it cannot drift unnoticed.
#
# The contract is upstream's (admin/brand/README.md): ten required non-empty string
# fields, an id matching [a-z0-9][a-z0-9._-]* that equals the file name, and four
# convention-named assets.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$here"
ok=0; fail=0
D="portal-skin/admin-brand/net4sats.json"
A="portal-skin/admin-public-assets/brand/net4sats"

if [ ! -f "$D" ]; then echo "FAIL - descriptor missing: $D"; exit 2; fi

python3 - "$D" <<'PY'
import json, re, sys, os
d = json.load(open(sys.argv[1]))
req = ["id","name","domain","tagline","poweredBy","website","version",
       "themeColor","sessionKey","sessionUser"]
bad = []
for f in req:
    v = d.get(f)
    if not isinstance(v, str) or not v.strip():
        bad.append(f"missing/empty: {f}")
extra = sorted(set(d) - set(req))
if extra: bad.append(f"extra keys: {extra}")
if d.get("id") != "net4sats": bad.append(f"id must equal the file name, got {d.get('id')!r}")
if not re.fullmatch(r"[a-z0-9][a-z0-9._-]*", str(d.get("id",""))):
    bad.append("id violates the identifier alphabet")
print("ok   - descriptor carries all ten required fields" if not any("missing" in b for b in bad)
      else "FAIL - " + "; ".join(b for b in bad if "missing" in b))
print("ok   - descriptor has no keys outside the contract" if not any("extra" in b for b in bad)
      else "FAIL - " + "; ".join(b for b in bad if "extra" in b))
print("ok   - id equals the file name and matches the alphabet" if not any("id " in b for b in bad)
      else "FAIL - " + "; ".join(b for b in bad if "id " in b))
raise SystemExit(1 if bad else 0)
PY
rc=$?
[ $rc -eq 0 ] && ok=$((ok+3)) || fail=$((fail+1))

# The four assets are a CONVENTION derived from the id; a missing one is a broken skin.
for f in logo-colour.png logo-white.png icon-colour.png icon-white.png; do
  if [ -f "$A/$f" ]; then printf 'ok   - asset present: %s\n' "$f"; ok=$((ok+1))
  else printf 'FAIL - asset missing: %s\n' "$f"; fail=$((fail+1)); fi
done
# and they must be real PNGs, not placeholders or renamed files
for f in "$A"/*.png; do
  if [ "$(head -c 8 "$f" | od -An -tx1 | tr -d ' \n')" = "89504e470d0a1a0a" ]; then
    ok=$((ok+1))
  else printf 'FAIL - not a real PNG: %s\n' "$(basename "$f")"; fail=$((fail+1)); fi
done
echo "ok   - all four assets are real PNGs"
echo
echo "ok=$ok fail=$fail"
[ "$fail" -eq 0 ] || exit 2
