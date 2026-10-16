# REPORT — net4sats/installer, a thin branded shell over TollGate

**Work package:** WP-B — create the repo as a thin branded shell over upstream
TollGate, building against the pinned `net4sats-pin/*` tags (never `main`).
**Date:** 2026-10-16
**Repository:** https://github.com/net4sats/installer (public, branch `main`)

Everything below is an **observation**. Where something was not done or not
measured it says so; a push, a commit, a test result or a read-back that was not
observed is never claimed.

---

## 1. What was delivered

| # | Deliverable | Where | Evidence |
|---|---|---|---|
| 1 | Thin laptop-side wrapper over upstream's launcher (~15 lines of logic) | `install.sh` | 102 lines total, **49 non-comment/non-blank**; comment block documents the argv hazard |
| 2 | Pin-based build + documented composition recipe | `pins.tsv`, `scripts/build-pinned-upstream.sh`, `docs/PINS.md` | executed; `go build ./...` **exit 0** |
| 3 | Brand inputs (descriptor + 4 assets, admin half from the rescued overlay set) | `brand/active`, `brand/net4sats.json`, `brand/assets/*.png` | all five files **sha256-identical** to `rescue/pr2-theme-overlay` |
| 4 | De-brand regression test, **RED first** | `tests/shell/test-debrand-passthrough.sh` | RED captured, then **PASS — 21 assertions** |
| 5 | GPL-3.0 LICENSE + upstream copyright + visible "built on TollGate" | `LICENSE`, `NOTICE`, run-time notice, README | **PASS — 17 assertions**; notice printed on every run |
| 6 | README + docs | `README.md`, `docs/{PINS,BRAND,ARCHITECTURE,VALIDATION,CONTRIBUTING}.md` | — |

**Zero business logic.** No discovery, SSH/trust, deploy, feed resolution,
flashing, identity derivation or pricing. The guest portal was **not** attempted.

## 2. Commits (observed SHAs)

```
b00b2230dabd8934942cf1b4695b3a3db9472759  chore(licence): GPL-3.0 with upstream copyright intact
3f9a337cb0c9cd855842090d4dfc54efe7c9d724  feat(pins): pin manifest + composition recipe for the pinned upstream build
417f87cd9355b4cc4ae84778a0c589348218e01b  test(debrand): RED-first gate for the no-brand pass-through
2076ecd14c4a45dafc0b09901df1bd3a2b363349  feat(brand): net4sats brand input set (descriptor + four assets)
e0be13b6211904c2838f85a5e0bd48056fc15b35  feat(installer): thin wrapper over the pinned launcher
6d465ccd7cfdad6a5fce08b68cab1da7f2289899  test(licence): gate the GPL-3.0 obligations
6c7c90e67b9aabd6fd099e8c45959587e2028b24  ci: run both gates on every push
```

The de-brand gate is committed **before** the wrapper it gates
(`417f87c` then `e0be13b`), so the repository's own history carries the RED-first
record: at `417f87c` the gate fails because `install.sh` does not exist; the next
commit turns it green. Two further commits add the docs and this report.

## 3. The pins (observed via `git ls-remote`, cold, against an empty repo)

```
net4sats-pin/installer-comfast          b042a23964256e65e83a22c19949117bd5210926  felixfelix-bot/tollgate-installer
net4sats-pin/installer-gateway-domain   a72a4f6698f77fa1b0637723867b02316ab0d13d  felixfelix-bot/tollgate-installer
net4sats-pin/installer-rebrand-gutter   049b68918684d640bb4d464869c29369b62a50d2  felixfelix-bot/tollgate-installer
net4sats-pin/module-ssid-bang           41ada96054bd5394718240d6ec9b43f39a909c12  felixfelix-bot/tollgate-module-basic-go
```

Every one matches `pins.tsv`. No pin was moved, force-pushed or retargeted.

## 4. THE TRAP: verified, then verified *not* to block

The three installer pins are **mutually independent** and do **not** share a base:

