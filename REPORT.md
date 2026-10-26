# REPORT — WP-B `net4sats/installer`: duplicate-dispatch verification + one repair

**Card:** `t_wpb_shell` (board `net4sats-mvp-v2`)
**Dispatched:** "Create `net4sats/installer` (the repo does not exist — 404)"
**Date:** 2026-10-23
**Worktree:** `/home/c03rad0r/worktrees/WP-B-installer-verify`
**Branch:** `worker-base/WP-B-installer-verify` @ `a1b0007f` (pushed, observed)
**PR:** https://github.com/net4sats/installer/pull/9 — CI **pass**

---

## 0. Headline: the dispatch premise is false

The card says the repo does not exist. **It exists**, and has since
2026-10-16T21:03Z — seven days before this dispatch:

```
$ gh api repos/net4sats/installer → created_at 2026-10-16T21:03:38Z, pushed_at 2026-10-20T16:26:01Z
  size 537 KB, license GPL-3.0, default_branch main, 20 commits
$ gh api repos/net4sats/installer/tags → v0.1.0, v0.1.1
$ gh api repos/net4sats/installer/releases → v0.1.1, assets=7
```

The card body was never updated after the 2026-10-16 delivery. So this pass is a
**duplicate-dispatch verification** — independently re-measure every claim, fix
only what is genuinely broken, and record the divergence — not a build-from-scratch.
Declining silently is what causes the same card to be re-queued forever, so the
findings are recorded in the repo (`PROGRESS.md` on the branch).

---

## 1. What I re-verified independently (not quoted from the repo's own report)

I did **not** trust `REPORT.md`'s assertions. Each was re-measured from primary
sources this pass:

### 1.1 The build model — pins are data, never `main`

`pins.tsv` carries all four pins exactly as recorded in
`hermes-orchestration docs/plans/2026-10-16-net4sats-UPSTREAM-PINS.md`:

```
b042a2396425…  felixfelix-bot/tollgate-installer     net4sats-pin/installer-comfast          base
a72a4f6698f7…  felixfelix-bot/tollgate-installer     net4sats-pin/installer-gateway-domain   cherry
049b68918684…  felixfelix-bot/tollgate-installer     net4sats-pin/installer-rebrand-gutter   cherry
41ada96054bd…  felixfelix-bot/tollgate-module-basic-go net4sats-pin/module-ssid-bang         module
```

I re-fetched all three installer pins **from the remote this pass** into a fresh
`/dev/shm` repo — each resolved to the recorded SHA. No tag moved, no pin
re-pointed. `scripts/build-pinned-upstream.sh` refuses to build on a manifest/remote
mismatch, and reads pin names as DATA rather than spelling them.

### 1.2 The independence trap — re-measured, zero assumptions

The plan's VERIFIED TRAP says the three installer pins are mutually independent.
Re-ran `git merge-base --is-ancestor` over **all 6 ordered pairs**:

```
ANCESTOR lines emitted: 0
```

⇒ mutually independent, as claimed. This matters because composing them is a real
cherry-pick, not a fast-forward.

### 1.3 The de-brand default — the property the card singles out

`test-debrand-passthrough.sh`: **21 assertions, 0 FAIL**, including

```
ok   - vendored launcher is BYTE-IDENTICAL to the pinned upstream bytes
ok   - forwarded argv is exactly: bash <launcher> --one --two=three 'four five'
ok   - the brand flag is consumed here, so argv is byte-identical to the no-brand case
ok   - the token containing a space survived argv forwarding verbatim
ok   - no brand literal on any scanned executable surface (13 files)
```

The argv hazard the skill documents is genuinely handled: the brand travels in the
**environment**, not in argv, because upstream's loop ends in
`*) POSITIONAL+=("$1")` and the first positional is the router IP — appending
`--brand foo` would make upstream read `foo` as a **deploy target**.

### 1.4 All gates

