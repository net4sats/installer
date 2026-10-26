# PINS — what this shell builds against, and why

**The rule:** this repository builds from **pinned, immutable tags**. Never from
`main`, never from an unmerged branch tip.

## Why tags and not branches

The upstream PRs behind these pins are open and **deliberately not merged** while
the operator's release freeze holds (pre-releases are out with the review club; the
next merge waits for a release and a clean slate). Their **branches** are the review
vehicle and *may be rebased* when that release lands. The **tags** are the
dependency and do not move.

That separation is the whole point: a rebase of `pr/...` cannot silently change
what this repository builds.

## The pins

Recorded in [`pins.tsv`](../pins.tsv) — the one place the pinned ref *names* may
appear. The build script reads them from there and refuses to build if any
recorded commit disagrees with the remote.

| Tag | Repo | Commit | Carries |
|---|---|---|---|
| `net4sats-pin/installer-comfast-3` | `felixfelix-bot/tollgate-installer` | `9efbd13b4540` | everything in `-2` (COMFAST CF-WR632AX flashable: guard widened against the model table, per-model release gate, vendor-neutral refusals; **+ brand-neutral Cashu mint copy**, backport of upstream `70ee7fc`, PR #164, with its two regression guards) **+ upstream's busybox-`tr` launcher fix** `298c8d2` (PR #154) |
| `net4sats-pin/installer-gateway-domain` | `felixfelix-bot/tollgate-installer` | `a72a4f6698f7` | stop re-arming the nodogsplash `gatewaydomainname` redirect loop |
| `net4sats-pin/installer-rebrand-gutter` | `felixfelix-bot/tollgate-installer` | `049b68918684` | whitelabel rebrand-literal gutter ported from the module + CI wiring |
| `net4sats-pin/module-ssid-bang` | `felixfelix-bot/tollgate-module-basic-go` | `41ada96054bd` | write the `!` on the captive SSID, strip it in both shell parsers, pin the portal banner cross-repo |

The module pin is **recorded, not composed**: it is a different repository and is
consumed by the router-side package, not by this shell.

### Why the base pin is now `-3` (2026-10-26)

`§6` of `build-pinned-upstream.sh` compares **three** launcher digests — the
launcher inside the composed tree, `scripts/upstream-launcher.sha256`, and
`vendor/upstream-install-and-test.sh` — and on `-2` they could never agree:

```
pinned tree : 7cd397a4102dd9cc…   (-2's install-and-test.sh)
pin record  : 6595640e29e439c6…   (the shell's own vendored copy)
vendored    : 6595640e29e439c6…
FAIL - launcher mismatch
```

Cause, measured (not re-derived): this shell vendored the busybox-`tr` launcher
fix **itself** in `93a0ce4` (2026-10-20), before upstream had shipped one.
Upstream shipped the same fix separately as `298c8d2` — "busybox tr has no
character classes — asset URLs 404 on OpenWrt (#154)", 2026-10-24 — i.e. **after
every `net4sats-pin/*` tag was cut**, so no pin could contain it. The two copies
are not byte-identical (each carries its own explanatory comment), so their
digests cannot agree, and the shell cannot honestly vendor "the pinned tree's
launcher" while the pinned tree lacks the fix.

So the base pin was re-cut as `-3` = `336f51c` + **one** cherry-pick of `298c8d2`
(`9efbd13`, touching only `install-and-test.sh` and
`tests/shell/test-launcher-platform-detection.sh`). Its launcher is
`4e97751a19e5…`, and that is now what the pin record, `vendor/` and
`install.sh`'s embedded `LAUNCHER_SHA_EMBEDDED` all carry. Tags
`installer-comfast` (`b042a23`) and `installer-comfast-2` (`336f51c`) were **not
moved** — see "Do not move a pin".

`-3` still descends from `b042a23` via `336f51c`, so it is still independent of
the two cherry pins, and it still carries the brand-neutral mint copy and both
guards (§4 re-asserts that cargo, unchanged).

### Why the base pin was `-2` (2026-10-26)

The Cashu mint preference hint named a mint vendor and the retired DLEQ
keyset-rotation workaround, and deploy step 8b carried the matching comment. That is
operator-visible brand copy, so it was fixed **upstream** — `OpenTollGate/tollgate-installer`
PR #164 (`70ee7fc`) — and backported onto the base pin as `336f51c`. The old tag
`net4sats-pin/installer-comfast` still resolves to `b042a23` and was **not moved**;
`-3` (above) descends from `336f51c` and carries it forward.

**The fix sits on the base on purpose, and that was measured twice.** `§3` derives
each pin's range as `<tag>^..<tag>` (exactly one commit per pin) and composes the base
by **checking its tree out** rather than cherry-picking it, so the base tag's commit is
carried whole while a cherry pin contributes only its last commit:

- putting the backport on a cherry pin (gateway-domain) silently did not replay that
  pin's own fix beneath it — re-measured before this commit by recreating the
  composition (`b042a23` + `a72a4f6..<gw-top>`): the result still carries
  `gatewaydomainname='tollgate.lan'` in `deploy.go`, which `§4` reports as `1`
  where it wants `0`;
- giving the same backport to a second cherry pin stops the composition on an
  **empty** cherry-pick (`nothing to commit`), because the first pick already
  carried it — refused by `§3` just as a conflict would be.

On the base, no later cherry-pick can drop it.

## Do not move a pin

**Never force-push, delete or re-point a `net4sats-pin/*` tag.** Moving one is a
deliberate act. If a pin must change, cut a **new tag** (`…-2`) and record the new
row here, so an existing build stays reproducible. `build-pinned-upstream.sh`
fails loudly if a recorded commit no longer matches the remote:

```
FAIL - pin net4sats-pin/installer-comfast MOVED: recorded b042a2396425… but remote is …
```

## THE TRAP: the installer pins are mutually independent

The three installer pins **do not share a base**, so composing them is a real
cherry-pick, not a fast-forward. `installer-comfast-3` is the newer base; the other
two descend from an older commit.

| Pin | merge-base (its parent / base) |
|---|---|
| `installer-comfast-3` | `336f51c` (it is `336f51c` + the `298c8d2` backport `9efbd13`), which is itself `b042a23` + the mint-copy backport |
| `installer-gateway-domain` | `346e473` |
| `installer-rebrand-gutter` | `b26c2b9` |

So `installer-comfast-3` does **not** contain the other two, and vice versa. This is
**re-checked, not assumed** — `build-pinned-upstream.sh` asserts independence in
*both* directions with `git merge-base --is-ancestor` for every pair, and refuses to
compose if any pin turns out to be an ancestor of another (which would mean
composing both would double-apply the change):

```sh
git merge-base --is-ancestor <pinA> <pinB>
```

That the trap is real, and that it does **not** block, were both verified by
executing the composition — see below.

## Composition recipe

```sh
git clone --no-checkout https://github.com/felixfelix-bot/tollgate-installer
cd tollgate-installer
git fetch origin 'refs/tags/net4sats-pin/*:refs/pins/*'
git checkout -B release/pinned-upstream refs/pins/installer-comfast-3
for p in installer-gateway-domain installer-rebrand-gutter; do
  base=$(git rev-list --max-count=1 --skip=1 "refs/pins/$p")
  git cherry-pick "$base..refs/pins/$p"
done
go build ./... && go test ./... -count=1
```

`scripts/build-pinned-upstream.sh` is this recipe with the assertions attached;
prefer it, because it also proves the composed tree still *carries* every fix.

Note `git fetch --depth 1` is **not** enough to cherry-pick: the pick needs each
pin's parent, which a shallow fetch does not carry. Fetch full history; the cold
path is still exercised because the repository starts empty.

## Re-verify the composed tree carries every fix

A clean cherry-pick that *loses* a change is the failure mode to guard, so the
script asserts the content, not just the exit status:

```sh
git grep -c "gatewaydomainname='tollgate.lan'" -- internal/app/deploy.go   # want 0
git grep -c 'cf-wr632ax' -- internal/app/images.go                        # want > 0
git ls-tree -r --name-only HEAD tests/shell/ | grep -c rebrand-literal-gutter  # want 1
# the base pin's own cargo (inherited from -2): brand-neutral mint copy + both guards
git grep -c -i -E 'minibits temporarily|DLEQ keyset rotation bug' -- internal/app/   # want nothing
git grep -c 'Which Cashu mint the router should prefer for ecash payments\.' \
    -- internal/app/index.html                                                       # want 1
git cat-file -e HEAD:internal/app/mint_copy_neutrality_test.go                       # want present
```

## Observed result — executed 2026-10-26 (the `-3` composition)

Run in full on this host with the `-3` base pin. `§6` now passes:

```
== 0. every pinned tag still resolves to its recorded commit on the remote
ok   - pin net4sats-pin/installer-comfast-3 == 9efbd13b4540… on felixfelix-bot/tollgate-installer (role=base)
ok   - pin net4sats-pin/installer-gateway-domain == a72a4f6698f7… (role=cherry)
ok   - pin net4sats-pin/installer-rebrand-gutter == 049b68918684… (role=cherry)
ok   - pin net4sats-pin/module-ssid-bang == 41ada96054bd… (role=module)

== 2. the installer pins are mutually independent (neither direction contains the other)
       net4sats-pin/installer-comfast-3           base=336f51c
       net4sats-pin/installer-gateway-domain      base=346e473
       net4sats-pin/installer-rebrand-gutter      base=b26c2b9

== 3. compose all installer pins onto release/pinned-upstream
ok   - based on net4sats-pin/installer-comfast-3 (9efbd13b4540)
ok   - cherry-picked 346e47362147..refs/pins/net4sats-pin/installer-gateway-domain -> c218c7d67d7e
ok   - cherry-picked b26c2b96aa18..refs/pins/net4sats-pin/installer-rebrand-gutter -> 5e7cc96977a7

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
       ok  github.com/OpenTollGate/tollgate-installer/internal/app  34.897s

== 6. vendored launcher == the launcher in the composed pinned tree
       pinned tree : 4e97751a19e5dc1e3e89adcd5871eeeca10da64177da10c75ad9aa60724e9183
       pin record  : 4e97751a19e5dc1e3e89adcd5871eeeca10da64177da10c75ad9aa60724e9183
       vendored    : 4e97751a19e5dc1e3e89adcd5871eeeca10da64177da10c75ad9aa60724e9183
ok   - all three agree — the vendored launcher IS the pinned tree's launcher

== result
PASS — composed 5e7cc96977a7449f8382e7a43f3d94c6364fe70b from 3 independent pins; all fixes present; build+test green; launcher verified
```

One operational note, because it misreads as a composition defect: the composed
suite contains a LIVE test, `TestLivePackageDigestRejectsCorruptedBytes`, which
cross-checks the feed's `SHA256SUMS` manifest against `api.github.com`. Anonymous
API quota is 60 requests/hour per IP; once it is spent the API answers 403, the
cross-check gets no API answer, and the test fails **in isolation as well** — the
gate then (correctly, per its own rule) calls it a real failure. Re-run with
`TOLLGATE_GITHUB_TOKEN` set — the token only raises that limit
(`pkgverify.go`: "it is never required for a public release") — and the suite is
green, as above. Two other names occasionally appear in a suite run and pass in
isolation: `TestPrivateBridgeMoveNeverDialsTheRelocatedBridgeAddress` and
`TestLivePackageDigestRejectsCorruptedBytes` under load; both were re-run
individually here.

## Observed result — executed 2026-10-26 (the `-2` composition, historical)

Kept verbatim as the dated record of the run that PRODUCED the follow-up this
re-cut fixes. Do not read it as the current state — the `-3` run above is.

Re-run in full after the base pin was re-cut, on this host:

```
== 0. every pinned tag still resolves to its recorded commit on the remote
ok   - pin net4sats-pin/installer-comfast-2 == 336f51cac2db… (role=base)
ok   - pin net4sats-pin/installer-gateway-domain == a72a4f6698f7… (role=cherry)
ok   - pin net4sats-pin/installer-rebrand-gutter == 049b68918684… (role=cherry)
ok   - pin net4sats-pin/module-ssid-bang == 41ada96054bd… (role=module)

== 2. the installer pins are mutually independent
       net4sats-pin/installer-comfast-2           base=b042a23
       net4sats-pin/installer-gateway-domain      base=346e473
       net4sats-pin/installer-rebrand-gutter      base=b26c2b9

== 3. compose all installer pins onto release/pinned-upstream
ok   - based on net4sats-pin/installer-comfast-2 (336f51cac2db)

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
       ok   github.com/OpenTollGate/tollgate-installer/internal/app   39.902s

== 6. vendored launcher == the launcher in the composed pinned tree
       pinned tree : 7cd397a4102dd9cc…
       pin record  : 6595640e29e439c6…
       vendored    : 6595640e29e439c6…
FAIL - launcher mismatch: tree=7cd397a4102dd9cc… record=6595640e29e439c6… vendored=6595640e29e439c6…
```

**§6 is a pre-existing pin/vendor divergence, not a regression from the `-2`
re-cut, and it is NOT fixed by re-pointing a tag.** Measured: the shell's
vendored launcher and its recorded sha256 both come from the shell's own
`93a0ce4`, which carries the busybox-`tr` fix; upstream shipped the same fix as
`298c8d2` (#154), which is in upstream `main` but in **none** of the four
`net4sats-pin/*` tags (each was cut before it). `b042a23` and `336f51c` both
still carry `tr '[:upper:]' '[:lower:]'` — byte-identical to each other, so the
mint-copy backport did not change the launcher at all. The diff between the
pinned launcher and the vendored one is exactly that one hunk.

Resolution was a **separate** pin re-cut that folds `298c8d2` into the base tag
(and then re-records `scripts/upstream-launcher.sha256` + `vendor/`). It was
deliberately out of scope there: bundling an unrelated launcher change into the
mint-copy pin would have made that pin's provenance ambiguous, and pin
provenance is exactly the kind of judgement that belongs in a recorded decision
rather than bundled into an unrelated pin. Recorded as a follow-up and
**done** as `net4sats-pin/installer-comfast-3` (see the `-3` observed result above).

## Observed result — executed 2026-10-16 (historical, pre-`-2`)

Composing all three installer pins onto one branch, on this host. The pin names
and commits below are as they read **before** the `-2` re-cut; kept verbatim as a
dated record, not as the current state:

```
== 2. the installer pins are mutually independent (neither direction contains the other)
ok   - installer-comfast is not an ancestor of installer-gateway-domain
ok   - installer-gateway-domain is not an ancestor of installer-comfast
       installer-comfast          base=5df4c9c
       installer-gateway-domain   base=346e473
       installer-rebrand-gutter   base=b26c2b9

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

**Both cherry-picks applied clean, with no conflicts**, and the composed tree
carries all three fixes. `go build ./...` exits 0.

## Two things worth re-checking when the release lands

1. **The `gatewayname` suffix divergence.** The pins remove the installer's
   `gatewaydomainname` re-arm, which is the redirect-loop fix. They do **not** add
   the `" Portal"` suffix the module writes, so the captive banner still has two
   writers with no cross-repo pin. That is upstream work, not a shell concern.
2. **Re-point at released tags.** When upstream merges and tags, cut new pins at
   the released tags and update `pins.tsv`. This shell then rebuilds against
   releases rather than pre-merge commits — the same composition, a better
   provenance.