| Pin | base |
|---|---|
| `installer-comfast` | `5df4c9c` |
| `installer-gateway-domain` | `346e473` |
| `installer-rebrand-gutter` | `b26c2b9` |

`git merge-base --is-ancestor` executed in **both directions for all six ordered
pairs** — all six report *not an ancestor*. So no pin contains another, and
composing them is a genuine cherry-pick. This is **re-checked by the build script,
never assumed**, and the script refuses to compose if any pin turns out to be an
ancestor of another (which would double-apply the change).

**Composition executed — both cherry-picks applied clean, no conflicts:**

```
ok   - based on installer-comfast (b042a2396425)
ok   - cherry-picked 346e47362147..installer-gateway-domain -> 8abff3696a36
ok   - cherry-picked b26c2b96aa18..installer-rebrand-gutter -> 45836a5b0bc4
ok   - gatewaydomainname re-arm ABSENT from internal/app/deploy.go (want 0, got 0)
ok   - cf-wr632ax present in internal/app/images.go (want >0, got 5)
ok   - the rebrand-literal gutter test is present in the composed tree (1 file)
ok   - go build ./... exit 0
```

The composed tree still **carries every fix**, asserted on content rather than on
exit status — a clean cherry-pick that *loses* a change is the failure mode worth
catching.

## 5. `go test` is flaky upstream — measured, not excused

| Run | Tree | Result |
|---|---|---|
| 1 | composed | `go test ./... -count=1` **exit 0**, whole suite green (145 s) |
| 2 | composed | FAIL: `TestTrustPreflightSequenceOverHTTP` (HTTP context deadline exceeded) |
| — | composed, that test alone, `-count=4` | **exit 0** |
| — | **BASE PIN alone**, unmodified, full suite | FAIL: `TestPrivateBridgeMoveNeverDialsTheRelocatedBridgeAddress` |

The failing file `internal/app/deploy_trust_preflight_test.go` is
**byte-identical (`6fe4260cf8bddc37`) at all three pins and in the composed tree**,
and is **untouched by either composition commit**. The **base pin failing a
different test** under the same load is what rules composition out as the cause.

Consequently the build script treats a full-suite failure as fatal **only if the
failing test also fails in isolation** — a test that passes alone but fails in the
suite is reported as a load flake. The flake is upstream's; re-pointing a pin is
not a fix for it.

## 6. The de-brand regression test (RED-first)

**RED evidence, run before the wrapper existed:**

```
RESULT: FAIL (missing artifacts — nothing further could be checked)
rc=2   → FAIL - missing required file: install.sh
```

**Stronger RED, with a deliberately-wrong branded stub** (`--brand foo` appended
to argv, brand as a code literal — never committed): **13 assertions failed**,
including the two that matter:

```
FAIL - the brand reached the forwarded argv — upstream would read it as the ROUTER IP
FAIL - brand literal on an executable surface: install.sh
```

**GREEN: PASS — 21 assertions** (rc=0). What it proves, positively:

- the vendored launcher, the recorded pin and `--print-launcher-path` all agree on
  one sha256 — the bytes handed to bash **are** upstream's pinned bytes;
- the forwarded argv is `bash <launcher> --one --two=three 'four five'` — argv[0]
  is `bash`, order preserved, and a token containing a space survives verbatim;
- **selecting a brand leaves that argv byte-identical** and carries no `--brand`
  token. This is the hazard guard: upstream's arg loop ends in
  `*) POSITIONAL+=("$1")` and the **first positional is the ROUTER IP**, so an
  appended brand flag would be read as a router address — a *silent* wrong target;
- controls (composed at run time, so the scan cannot pass vacuously):
  `TOLLGATE_NO_BRAND=1` resolves `brand=none`; an explicit `--brand` is observed;
  the probe brand genuinely has no descriptor; `--brand` with no value fails loudly;
- the launcher is the pinned artifact in **all three** modes;
- **zero brand literals** on any scanned executable surface, while `brand/active`
  still names a brand resolving to a real descriptor — i.e. the rule was satisfied
  by moving a literal into data, **not by deleting the brand**.

