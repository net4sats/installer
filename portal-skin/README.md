# net4sats portal skin overlay

**What this is.** The net4sats brand inputs for the TollGate captive-portal build. It is
an **overlay**, applied to an upstream checkout at build time — deliberately NOT a
committed change to upstream.

**Why not just PR the descriptor upstream.** We tried; the upstream test suite refused it,
correctly:

```
tests/unit/brand.test.js
  "the shipped brand slot bundles exactly the generic default descriptor
   and no distribution skin"
  // Anti-leak regression test: this repo is the protocol side. The slot may
  // only ever contain the generic default; an operator onboards by shipping
  // its own descriptor from its own distribution repo (issue #33).
```

That test is the architecture, not an obstacle: the repo carries the protocol and the
generic default; a distributor ships its own skin from its own repo. Committing
`net4sats.json` upstream would fail CI by design.

## Contents

```
admin-brand/net4sats.json                       the BrandDescriptor (10 required fields)
admin-public-assets/brand/net4sats/             the 4 required PNGs
  logo-colour.png  logo-white.png
  icon-colour.png  icon-white.png
apply.sh                                        copies both into place
```

## Usage

```sh
git clone https://github.com/OpenTollGate/tollgate-captive-portal-site
cd tollgate-captive-portal-site

/path/to/portal-overlay/apply.sh "$PWD"

VITE_BRAND=net4sats npm run build
```

`apply.sh` takes the checkout path as its only argument. Set `BRAND_ID` to install a
different skin from this overlay.

## What this brands, and what it does NOT

**Brands — verified in a real build:**

| Artifact | Value |
|---|---|
| `build/admin/manifest.json` | `name: "net4sats"`, `short_name: "net4sats"` |
| admin bundle | carries `net4sats`, `Powered by net4sats`, `net4sats.lan`, `net4sats_session`, theme `#f7931a` |

**Does NOT brand — measured:**

| Artifact | Value | Why |
|---|---|---|
| `build/manifest.json` (guest) | `name: "Tollgate Captive Portal"` | static file |
| `public/locales/en.json` | `"powered_by": "Powered by <1>TollGate</1>"` | static strings |
| `src/assets/logo/TollGate_Logo-*.png` | TollGate marks | static assets |

The brand slot drives the **admin** app. `scripts/build-all.mjs` says so itself: *"The
active descriptor drives the generated PWA manifest for the admin app."* The guest portal
takes its visible wording from `public/locales/en.json` (one locale, `en`), which has the
TollGate strings baked in and no brand input.

So a guest-only deployment still reads "Powered by TollGate" on the captive page. Closing
that needs a **guest-side brand input** contributed upstream — an env-driven
locale/logo overlay defaulting to the current strings so the unbranded path stays
byte-identical. Same shape as the token param and the asset slot.

## Verifying a build

```sh
# the admin skin took
python3 -c "import json;d=json.load(open('build/admin/manifest.json'));print(d['name'],d['short_name'])"
grep -rl net4sats build/admin/ | head

# and the guest did NOT (expected until the guest input exists)
python3 -c "import json;d=json.load(open('build/manifest.json'));print(d['name'])"
```

## Provenance

The descriptor and all four assets come from the rescued portal overlay work
(`net4sats/tollgate-captive-portal-site` PR #2, fork branches since deleted) preserved as
tags on `felixfelix-bot/tollgate-captive-portal-site`:

| Tag | Commit |
|---|---|
| `rescue/pr2-theme-overlay` | `1c43361303f4729aa07d9eb8c2b307775f50b457` |
| `rescue/pr1-portal-reverse-sync` | `54ea2de5670a2ebca508938c6597d74e27632922` |

The descriptor satisfied all ten contract fields with zero extras, checked field by field
rather than assumed.
