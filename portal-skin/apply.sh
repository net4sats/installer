#!/usr/bin/env bash
# Apply the net4sats skin to an upstream portal checkout, then the caller builds with
# VITE_BRAND=net4sats. Kept OUTSIDE the upstream tree: tests/unit/brand.test.js asserts
# the upstream slot holds only the generic default, so this overlay is an INPUT, never
# a committed change to upstream.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
TREE="${1:?usage: apply.sh <upstream-checkout>}"
BRAND_ID="${BRAND_ID:-net4sats}"
cp "$HERE/admin-brand/$BRAND_ID.json"                 "$TREE/admin/brand/$BRAND_ID.json"
mkdir -p "$TREE/admin/public/assets/brand/$BRAND_ID"
cp "$HERE/admin-public-assets/brand/$BRAND_ID/"*.png  "$TREE/admin/public/assets/brand/$BRAND_ID/"
echo "applied skin '$BRAND_ID' to $TREE"