```
test-busybox-tr.sh                 rc=0  ok=1   FAIL=0
test-debrand-passthrough.sh        rc=0  ok=21  FAIL=0
test-documented-urls-resolve.sh    rc=0  ok=4   FAIL=0
test-landing-page.sh               rc=0  ok=8   FAIL=0
test-licence-attribution.sh        rc=0  ok=17  FAIL=0
test-macos-shasum.sh               rc=0  ok=2   FAIL=0
test-piped-brand.sh                rc=0  ok=1   FAIL=0
test-piped-descriptor.sh           rc=0  ok=6   FAIL=0   ← added this pass
test-portal-skin-contract.sh       rc=0  ok=9   FAIL=0
test-posix-invocation.sh           rc=0  ok=8   FAIL=0
                                           77 ok, 0 FAIL
shellcheck --severity=error  →  clean
```

> **Harness note worth carrying:** these tests are **bash**, not POSIX. Running
> them under `sh` produces nine spurious failures ("Bad substitution"). I hit that
> first and wasted a cycle on it. `scripts/local-gates.sh` now documents it.

---

## 2. The repair: piped introspection reported a phantom path

### 2.1 The defect

```
$ curl -fsSL https://raw.githubusercontent.com/net4sats/installer/main/install.sh \
    | N4S_REPO_SLUG=net4sats/installer sh -s -- --print-brand-mode
brand=net4sats descriptor=/net4sats.json
```

`/net4sats.json` is a path at the **root of the caller's machine**. When the shell
is piped, `ROOT` is empty so `BRAND_DIR` is `""`, and `${BRAND_DIR}/${BRAND}.json`
collapses. The path does not exist, and it is not what the piped path reads (that
path fetches `brand/active` from `_RAW_BASE`). An operator debugging a failed brand
resolution was pointed at a phantom file — a small bug with a real misdiagnosis cost.

### 2.2 TDD — RED observed before the change

`tests/shell/test-piped-descriptor.sh` was written **first**:

```
RED:   FAIL - piped descriptor is a ragged/absent filesystem path [/net4sats.json]
       pass=3 fail=1     (rc=1)

fix:   7 lines in the mode) branch

GREEN: ok - piped descriptor is anchored to the base the piped path reads […/brand/net4sats.json]
       ok - piped descriptor names brand/net4sats.json
       ok - the reported piped descriptor URL actually RESOLVES to a real descriptor
       ok - control: the piped path still resolves brand=net4sats (fix did not de-brand it)
       ok - control: --brand none over the pipe is still 'brand=none descriptor=none'
       ok - from-disk descriptor is unchanged: the real absolute path under brand/
       pass=6 fail=0     (rc=0)
```

| invocation | before | after |
|---|---|---|
| piped | `descriptor=/net4sats.json` | `descriptor=<base>/brand/net4sats.json` |
| from disk | `…/brand/net4sats.json` | **unchanged** (asserted) |
| `--brand none` | `brand=none descriptor=none` | **unchanged** (asserted) |

The from-disk value is asserted so the fix cannot "solve" the piped case by
degrading the on-disk one.

### 2.3 Proven over the real network, with `main` shown defective alongside

```
--- piped from the FIXED branch ---
brand=net4sats descriptor=https://raw.githubusercontent.com/net4sats/installer/worker-base/WP-B-installer-verify/brand/net4sats.json

--- piped from MAIN (production defect, same run) ---
brand=net4sats descriptor=/net4sats.json
```

### 2.4 The carrier rule caught my own test — and I fixed it the right way

My first draft spelled the brand in an `N4S_REPO_SLUG` default. The gate failed it:

```
FAIL - brand literal on an executable surface: tests/shell/test-piped-descriptor.sh
```

I fixed it by **deriving** the id and slug from `brand/active`, **not** by
exempting `tests/` from the scan. An allowlist entry for `tests/` would permanently
weaken an invariant whose job is to protect source surfaces.

---

## 3. Two gate-coverage gaps closed

### 3.1 The new gate was not in CI

The first PR CI run executed only 4 steps — the new gate was not wired, so it could
never have caught a regression. I made it **hermetic** (defaults the fetch base to
`file://$PWD`, no network; `curl -fsSL` resolves `file://` identically) and added it
as a CI step. GitHub's clean runner now reports:

```
1. Set up job                                                      success
2. Run actions/checkout@v4                                         success
3. de-brand regression (no-brand path byte-identical, argv verbatim) success
4. licence attribution (GPL-3.0 obligations)                        success
5. piped descriptor location is truthful (hermetic, no network)     success  ← new
6. shellcheck (advisory on style, fatal on error)                   success
7. the vendored launcher is the pinned bytes                        success
```

Passing on GitHub's runner is itself the proof of hermeticity.

Hermeticity bought a **stronger** assertion too: the gate now proves the reported
descriptor URL actually **resolves** to a real descriptor file, not merely that the
string looks well-formed.

### 3.2 The local runner under-ran the suite

`scripts/local-gates.sh` ran 2 of the 10 tests by hardcoded name — it had been
silently under-covering as tests were added, and did not exit non-zero. It now
iterates every `tests/shell/test-*.sh`, prints ok/FAIL counts, and exits non-zero.

---

## 4. The load-bearing finding: the brand is INERT at the pin

The card calls the router read-back load-bearing because *"the brand is
read-or-default and never asserted, so an under-branded router passes every other
gate silently."* Verification confirms exactly that, and the cause is upstream:

At the composed base pin `b042a239`:

```
git grep -l 'TOLLGATE_BRAND|TOLLGATE_NO_BRAND' refs/pins/installer-comfast -- '*.go'
  → (no output)                                   # 0 hits

os.Getenv calls in internal/app/deploy.go:
  214: if p := strings.TrimSpace(os.Getenv(credentialFileEnv));  ← the only one

nodeName construction (hardcoded):
  779:  Hostname:    "tollgate-" + code
  858:  "uci -q set nodogsplash.@nodogsplash[0].gatewayname='" + id.SSID + "'"
```

So `TOLLGATE_BRAND` is **forwarded but inert**. Upstream's step 7 *called* "brand"
is hardcoded to upstream's own name — the classic same-named-feature trap. A
shell-only change cannot make the router read `tollgate.brand == net4sats`; that
requires the WP-A' upstream change to the installer's brand step and the module.

**`docs/VALIDATION.md` §3 already discloses this accurately**, unprompted:

> `TOLLGATE_BRAND` is **forwarded and inert**: it is the correct *shape* for the
> brand-write path, but upstream does not yet consume it. […] The **branded** path's
> effect on the *deployed router* … is **not wired end-to-end by this shell** and is
> not claimed. Wiring it is WP-A'.

There is nothing to correct here — the repository understates nothing and
overclaims nothing. I am re-confirming it because it is the finding that decides
whether the card's router read-back criterion can pass at all.

---

## 5. Open finding — release assets are stale (NOT fixed here)

Release **v0.1.1** (2026-10-16T23:59Z) predates **6 commits** on `main`. Measured
this pass by downloading the release assets:

| | v0.1.1 asset | `main` |
|---|---|---|
| `install.sh` | 8043 B | 9524 B |
| `_PIPED_BRAND` occurrences | 0 | 2 |
| portable `_sha256` / `shasum` path | 0 | 2 |
| embedded launcher pin | `7cd397a4…` | `6595640e…` |
| launcher bytes | 39492 B | 39712 B |

Consequence: installing from the **v0.1.1 release assets** still installs
**de-branded** over a pipe (fixed on `main` by `a7169666`) and still **fails on
macOS** (fixed by `1be5b2a6`). The **documented one-liner** points at
`raw.githubusercontent.com/net4sats/installer/main/install.sh`, so the *advertised
command* is correct — only the release artifacts lag.

**I did not cut a release.** The card forbids pushing to `main`, and re-cutting a
release is an operator decision about what version the review club is holding.
Recommendation: after PR #9 merges, cut v0.1.2 from `main` and verify the three
post-tag fixes are present in the assets.

---

## 6. Acceptance criteria — honest status

