# CONTRIBUTING — the working agreement for this repository

Inherits the fleet working agreement. This file adds only what is specific to a
**thin branded shell**.

> Note: this content was intended for `AGENTS.md` at the repository root, but
> writes to agent-instruction files are gated and the approval did not come
> through in this session. It lives here, fully intact, so it is not lost. A
> maintainer may move it to `AGENTS.md` after review — an agent must not.

## The one rule

**This repository implements no business logic.** It selects a brand, verifies a
pin, and forwards argv. Everything else is upstream:

- router discovery, SSH/host-key trust, deploy, rollback, feed resolution,
  flashing → `OpenTollGate/tollgate-installer`
- identity derivation (IPv4/MAC/BIP39), pricing, payments →
  `OpenTollGate/tollgate-module-basic-go`

Upstream states the same rule for its own repos, and it is binding here verbatim:

> TollGate repos are thin UI wrappers. All business logic resides in
> `tollgate-module-basic-go`. The TollGate repos only call backend APIs and render
> results — they do NOT implement or duplicate business logic.
> If you find yourself writing more logic than API-call-and-render, stop and
> reconsider whether it belongs in the backend instead.

**If you are about to write logic, stop.** Either it is a brand default (→ data in
`brand/`), or it is an upstream change (→ a PR to the upstream repo, not a local
bypass). There is no third option, and "just for now" is how a shell becomes a
fork.

## Non-negotiables

1. **Never build from `main`, `latest`, or a branch tip.** Pins only, recorded in
   `pins.tsv`. Never force-push, delete or re-point a `net4sats-pin/*` tag — cut a
   new `-2` tag instead. See `docs/PINS.md`.
2. **Never put the brand literal in executable code**, not even as a default. It
   is data in `brand/active`. `tests/shell/test-debrand-passthrough.sh` enforces
   this, and it scans itself.
3. **Never forward a brand flag to upstream's launcher.** Its arg loop ends in
   `*) POSITIONAL+=("$1")` and the first positional is the ROUTER IP, so a
   forwarded flag becomes a wrong deploy target. The brand is an environment
   input; `--brand` is consumed here.
4. **The no-brand path must stay byte-identical to upstream.** Same bytes, same
   argv. That is the property the regression test exists to protect.
5. **Never add portal code.** The guest portal is a separate work package; its
   brand is baked into upstream source and upstream has no slot for it yet.
6. **Never weaken a gate to make a change pass.** The build script's flake rule
   (a suite failure is fatal only if it also fails in isolation) is the *only*
   permitted concession; widen it and you are hiding real failures.
7. **Keep GPL-3.0 obligations intact**: verbatim `LICENSE`, intact upstream
   copyright, visible "built on TollGate" credit at run time and in `README.md`.
   `tests/shell/test-licence-attribution.sh` enforces all three.

## Definition of done

Code/risky tasks — the hard gate — may not be marked done until all hold:

1. A failing test first (TDD), then the change.
2. `tests/shell/test-debrand-passthrough.sh` and
   `tests/shell/test-licence-attribution.sh` both PASS.
3. `scripts/build-pinned-upstream.sh` PASSes if the change touches the pin,
   `vendor/`, or the brand.
4. Cold cross-family review with no prior context returns APPROVED.
5. Consolidated and pushed.

Docs/light tasks: the gates still run; review is advisory.

## Commands

```sh
bash tests/shell/test-debrand-passthrough.sh   # the de-brand gate (21 assertions)
bash tests/shell/test-licence-attribution.sh   # the GPL gate
bash scripts/build-pinned-upstream.sh          # pin fetch + compose + build (needs git+go)
```

Run the gates from any directory; each takes the tree as an optional `$1`.
`.github/workflows/gates.yml` runs both on every push.

## Commits

Conventional commits, atomic — one concern per commit. This repository is
GPL-3.0; do not commit secrets or binary blobs. `vendor/` holds one upstream shell
script, pinned by hash, and that is the only vendored file.

## Escalation

If a task needs something this repository must not contain, it is an upstream PR
(the pins exist precisely so a shell can consume unmerged work without waiting),
or a new work package. Do not solve it locally.
