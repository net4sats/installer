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

## 2a. Push — the observed result

```
$ git push -u origin main
To https://github.com/net4sats/installer
 * [new branch]      main -> main
branch 'main' set up to track 'origin/main'.
push exit: 0

$ git ls-remote origin refs/heads/main          # a fresh observation, not the push output
6669715bcad37c3e7878c27c356f25cfe199c2d7	refs/heads/main
local HEAD : 6669715bcad37c3e7878c27c356f25cfe199c2d7
```

Confirmed a second way, through the API — the remote tip, all nine commits with
their SHAs, and the 24 blobs in the tree (so the content is really there, not just
a ref):

```
$ gh api repos/net4sats/installer -q '"default=\(.default_branch) pushed=\(.pushed_at)"'
default=main pushed=2026-10-16T21:34:12Z

$ gh api repos/net4sats/installer/commits/main -q .sha
6669715bcad37c3e7878c27c356f25cfe199c2d7

$ gh api 'repos/net4sats/installer/commits?per_page=20' -q '.[] | "\(.sha[0:12])  \(.commit.message|split("\n")[0])"'
6669715bcad3  docs(report): work-package report with observed evidence
189b54584589  docs: README, pins, brand, architecture, validation, contributing
6c7c90e67b9a  ci: run both gates on every push
6d465ccd7cfd  test(licence): gate the GPL-3.0 obligations
e0be13b62119  feat(installer): thin wrapper over the pinned launcher
2076ecd14c4a  feat(brand): net4sats brand input set (descriptor + four assets)
417f87cd9355  test(debrand): RED-first gate for the no-brand pass-through
3f9a337cb0c9  feat(pins): pin manifest + composition recipe for the pinned upstream build
b00b2230dabd  chore(licence): GPL-3.0 with upstream copyright intact
```

No force-push; no `net4sats-pin/*` tag was touched.

## 2b. CI — ran, and passed

```
$ gh run list --repo net4sats/installer
in_progress  docs(report): …  gates  main  push  38970271526

$ gh run view 38970271526
✓ main gates · 38970271526
✓ shell-gates in 5s

$ gh api repos/net4sats/installer/actions/runs/38970271526/jobs -q '…'
  Set up job                                                       -> success
  Run actions/checkout@v4                                          -> success
  de-brand regression (no-brand path byte-identical, argv verbatim) -> success
  licence attribution (GPL-3.0 obligations)                        -> success
  shellcheck (advisory on style, fatal on error)                   -> success
  the vendored launcher is the pinned bytes                        -> success
```

Both gates therefore also pass on a **fresh, shallow GitHub checkout**, which was
the point of keeping them free of Go, network and git history.

## 2c. Verified from a fresh clone of the PUBLISHED repo

The strongest form of the evidence: clone what is actually published, then run
everything there. Not the worktree the code was written in — the remote.

```
$ git clone https://github.com/net4sats/installer /tmp/…/n4s-fresh-verify
clone exit: 0
cloned HEAD: 7cd1af346704ede06e7979171cf8f3882a2a2d93
remote says : 7cd1af346704ede06e7979171cf8f3882a2a2d93

$ bash tests/shell/test-debrand-passthrough.sh ; echo RC=$?
RESULT: PASS — no-brand path byte-identical to upstream, argv forwarded verbatim, brand is data
de-brand RC=0  ok=21

$ bash tests/shell/test-licence-attribution.sh ; echo RC=$?
RESULT: PASS — GPL-3.0 verbatim, upstream copyright intact, attribution visible at run time
licence  RC=0  ok=17

$ bash install.sh --print-brand-mode
brand=net4sats descriptor=…/n4s-fresh-verify/brand/net4sats.json

$ bash install.sh --help
Built on TollGate — Copyright (C) the OpenTollGate contributors. GPL-3.0. See LICENSE and NOTICE.
Brand:  net4sats
TollGate Installer — one-shot setup and headless deploy test

$ TOLLGATE_TEST_PLATFORM_ONLY=1 bash install.sh --brand none --installer-tag v9.9.9-probe
Detected platform: linux-amd64
Asset URL: https://github.com/OpenTollGate/tollgate-installer/releases/download/v9.9.9-probe/tollgate-installer-linux-amd64

$ git status --short
(empty — the published tree is clean)
```

So a user who clones this repository gets a working wrapper: the attribution
prints, the default brand resolves, `--help` reaches upstream with an unmodified
argv, and the de-branded path takes the upstream default naming.

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