| Criterion | Status | Evidence / blocker |
|---|---|---|
| Repo exists, tagged, binaries published | **MET** | exists, v0.1.0/v0.1.1 tagged, release with 7 assets — but assets stale (§5) |
| Vanilla OpenWrt deploys using ONLY this + upstream feed | **NOT EXERCISED** | needs hardware; also blocked by §4 |
| Router read-back: `tollgate.brand`, hostname, SSID, NDS gatewayname | **NOT EXERCISED — BLOCKED** | needs hardware **and** the brand is inert upstream (§4). WP-A' is the unblocker |
| Real payment e2e on hardware (Cashu or LN) | **NOT EXERCISED** | needs hardware |
| `curl -sL one-liner \| sh` on clean macOS AND Linux | **PARTIAL** | Linux: exercised live (A–H matrix below). macOS: **not exercised** — no Mac host; the macOS fix is present and unit-gated (`test-macos-shasum.sh`, CI) but not run on real macOS |
| Portal renders net4sats skin, zero app-logic diff | **PARTIAL — as scoped** | admin half shipped as `portal-skin/` overlay, contract-gated (9 assertions); guest portal explicitly out of scope per the card |
| De-brand default not regressed by changes | **MET — PROVEN** | 21 assertions; argv byte-identical with and without a brand |

### Live invocation matrix (Linux, this pass, observed)

| shape | result |
|---|---|
| `bash install.sh --print-brand-mode` | `brand=net4sats descriptor=<abs path>` rc=0 |
| `sh install.sh …` | same, rc=0 |
| `dash install.sh …` | same, rc=0 |
| documented `curl … \| sh` (+slug) | `brand=net4sats`, rc=0 |
| piped **without** slug | fails **loudly**, rc=1, actionable message (not the old silent no-op) |
| piped `--brand none` | `brand=none descriptor=none`, rc=0 |
| `install.sh --help` | reaches **upstream's own** usage text, rc=0 |
| `--print-command --one 'four five'` | argv forwarded verbatim incl. the space |

**Not exercised:** an actual deploy, an actual flash, an actual payment. No router
was touched; no SSH/reboot/power-cycle was performed.

---

## 7. Deliverables on the branch

Commits (both pushed; remote ref observed to equal local HEAD `a1b0007f`):

```
8c2b624e  fix(install): report the TRUTHFUL descriptor location when piped
a1b0007f  test(gates): make the piped-descriptor gate hermetic and wire it into CI
```

Files changed: `install.sh` (+9/−1), `tests/shell/test-piped-descriptor.sh` (new),
`.github/workflows/gates.yml` (+3), `scripts/local-gates.sh` (rewritten),
`PROGRESS.md`, `REPORT.md`.

Zero business logic added. No discovery, SSH/trust, deploy, feed resolution,
flashing, identity derivation or pricing was touched or re-implemented. No pin was
moved. No tag was force-pushed or re-pointed. Nothing was pushed to `main`.

---

## 8. What a follow-up pass should do (in order)

1. Merge PR #9 (CI green, mergeable=MERGEABLE).
2. **Cut v0.1.2 from `main`** and verify the assets carry the 3 post-tag fixes (§5).
3. **WP-A'** — the real unblocker for the card's router read-back: wire the brand
   token through the installer's brand step + the module's UCI record. Until then
   the router cannot report `tollgate.brand == net4sats` no matter what the shell does.
4. Hardware pass: deploy a vanilla OpenWrt router using only this shell + the
   upstream feed, and read back UCI / hostname / SSID / NDS gatewayname **from the
   router** — the assertion that makes under-branding loud.
5. A real macOS box for the clean-macOS leg of the one-liner criterion.
6. Guest-portal branding (separate work package, explicitly out of scope here).

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

Re-run once more at the pushed PR head (`31a3bac`, the report-only follow-up) to
confirm the tree that CI sees is the tree that was gated: **exit 0**, same `§0`–`§6`
results, `PASS — composed 4108aa1797c366f8… from 3 independent pins`
(`evidence/build-pinned-upstream-31a3bac.log`). The composed commit sha differs
between runs because cherry-pick commits carry a fresh timestamp; every assertion,
digest and test result is identical.

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
