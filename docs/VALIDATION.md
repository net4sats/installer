# VALIDATION — what was measured, and what was not

Honesty section first, because a validation document that overstates is worse
than none. Everything below is an observation made on 2026-10-16 on the build
host; nothing is projected.

## Status

| Item | State |
|---|---|
| Repository exists at `net4sats/installer` | ✅ created public, default branch `main` |
| Wrapper, pin, brand inputs, tests, docs | ✅ complete on `main` |
| De-brand regression test | ✅ written RED first, now PASS (21 assertions) |
| Licence-attribution test | ✅ PASS (17 assertions) |
| Pin-based build + composition | ✅ executed; `go build` exit 0; all fixes present |
| Push, and proof by `ls-remote` | ✅ pushed; remote tip == local HEAD, verified by `ls-remote` and by the API |
| CI | ✅ ran and passed — run `38970271526`, all gate steps `success` |

### The repo, and the rights to push to it

`net4sats/installer` was created public with `main` as the default branch, and the
account pushing here holds admin on it. Verified from the API, not from a note:

```
$ gh api user -q .login
felixfelix-bot

$ gh api repos/net4sats/installer -q '"\(.full_name) private=\(.private) default=\(.default_branch) created=\(.created_at)"'
net4sats/installer private=false default=main created=2026-10-16T21:03:38Z

$ gh api repos/net4sats/installer -q '"admin=\(.permissions.admin) push=\(.permissions.push) pull=\(.permissions.pull)"'
admin=true push=true pull=true

$ gh api user/memberships/orgs/net4sats -q '"state=\(.state) role=\(.role)"'
state=active role=member
```

**An earlier revision of this document recorded a blocker.** It is kept here
because it is part of the record, not because it still holds: at the time,
`gh repo create net4sats/installer` failed and every existing `net4sats` repo
reported `push:false` for this account, so this document said the repository could
not be created and nothing was pushed. It was later created, this account was
added to the organisation as an active member (the org sets
`members_can_create_repositories=true`, so member rights suffice — owner was not
required), and the tree pushed. **The stale claim is corrected above rather than
quietly deleted**, because a validation document that silently rewrites its own
history is worth less than one that shows what changed.

## What WAS measured

### The pins are live and unmoved

```
net4sats-pin/installer-comfast          b042a23964256e65e83a22c19949117bd5210926
net4sats-pin/installer-gateway-domain   a72a4f6698f77fa1b0637723867b02316ab0d13d
net4sats-pin/installer-rebrand-gutter   049b68918684d640bb4d464869c29369b62a50d2
net4sats-pin/module-ssid-bang           41ada96054bd5394718240d6ec9b43f39a909c12
```

Every one resolves on the remote and matches `pins.tsv`. Verified by
`git ls-remote --tags`, cold, against an empty repository.

### The independence trap is real and is re-checked, not assumed

The three installer pins are mutually independent, and do not share a base:

| Pin | base |
|---|---|
| `installer-comfast` | `5df4c9c` |
| `installer-gateway-domain` | `346e473` |
| `installer-rebrand-gutter` | `b26c2b9` |

`git merge-base --is-ancestor` was run in **both directions for all six ordered
pairs**: all six report "not an ancestor". So no pin contains another, and
composing them is a genuine cherry-pick rather than a fast-forward.

### Composition succeeds with no conflicts, and the composed tree carries every fix

```
== 3. compose all installer pins onto release/pinned-upstream
ok   - based on installer-comfast (b042a2396425)
ok   - cherry-picked 346e47362147..installer-gateway-domain -> 8abff3696a36
ok   - cherry-picked b26c2b96aa18..installer-rebrand-gutter -> 45836a5b0bc4

== 4. the composed tree still carries every pinned fix
ok   - gatewaydomainname re-arm ABSENT from internal/app/deploy.go (want 0, got 0)
ok   - cf-wr632ax present in internal/app/images.go (want >0, got 5)
ok   - the rebrand-literal gutter test is present in the composed tree (1 file)

== 5. go build ./... exit 0
```

`go build ./...` observed at **exit 0**. Both cherry-picks applied clean.

### `go test` is FLAKY upstream — and that is measured, not excused

| Run | Tree | Result |
|---|---|---|
| 1 | composed | `go test ./... -count=1` **exit 0** — whole suite green in 145 s |
| 2 | composed | FAIL: `TestTrustPreflightSequenceOverHTTP` (HTTP context deadline exceeded) |
| — | composed, that test alone, `-count=4` | **exit 0** |
| — | **BASE PIN alone**, unmodified, full suite | FAIL: `TestPrivateBridgeMoveNeverDialsTheRelocatedBridgeAddress` |

The failing file `internal/app/deploy_trust_preflight_test.go` is
**byte-identical** (`6fe4260cf8bddc37`) at all three pins *and* in the composed
tree, and is **untouched by either composition commit**. The base pin failing a
*different* test under the same load is what rules out composition as the cause.

Consequence, and it is a design decision rather than a caveat: the build script
treats a suite failure as fatal **only if the failing test also fails in
isolation**. A test that passes alone but fails in the suite is reported as a load
flake. The flake is upstream's, and re-pointing a pin is not a fix for it.

### The no-brand path, asserted rather than asserted-by-eye

`tests/shell/test-debrand-passthrough.sh` — **21 assertions, PASS**. It was
written **RED first**, and the RED runs are kept as evidence of what it catches:

