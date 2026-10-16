# ARCHITECTURE — a shell, a pin, and a boundary

## The one diagram

```
  your terminal
        │  curl … | sh    (or ./install.sh <IP> <PW> <LN-ADDRESS>)
        ▼
  install.sh ──────────────────────────────────────────────────────────────
   1. brand_id()          brand/active  →  $BRAND        (DATA, never a literal)
   2. verify_launcher()   vendor/… .sh  vs  scripts/upstream-launcher.sha256
   3. consume --brand, forward every other argv token verbatim
   4. exec bash vendor/upstream-install-and-test.sh "$@"
  ──────────────────────────────────────────────────────────────────────────
        │  the operator's own argv, unmodified
        ▼
  vendor/upstream-install-and-test.sh   ← upstream's launcher, PINNED
        │  detects OS/arch, resolves the installer tag, downloads the binary
        ▼
  tollgate-installer  (upstream, from upstream's release assets)
        │  serves a UI on :8099; given a router IP it deploys headlessly
        ▼
  your router
```

## The boundary, stated as a rule

Everything **below** the dashed line belongs to upstream. Everything **above** it
is this repository: brand selection, pin verification, argv pass-through.

| Concern | Owner | In this repo? |
|---|---|---|
| Router discovery (ARP scan, TCP probe) | upstream installer | **no** |
| SSH / host-key trust / known-hosts | upstream installer | **no** |
| Deploy, rollback, transport re-acquire | upstream installer | **no** |
| Feed resolution; per-arch asset selection | upstream installer + the feed | **no** |
| Flashing firmware | upstream installer | **no** |
| Identity derivation (IPv4, MAC, BIP39) | `tollgate-module-basic-go` | **no** |
| Pricing, payments, Cashu/Lightning | `tollgate-module-basic-go` | **no** |
| Brand identity (descriptor + assets) | **this repo** | **yes** |
| Which upstream commit is trusted | **this repo** | **yes** |
| The one-line entry point | **this repo** | **yes** |

Upstream states the same rule for its own repos, and this repository is held to
it verbatim: *a TollGate repo is a thin UI wrapper; it calls backend APIs and
renders results; it does not implement or duplicate business logic.*

## Why a wrapper at all, instead of a fork

A fork would re-introduce exactly the divergence this exists to remove: two
copies of a wizard to keep in step, and every upstream fix landing in only one of
them. The shell approach means an upstream fix reaches users by **re-pointing a
pin**, with no merge.

It also means the shell has almost nothing to break. What it *can* break is the
two things the tests pin down:

1. **The pin.** A launcher that is fetched from a branch, or a copy that was
   quietly edited, would mean the verified bytes are not the executed bytes.
   Hence: hash on every run, and `vendor/` compared against the pin in CI.
2. **The pass-through.** A shell that altered argv would deploy to the wrong
   target or drop an operator's flag. Hence: argv asserted verbatim, and asserted
   *unchanged* by brand selection.

## Why the brand is an environment input, not an argument

This is the least obvious decision here, so it is written down twice (see also
README §"Two ideas").

Upstream's launcher drains `"$@"` itself. Its argument loop ends in
`*) POSITIONAL+=("$1")`, and the **first positional is the router IP**:

```sh
while [ $# -gt 0 ]; do
    case "$1" in
        --tag) … ;;  --channel) … ;;  # … recognised flags
        *)     POSITIONAL+=("$1"); shift ;;   # EVERYTHING else is a positional
    esac
done
```

So a wrapper that appended `--brand foo` would have `foo` read as a router
address. That is a *silent* wrong-target deploy — strictly worse than a failure.
Therefore `--brand` is consumed at the top, the brand is exported as
`TOLLGATE_BRAND`, and the forwarded argv is exactly what the operator typed. The
regression test asserts the equality, and a control asserts the brand is still
observable elsewhere (so the equality cannot pass for a shell that ignores its
input entirely).

## Failure modes, and the intended behaviour of each

| Failure | Behaviour | Enforced by |
|---|---|---|
| `vendor/` edited or missing | abort before executing anything, printing both hashes | `verify_launcher()` |
| pin record absent/empty | abort (`sha256` comparison cannot pass vacuously) | `verify_launcher()` |
| a pinned tag moved on the remote | `build-pinned-upstream.sh` fails; instructs a new `-2` tag | build script §0 |
| pins no longer mutually independent | build refuses to compose (would double-apply) | build script §2 |
| composition loses a fix | build fails on content assertions, not exit status | build script §4 |
| a brand literal reappears in code | CI fails, naming the file | de-brand test §C |
| brand selected but not observable | the test's control fails (not the assertion) | de-brand test §B |
| `--brand` with no value | exit 1 with a message, never a silent fallback | `install.sh` |
| upstream suite flaky under load | a suite failure is fatal **only** if it also fails in isolation | build script §5 |

## What must never be added here

- Any router interaction beyond exec'ing the pinned launcher.
- Any second writer of a brand-derived name.
- Any brand literal in executable code, including as a default.
- Any fetch of upstream at `main`, `latest`, or a branch tip.
- Any portal code — the guest portal is a separate work package.

A change that looks like one of these is drift. It belongs upstream as a PR, or
it does not belong.
