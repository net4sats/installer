# BRAND — the input set, and the rule about where it may live

## The rule of record

TollGate is a **protocol**; a brand is a **company**. This repository owns
**identity**, not code. The rendering logic lives upstream. A brand is a
descriptor plus assets, fed to a *slot that upstream already provides* — never a
fork, never a code diff, never a vendor name in the upstream tree.

## The three files that are the brand

| Path | What it is |
|---|---|
| `brand/active` | **which** descriptor is the default. One line, a bare id. This is DATA. |
| `brand/<id>.json` | the `BrandDescriptor` — 10 fields: `id`, `name`, `domain`, `tagline`, `poweredBy`, `website`, `version`, `themeColor`, `sessionKey`, `sessionUser` |
| `brand/assets/{logo,icon}-{colour,white}.png` | the four files the upstream slot's path convention expects |

## Why the id lives in a file rather than in the script

`brand/active` exists so that **no brand literal appears in executable code**.
This is not tidiness — it is the same invariant upstream's rebrand gutter
enforces, and the failure it prevents is specific: a bare literal in a script is
how a second writer for a name gets introduced and fights the first one. A
descriptor is a *value*; only one component may act on it.

`tests/shell/test-debrand-passthrough.sh` scans every executable surface
(`install.sh`, `scripts/**`, `tests/**`) for the brand literal and fails if it
finds one — including in its own source. The scan pattern is a bracket
expression (`net4[s]ats`) so the test can scan itself without matching its own
bytes, and the test carries a composed-at-run-time real match and near-miss as
negative controls, so a scan that matches nothing can never read as a pass.

The scan deliberately **does not** cover `README.md`, `NOTICE`, `docs/**`,
`brand/**` or `REPORT.md`: an operator-facing document must be able to *name* the
brand, and `brand/` *is* the input. That is a decision, not an oversight.

## Adding a brand

```sh
mkdir -p brand/assets          # (only if adding assets for a new id)
cat > brand/<id>.json <<'JSON'
{ "id": "<id>", "name": "...", "domain": "...", "tagline": "...",
  "poweredBy": "...", "website": "https://...", "version": "...",
  "themeColor": "#rrggbb", "sessionKey": "...", "sessionUser": "..." }
JSON
printf '%s\n' '<id>' > brand/active        # make it the default
bash tests/shell/test-debrand-passthrough.sh
```

To ship a brand without making it the default, leave `brand/active` alone and
select it with `--brand <id>`.

## The descriptor fields, and why they are shaped this way

The ten fields mirror upstream's own `REQUIRED_DESCRIPTOR_FIELDS`
(`admin/src/brand-core.ts`), and the id alphabet mirrors upstream's
`scripts/brand-id.mjs` (`^[a-z0-9][a-z0-9._-]*$`). Keeping the shape identical is
the point: this input set is *for* that slot, so it must satisfy it exactly
rather than approximately. `themeColor` is `#rrggbb` because it reaches a browser
`theme-color` meta tag; `sessionKey`/`sessionUser` are the browser storage keys,
which is why a re-brand is what forces them to differ.

## De-branding

`--brand none` (or `TOLLGATE_NO_BRAND=1`) is the de-branded path. It selects
upstream's **default naming** with no brand input set at all — it does not invent
a neutral brand, and it does not silently fall back to the shipped one. The
regression test asserts that in this mode the shell is byte-identical to upstream:
same launcher bytes, same forwarded argv.

## Scope: the admin half only

The brand input set here covers the **installer's** brand selection and mirrors
the rescued overlay set for the **admin** surface of the portal (descriptor +
four logo/icon assets, in the slot convention upstream's `admin/brand/README.md`
documents). The **guest portal** has no brand slot upstream and its brand is baked
into upstream source; it is a separate work package and is **not** attempted here.