---

## Note on this document's own history

This report is a **snapshot**, and it cannot contain the SHA of the commit that
adds it — the hash does not exist until the commit is written. The commit that
first added this file is `6669715bcad37c3e7878c27c356f25cfe199c2d7`, and the
observed push and CI results recorded in §2a and §2b were added by the commit
immediately after it, once those results had actually happened. No figure in this
report was written ahead of the observation it describes.

---

# Pin re-cut `-3` — fold in upstream `298c8d2` so `§6` can go green

**Card:** `t_9789e7ef` (parent `t_e718b7b0`) · **Date:** 2026-10-26 · **Host:** x280
**Scope:** the base pin the shell builds from, the launcher pin record, `vendor/`,
the digest embedded in `install.sh`, and the docs that describe them. No
`internal/app/*` change — this repository implements no business logic.

Appended rather than replacing the document above: the WP-B report is a dated
record and rewriting it would have destroyed it. Every figure below is an
observation from tool output on this host.

## R1. Result

| Item | Value |
|---|---|
| New tag | `net4sats-pin/installer-comfast-3` → `9efbd13b45406f6189ed00d9cb9a9e62b757a926` |
| Tag kind | lightweight (`git cat-file -t` = `commit`), same as the other four pins |
| Base | `336f51c` (= `installer-comfast-2`) + **one** cherry-pick of upstream `298c8d2`, picked with `-x` so the origin is recorded |
| Files the pick touched | `install-and-test.sh`, `tests/shell/test-launcher-platform-detection.sh` |
| Launcher digest | `4e97751a19e5dc1e3e89adcd5871eeeca10da64177da10c75ad9aa60724e9183` |
| Old tags | `installer-comfast` → `b042a23`, `installer-comfast-2` → `336f51c` — **not moved** (`git ls-remote` before/after; the two listings differ only by the added `-3` row) |
| Gate | `scripts/build-pinned-upstream.sh` **exit 0**, `§6` green (R4) |

The pick is faithful, not merely conflict-free: `git patch-id --stable` on
`9efbd13 -- install-and-test.sh` and on `298c8d2 -- install-and-test.sh` returns
the **same** id, `c66d01e5a18735aa8250040dd610cc3c30999354`. The tag's launcher
carries `tr 'A-Z' 'a-z'` (grep count 1) and no longer the character-class form.

`298c8d2` is **not** an ancestor of the new tag, and that is correct: the tag is a
cherry-pick onto the pin lineage, not a merge of upstream `main`. "The sha comes
from a tree containing `298c8d2`" holds by content and patch-id, not by ancestry —
claiming ancestry would be false.

## R2. Why it was needed — and one inherited claim corrected

`§6` compares three digests; on `-2` they could never agree:

```
pinned tree : 7cd397a4102dd9cc…   (-2's install-and-test.sh)
pin record  : 6595640e29e439c6…
vendored    : 6595640e29e439c6…
```