1. With `install.sh` absent: `RESULT: FAIL (missing artifacts…)`, rc=2.
2. With a deliberately-branded stub (brand as a code literal, `--brand foo`
   appended to argv): **13 assertions failed**, including
   `the brand reached the forwarded argv — upstream would read it as the ROUTER IP`
   and `brand literal on an executable surface: install.sh`.

A first draft of the test also failed its own negative control
(`scan pattern does NOT match a real literal`) — a `printf` format-string bug in
the control, caught by the control. That is recorded here because it is the
argument for having the control: a tree-scan that matches nothing is
indistinguishable from a clean tree.

What the test proves, positively:

- the vendored launcher, the recorded pin and `--print-launcher-path` all agree
  on one sha256;
- the forwarded argv is `bash <launcher> --one --two=three 'four five'` — argv[0]
  is `bash`, order preserved, and a token containing a space survives verbatim;
- **selecting a brand leaves that argv byte-identical**, and it carries no
  `--brand` token — the hazard guard for upstream's positional parser;
- controls: `TOLLGATE_NO_BRAND=1` resolves `brand=none`; an explicit `--brand` is
  observed; the probe brand genuinely has no descriptor (so the default-mode
  result is not a fallback); `--brand` with no value fails loudly;
- the launcher is the pinned artifact in **all three** modes;
- **zero brand literals** on any scanned executable surface, while `brand/active`
  still names a brand that resolves to a real descriptor (so the rule passed by
  moving a literal into data, not by deleting the brand).

### Live end-to-end, not just introspection

The wrapper was run for real against the vendored launcher:

- `bash install.sh --help` → upstream's **own** usage text, exit 0 (so the exec
  really reaches upstream, with an unmodified argv).
- `TOLLGATE_TEST_PLATFORM_ONLY=1 bash install.sh --installer-tag v9.9.9-probe` →
  `Detected platform: linux-amd64` + a fully-resolved asset URL, exit 0. Hermetic:
  no network, because upstream's launcher provides a test seam for exactly this.
- The same in `--brand none` mode → same argv, de-branded naming.

### Licence obligations are gated, not merely written

`tests/shell/test-licence-attribution.sh` — PASS. `LICENSE` is the FSF GPL-3.0
text **verbatim**, pinned by sha256
`3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986`; no project
copyright line is grafted into it; `NOTICE` carries "built on TollGate" plus the
intact upstream copyright and the upstream source for every project consumed;
the installer **prints the attribution on every run** (asserted by running it);
`README.md` carries it too; and the redistributed launcher is declared and
matches its recorded pin.

## What was NOT measured

Stated plainly, because these are the gaps a reviewer should not have to find:

1. **CI has run exactly once, and passed.** Run `38970271526` on `main`, job
   `shell-gates`, every step `success` — de-brand regression, licence attribution,
   shellcheck (`--severity=error`), and the vendored-launcher-vs-pin hash check. The
   only output was two benign notices (the Node 20 → 24 action deprecation and an
   `ubuntu-latest` migration note). What is *not* measured: a CI run on a pull
   request, or on any failure path — the workflow has never been seen to *fail*,
   so its failure reporting is unproven. The gates' failure behaviour was observed
   locally instead (the RED runs in §6 of REPORT.md).
2. **No router install.** No binary was downloaded and no router was touched —
   deliberately, and out of scope for this work package. `README.md`'s one-liner
   advertises `https://net4sats.com/install.sh`, which **404s today**; publishing
   that path is WP-F's landing-page work, not done here.
3. **The brand input does not yet reach the router.** This is the most important
   gap, and it is stated in full because it would be easy to over-read the rest of
   this document.

   Upstream's launcher and wizard read no brand environment variable at all.
   Grepping the pinned composed tree for `TOLLGATE_BRAND` / `TOLLGATE_NO_BRAND`
   returns **nothing**. The only environment variables the wizard reads are:

   ```
   GITHUB_TOKEN                          internal/app/arch.go:255
   TOLLGATE_ALLOW_GITHUB_FALLBACK        internal/app/arch.go:393
   TOLLGATE_CREDENTIAL_FILE              internal/app/deploy.go:205
   TOLLGATE_KNOWN_HOSTS                  internal/app/hostkey.go:43
   TOLLGATE_TRUST_HOST_KEY               internal/app/hostkey.go:47
   ```

   There is also no `--brand` flag upstream; `grep` finds the string only in a
   test's step-name list and in one deploy step whose description is hardcoded to
   upstream's own project name (`{Name: "brand", Desc: "Branding captive portal as
   TollGate..."}`, `internal/app/deploy.go:921`).

   Consequences, stated plainly:
   - `TOLLGATE_BRAND` is **forwarded and inert**: it is the correct *shape* for the
     brand-write path, but upstream does not yet consume it.
   - The **de-branded path is fully real today**, because it is defined by the
     ABSENCE of a brand — which is exactly what upstream does with no input. This
     is the property the regression test protects.
   - The **branded** path's effect on the *deployed router* (SSID, portal
     branding) is **not wired end-to-end by this shell** and is not claimed.
     Wiring it is WP-A' — an upstream change to the installer's brand step and the
     module — and this shell must not pre-empt it with a local bypass.
   - What IS verified for the branded path here: that a brand is selected, that it
     resolves to a real descriptor under `brand/`, that selecting it leaves the
     forwarded argv byte-identical, and that the brand string is carried as data
     rather than as code.
4. **No guest-portal work.** Out of scope by instruction.
5. **Windows/macOS host behaviour.** Only Linux/amd64 was exercised. Upstream's
   launcher advertises both; the shell adds no platform logic, so the risk is
   upstream's, but it was not measured here.
