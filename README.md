# installer — a thin branded shell over TollGate

Built on TollGate. TollGate — Copyright (C) the OpenTollGate contributors.
GPL-3.0 (see [LICENSE](LICENSE) and [NOTICE](NOTICE)).

A branded one-line installer for TollGate routers. It is a **thin shell**: it
selects a brand, verifies the installer it is about to run, and hands your command
line to upstream. It implements no business logic of its own.

```sh
curl -fsSL https://net4sats.com/install.sh | sh
```

Then follow the prompts — the wizard serves its UI on `http://localhost:8099` and
deploys TollGate to your router over the network. For an unattended deploy:

```sh
./install.sh <ROUTER_IP> <ROUTER_PASSWORD> <LIGHTNING_ADDRESS>
```

---

## What this repository is (and is not)

**Is:** a brand input, a pin, and ~25 lines of pass-through.

**Is not:** discovery, SSH/host-key trust, deploy, feed resolution, flashing,
identity derivation, or pricing. Every one of those lives in upstream
`OpenTollGate/tollgate-installer` (the wizard) and
`OpenTollGate/tollgate-module-basic-go` (all business logic, on the router), and
is consumed here as a **pinned, byte-verified artifact**. Upstream's own
`AGENTS.md` states the rule this repository obeys:

> TollGate repos are thin UI wrappers. All business logic resides in
> `tollgate-module-basic-go`. The TollGate repos only call backend APIs and render
> results — they do NOT implement or duplicate business logic.

If a change here starts to look like logic, it is drift, and it belongs upstream.

## Two ideas, and nothing else

### 1. The launcher is pinned and verified, never fetched from a branch

`vendor/upstream-install-and-test.sh` is upstream's launcher at a pinned commit.
`scripts/upstream-launcher.sha256` records its sha256. **Every run re-verifies
it** and aborts on a mismatch rather than executing unverified bytes:

```
ERROR: launcher checksum mismatch (pin 7cd397a4…, got …)
```

Upstream's `main` is never the build input. The reasons are in
[docs/PINS.md](docs/PINS.md): the upstream PRs behind the pins are deliberately
unmerged while the operator's release freeze holds, and their *branches* may be
rebased — the *tags* do not move.

### 2. The brand is data, and it never enters your argv

The default brand is the contents of [`brand/active`](brand/active); the identity
is [`brand/net4sats.json`](brand/net4sats.json) (a 10-field descriptor) plus
[`brand/assets/`](brand/assets). No brand literal appears anywhere in the
executable code — `tests/shell/test-debrand-passthrough.sh` fails the build if one
reappears. That is the same invariant upstream's own rebrand gutter enforces, and
it is why the generic path stays generic.

**Why the brand is not a forwarded argument.** Upstream's launcher drains `"$@"`
itself and its argument loop ends in `*) POSITIONAL+=("$1")`. Every token it does
not recognise becomes a positional, and **the first positional is the router IP**.
A wrapper that appended `--brand foo` would have `foo` read as a router address —
a silently wrong deploy target. So `--brand` is consumed *here* and exported in
the environment, and the argv forwarded upstream is byte-identical to what you
typed. `tests/shell/test-debrand-passthrough.sh` asserts exactly that.

## Brand selection

| How | Result |
|---|---|
| *(nothing)* | the brand named by `brand/active` |
| `--brand <id>` | that brand, from `brand/<id>.json` + `brand/assets/` |
| `--brand none` | **de-branded** — upstream's default naming, no brand input set |
| `TOLLGATE_BRAND=<id>` | same as `--brand <id>` |
| `TOLLGATE_NO_BRAND=1` | same as `--brand none` |

```sh
curl -fsSL https://net4sats.com/install.sh | sh -s -- --brand none
```

The de-branded path is the important one and the reason the regression test exists:
with no brand selected this shell must be **indistinguishable from upstream** — same
bytes, same argv, not a "similar" script.

## Layout

```
install.sh                       the whole shell (~25 lines of logic)
vendor/upstream-install-and-test.sh   upstream's launcher, pinned
scripts/upstream-launcher.sha256      its recorded sha256 (verified every run)
pins.tsv                         every pinned upstream ref + commit (DATA)
scripts/build-pinned-upstream.sh compose + verify + build the pinned upstream
brand/active                     which descriptor is the default (DATA)
brand/<id>.json + brand/assets/  the brand input set
tests/shell/                     the gates (no network, no router, no Go)
docs/                            PINS, BRAND, VALIDATION, ARCHITECTURE
```

## Build, and the gates

Nothing here needs a router, a network, or a compiler:

```sh
bash tests/shell/test-debrand-passthrough.sh    # no-brand path stays byte-identical
bash tests/shell/test-licence-attribution.sh    # GPL-3.0 obligations are enforced
```

Rebuilding the pinned upstream — fetches the pins cold, re-checks that they are
mutually independent, composes them, asserts the composed tree still carries every
fix, then builds and tests it:

```sh
bash scripts/build-pinned-upstream.sh           # needs git + go
```

The composition recipe, the independence trap, and the observed results are in
[docs/PINS.md](docs/PINS.md). What was measured, and what was *not*, is in
[docs/VALIDATION.md](docs/VALIDATION.md).

## The guest portal is out of scope

This repository brands the **installer**. The captive portal is a separate
work package and is deliberately **not** attempted here — upstream's brand slot
covers the admin surface, and the guest portal still has its brand baked into
upstream source. Do not add portal code to this repo.

## Licence

GPL-3.0. The upstream copyright is intact and is not replaced by anything here:
all TollGate code, including the UI this shell serves, remains the copyright of
the OpenTollGate contributors. The exact upstream commits are recorded in
`pins.tsv`, and `scripts/build-pinned-upstream.sh` rebuilds them, so the
Corresponding Source required by GPL-3.0 §6 is reproducible from this repository.

net4sats is an independent distribution. It is not affiliated with, endorsed by,
or an official release of the OpenTollGate project; "TollGate" is used only to
describe the origin of the software.