The shell vendored the busybox-`tr` fix **itself** in `93a0ce4` (2026-10-20);
upstream shipped its own version as `298c8d2` (2026-10-24, PR #154) after every pin
tag had been cut. Same *fix*, different *bytes* — each commit carries a different
comment block — so the digests could never match, and re-recording `vendor/` alone
could not have closed `§6` honestly, because the composed tree did not contain the
fix at all.

**Corrected:** the parent card describes the delta as "exactly that one hunk"
(`tr '[:upper:]'…` → `tr 'A-Z'…`). Measured here, the two files differ in that hunk
**plus its comment**: 4 comment lines on the pinned side vs 3 on the vendored side,
with different wording. Semantically one line; by bytes (what `§6` compares) not.
That is precisely why only folding the upstream commit in could close the gate.

## R3. Changes in this commit

| File | Change |
|---|---|
| `pins.tsv` | base row → `-3`; new "WHY THE BASE PIN IS NOW SUFFIXED -3" note (the `-2` note stays — it still explains that re-cut) |
| `docs/PINS.md` | pins table → `-3`; new "Why the base pin is now `-3`"; merge-base table → `336f51c`; recipe uses `-3`; **new `-3` observed-result block** (verbatim gate output); `-2` block kept and marked historical; the "resolution is a separate re-cut" paragraph now says it was done |
| `docs/VALIDATION.md` | both dated notes record the `-2` **and** `-3` re-cuts |
| `scripts/upstream-launcher.sha256` | → `4e97751a…` |
| `vendor/upstream-install-and-test.sh` | **verbatim upstream bytes** from the `-3` tag |
| `install.sh` | `LAUNCHER_SHA_EMBEDDED` → `4e97751a…`; comment now names the test that actually enforces it |
| `tests/shell/test-debrand-passthrough.sh` | **new §A assertion**: the digest embedded in `install.sh` must equal the pin record |
| `README.md` | the example mismatch message shows the current digest prefix |
| `scripts/build-pinned-upstream.sh` | comment only: §4's mint-copy cargo described as inherited from `-2` |

Why the new assertion: `install.sh`'s own comment claimed the embedded digest is
"asserted equal to the file's by `tests/shell/test-posix-invocation.sh`". No such
assertion existed (`grep -n EMBEDDED tests/shell/*.sh` → nothing). A re-record that
updated the sha file and `vendor/` but missed the constant would therefore ship a
**broken documented one-liner** with every existing gate green — on this branch it
does exactly that, which is how the gap surfaced. The check was falsified before
being trusted: with the constant set back to `6595640e…` the gate fails

```
FAIL - embedded launcher digest differs from the pin record: embedded=6595640e29e439c6… pin=4e97751a19e5dc1e…
RESULT: FAIL — 1 assertion(s) failed          (rc=2)
```

and passes with the correct value.

## R4. Gate output — literal (`evidence/build-pinned-upstream-pin3-FINAL.log`)

```
== 0. every pinned tag still resolves to its recorded commit on the remote
ok   - pin net4sats-pin/installer-comfast-3 == 9efbd13b4540… on felixfelix-bot/tollgate-installer (role=base)
ok   - pin net4sats-pin/installer-gateway-domain == a72a4f6698f7… on felixfelix-bot/tollgate-installer (role=cherry)
ok   - pin net4sats-pin/installer-rebrand-gutter == 049b68918684… on felixfelix-bot/tollgate-installer (role=cherry)
ok   - pin net4sats-pin/module-ssid-bang == 41ada96054bd… on felixfelix-bot/tollgate-module-basic-go (role=module)

== 1. cold fetch (this is the shell's own cold path: the repository starts empty)
ok   - fetched refs/pins/net4sats-pin/installer-comfast-3 -> 9efbd13b4540…
ok   - fetched refs/pins/net4sats-pin/installer-gateway-domain -> a72a4f6698f7…
ok   - fetched refs/pins/net4sats-pin/installer-rebrand-gutter -> 049b68918684…

== 2. the installer pins are mutually independent (neither direction contains the other)
ok   - net4sats-pin/installer-comfast-3 is not an ancestor of net4sats-pin/installer-gateway-domain
ok   - net4sats-pin/installer-comfast-3 is not an ancestor of net4sats-pin/installer-rebrand-gutter
       net4sats-pin/installer-comfast-3           base=336f51c
ok   - net4sats-pin/installer-gateway-domain is not an ancestor of net4sats-pin/installer-comfast-3
ok   - net4sats-pin/installer-gateway-domain is not an ancestor of net4sats-pin/installer-rebrand-gutter
       net4sats-pin/installer-gateway-domain      base=346e473
ok   - net4sats-pin/installer-rebrand-gutter is not an ancestor of net4sats-pin/installer-comfast-3
ok   - net4sats-pin/installer-rebrand-gutter is not an ancestor of net4sats-pin/installer-gateway-domain
       net4sats-pin/installer-rebrand-gutter      base=b26c2b9

== 3. compose all installer pins onto release/pinned-upstream
ok   - based on net4sats-pin/installer-comfast-3 (9efbd13b4540)
ok   - cherry-picked 346e47362147..refs/pins/net4sats-pin/installer-gateway-domain -> bd301431be37
ok   - cherry-picked b26c2b96aa18..refs/pins/net4sats-pin/installer-rebrand-gutter -> 5184f6f84e2d

== 4. the composed tree still carries every pinned fix
ok   - gatewaydomainname re-arm ABSENT from internal/app/deploy.go (want 0, got 0)
ok   - cf-wr632ax present in internal/app/images.go (want >0, got 5)
ok   - the rebrand-literal gutter test is present in the composed tree (1 file)
ok   - no vendor-specific mint copy / DLEQ narrative in internal/app (want 0 files, got 0)
ok   - the mint selector hint is the neutral one-liner (1 occurrence)
ok   - the mint-copy regression guards are present in the composed tree

== 5. go build + go test on the composed tree
ok   - go build ./... exit 0
ok   - go test ./... -count=1 exit 0 — whole suite green
       ok  github.com/OpenTollGate/tollgate-installer/internal/app  39.442s

== 6. vendored launcher == the launcher in the composed pinned tree
       pinned tree : 4e97751a19e5dc1e3e89adcd5871eeeca10da64177da10c75ad9aa60724e9183
       pin record  : 4e97751a19e5dc1e3e89adcd5871eeeca10da64177da10c75ad9aa60724e9183
       vendored    : 4e97751a19e5dc1e3e89adcd5871eeeca10da64177da10c75ad9aa60724e9183
ok   - all three agree — the vendored launcher IS the pinned tree's launcher

== result
PASS — composed 5184f6f84e2d8a8b0e30d65484db3179b3344ffb from 3 independent pins; all fixes present; build+test green; launcher verified
```

`§4`'s cargo assertions are byte-for-byte the ones `d876129` added — none was
weakened; only the comment above them changed.

## R5. The shell suite and the two product gates

| Gate | Result |
|---|---|
| `tests/shell/test-debrand-passthrough.sh` | **PASS**, rc=0 — no-brand path byte-identical, argv verbatim, all three digest copies agree |
| `tests/shell/test-licence-attribution.sh` | **PASS**, rc=0 — GPL-3.0 verbatim, upstream copyright intact, attribution visible at run time |
| `tests/shell/test-busybox-tr.sh` | PASS — busybox `tr` yields `linux-arm64` |
| `tests/shell/test-documented-urls-resolve.sh` | PASS |
| `tests/shell/test-landing-page.sh` | PASS |
| `tests/shell/test-macos-shasum.sh` | PASS |
| `tests/shell/test-piped-brand.sh` | PASS |
| `tests/shell/test-portal-skin-contract.sh` | PASS |
| `tests/shell/test-posix-invocation.sh` | PASS **with `N4S_REPO_URL` pointed at a local server** (7/7); FAIL 3/7 against the default GitHub base — see R6 |
| `shellcheck --severity=error install.sh scripts/*.sh tests/shell/*.sh` | rc=0 |

Inside the composed tree: `tests/shell/test-launcher-platform-detection.sh` PASS
including its new busybox case, and `tests/shell/test-rebrand-literal-gutter.sh`
PASS.

The busybox behaviour the pin exists to fix was observed both ways on the same
test file: RED on `336f51c` (`Detected platform: Linlx-arm64`, rc=2) and GREEN on
`-3` (`linux-arm64`, rc=0). That is a real RED→GREEN, not an assertion that only
ever passes.

## R6. Limits — stated, not papered over

- **Nothing was pushed to `net4sats/installer`'s `main`** (hard rule). The change
  is branch `pin3/fold-in-298c8d2` → **PR
  https://github.com/net4sats/installer/pull/11**, OPEN, `MERGEABLE`,
  `mergeStateStatus: CLEAN`, both `shell-gates` checks `pass` (run ids
  40349063815 / 40349083835), left unmerged. PR #10 (the `-2` pin) is still OPEN
  and independent of this one.
- **The `-3` tag is a tag, not an upstream PR.** `298c8d2` is already in upstream
  `main` (merged as PR #154), so there is nothing to upstream-propose; the pin
  simply predates it.
- **`test-posix-invocation.sh` fails on any branch** because its piped cases fetch
  from the default GitHub base (`raw.githubusercontent.com/net4sats/installer/main`)
  and compare those remote bytes with the local pin. Measured: default base → 3
  FAIL with `got 6595640e…`; `N4S_REPO_URL=http://127.0.0.1:8765` serving the
  worktree → 7/7 PASS. The pre-change tree (`d876129`) passes the default-base run
  only because its pin happens to equal what `main` serves today — the test is
  remote-coupled, not pin-coupled. Property of the test, not of this change; noted
  rather than hidden.
- **The composed Go suite contains a LIVE test** (`TestLivePackageDigestRejects…`)
  that cross-checks the feed's `SHA256SUMS` against `api.github.com`. Anonymous
  quota on this host was exhausted mid-run (`rate_limit` → `remaining: 0`), which
  made it fail *in isolation* — and the gate, correctly, calls that a real failure.
  With `TOLLGATE_GITHUB_TOKEN` set (the token only raises the rate limit;
  `pkgverify.go`: "it is never required for a public release") the same tree is
  green — R4 is that run. Both runs are kept in `evidence/`.
- No router, no binary download, no portal work: out of scope for this card.

