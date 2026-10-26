# PINS — what this shell builds against, and why

**The rule:** this repository builds from **pinned, immutable tags**. Never from
`main`, never from an unmerged branch tip.

## Why tags and not branches

The upstream PRs behind these pins were **deliberately held** while the operator's
release freeze was in force. **That freeze is over:** `v0.6.0` shipped on all three
repositories on 2026-10-21 (feed `02:06Z`, installer `03:27Z`, module `03:27Z`).

The pins are still here because **the release does not contain these fixes**. Every
pinned change merged, or was pushed, *after* the tag was cut:

| Pin | Merged / pushed | Tag `v0.6.0` cut | In the release? |
|---|---|---|---|
| `installer-comfast` (#152) | still **open** | 2026-10-21 | no |
| `installer-gateway-domain` (#150) | still **open** | 2026-10-21 | no |
| `installer-rebrand-gutter` (#151) | still **open** | 2026-10-21 | no |
| `module-ssid-bang` (#957) | merged 2026-10-23 | 2026-10-21 | no |

Verified at the tag rather than assumed: `v0.6.0` has **no `internal/app/brand.go`**
(so it predates the brand token from #153) and `deploy.go:861` **still carries** the
`gatewaydomainname` re-arm (so it predates #150).

So tags-not-branches remains the right rule — a rebase of `pr/...` still cannot
silently change what this repository builds — but it is now a **temporary** mechanism.

### Retiring the pins

The gate for dropping them entirely is tracked in
[**issue #15**](https://github.com/net4sats/installer/issues/15): what must land in
`v0.6.1` (installer + module + a feed rebuild), and what this repo must then change.
Until every item there is closed, these tags are the dependency.

## The pins

Recorded in [`pins.tsv`](../pins.tsv) — the one place the pinned ref *names* may
appear. The build script reads them from there and refuses to build if any
recorded commit disagrees with the remote.

| Tag | Repo | Commit | Carries |
|---|---|---|---|
| `net4sats-pin/installer-comfast` | `felixfelix-bot/tollgate-installer` | `b042a2396425` | make the COMFAST CF-WR632AX flashable (guard widened against the model table, per-model release gate, vendor-neutral refusals) |
| `net4sats-pin/installer-gateway-domain` | `felixfelix-bot/tollgate-installer` | `a72a4f6698f7` | stop re-arming the nodogsplash `gatewaydomainname` redirect loop |
| `net4sats-pin/installer-rebrand-gutter` | `felixfelix-bot/tollgate-installer` | `049b68918684` | whitelabel rebrand-literal gutter ported from the module + CI wiring |
| `net4sats-pin/module-ssid-bang` | `felixfelix-bot/tollgate-module-basic-go` | `41ada96054bd` | write the `!` on the captive SSID, strip it in both shell parsers, pin the portal banner cross-repo |

The module pin is **recorded, not composed**: it is a different repository and is
consumed by the router-side package, not by this shell.

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
cherry-pick, not a fast-forward. `installer-comfast` is the newer base; the other
two descend from an older commit.

| Pin | merge-base (its parent / base) |
|---|---|
| `installer-comfast` | `5df4c9c` |
| `installer-gateway-domain` | `346e473` |
| `installer-rebrand-gutter` | `b26c2b9` |

So `installer-comfast` does **not** contain the other two, and vice versa. This is
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
git checkout -B release/pinned-upstream refs/pins/installer-comfast
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
```

## Observed result — executed 2026-10-16

Composing all three installer pins onto one branch, on this host:

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

## Two things that were flagged for "when the release lands" — both still open

The release landed on 2026-10-21 and neither of these was touched by it.

1. **The `gatewayname` suffix divergence — still live, measured 2026-10-26.** Two
   writers still disagree about the captive banner:

   ```sh
   # tollgate-installer main internal/app/deploy.go:858
   uci -q set nodogsplash.@nodogsplash[0].gatewayname='<SSID>'

   # tollgate-module-basic-go main 99-tollgate-setup:2056 and :2900
   uci set nodogsplash.@nodogsplash[0].gatewayname="${GATEWAY_NAME} Portal"
   ```

   The installer writes no suffix, the module appends `" Portal"`, so the banner
   text depends on which one ran last. The pins do not fix this and never did — they
   only remove the `gatewaydomainname` re-arm. Tracked as item **C6** in
   [issue #15](https://github.com/net4sats/installer/issues/15).

2. **Re-point at released tags.** That is now the whole point of
   [issue #15](https://github.com/net4sats/installer/issues/15): wait for `v0.6.1`
   across installer + module + feed, then cut new pins at the released tags and update
   `pins.tsv`. The same composition, a better provenance — and eventually no pins at all.