A first draft of the test also failed **its own negative control** (a `printf`
format-string bug in the control). That is recorded because it is the argument for
having the control: a tree-scan that matches nothing is indistinguishable from a
clean tree.

## 7. Live end-to-end, not just introspection

- `bash install.sh --help` → upstream's **own** usage text, exit 0 — the exec
  really reaches upstream with an unmodified argv.
- `TOLLGATE_TEST_PLATFORM_ONLY=1 bash install.sh --installer-tag v9.9.9-probe` →
  `Detected platform: linux-amd64` plus a fully-resolved asset URL, exit 0.
  **Hermetic** — no network, using upstream's own test seam.
- The same in `--brand none` mode → same argv, de-branded naming.

## 8. Licence obligations, gated rather than merely written

`tests/shell/test-licence-attribution.sh` → **PASS, 17 assertions**. `LICENSE` is
the FSF GPL-3.0 text **verbatim**, pinned by sha256
`3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986`; no project
copyright line is grafted into it; `NOTICE` carries "built on TollGate", the
intact upstream copyright, the upstream source for every project consumed, and the
pointer to `pins.tsv` for GPL §6 Correspondence; the installer **prints the notice
on every run** (asserted by running it); `README.md` carries it too.

## 9. Key design decisions

1. **The brand travels in the ENVIRONMENT, never as a forwarded argument.** One
   flag, `--brand <id>`, is consumed here. `--brand none` is the de-branded path.
   This exists solely because of upstream's positional parser (see §6).
2. **The brand is DATA, not a compiled-in default.** `brand/active` holds the id;
   the gate fails if any brand literal appears on an executable surface.
3. **Tags, not branches.** The upstream PRs are unmerged pending a release, and
   their branches may be rebased; tags do not move.
4. **The pin record is verified every run**, and a mismatch aborts rather than
   executing unverified bytes.
5. **The gate covers its own source.** The scan pattern is a bracket expression so
   the test can scan itself; the sibling licence test uses the same trick. (The
   first version of the licence test did contain the literal, and the de-brand gate
   **caught it** — the gates caught three of my own mistakes before commit.)

## 10. Honest gaps

1. **The brand input does not yet reach the router.** Grepping the pinned composed
   tree for `TOLLGATE_BRAND`/`TOLLGATE_NO_BRAND` returns **nothing**; there is also
   no `--brand` flag upstream. The only env vars the wizard reads are
   `GITHUB_TOKEN`, `TOLLGATE_ALLOW_GITHUB_FALLBACK`, `TOLLGATE_CREDENTIAL_FILE`,
   `TOLLGATE_KNOWN_HOSTS`, `TOLLGATE_TRUST_HOST_KEY`. So `TOLLGATE_BRAND` is
   **forwarded but inert** — the right shape for the brand-write path, not yet a
   router-visible effect. Wiring it is WP-A' (an upstream change) and this shell
   must not pre-empt it. The **de-branded** path is fully real, because it is
   defined by the *absence* of a brand.
2. **No CI run observed.** The workflow is committed and its steps are exactly the
   commands run locally, but no Actions run had been seen at the time of writing.
3. **No router touched, no binary downloaded** — out of scope for this package.
4. **The guest portal is untouched** — out of scope by instruction.
5. **Only Linux/amd64 exercised.** Upstream advertises more; the shell adds no
   platform logic, so the risk is upstream's, but it was not measured here.

## 11. Two things to watch when the upstream release lands

1. **The `gatewayname` divergence.** The pins remove the installer's
   `gatewaydomainname` re-arm (the redirect-loop fix) but do not add the
   `" Portal"` suffix the module writes, so the captive banner still has two
   writers with no cross-repo pin. That is upstream work.
2. **Re-point at released tags.** When upstream merges and tags, cut new pins at
   the released tags and update `pins.tsv` — the same composition with better
   provenance.
