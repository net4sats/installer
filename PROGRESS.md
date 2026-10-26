# PROGRESS — WP-B net4sats/installer verification & repair

Card: `t_wpb_shell` (board net4sats-mvp-v2). Dispatched as "create the repo (404)".
**The premise is false: the repo exists and is substantial.** This pass is therefore a
DUPLICATE-DISPATCH VERIFICATION + repair, not a build-from-scratch.

Worktree: /home/c03rad0r/worktrees/WP-B-installer-verify
Branch:   worker-base/WP-B-installer-verify  (pushed, PR #9)

## Findings (chronological)

1. **Repo EXISTS** — github.com/net4sats/installer, created 2026-10-16T21:03Z,
   20 commits at base `26fe4872`, default branch main, GPL-3.0, 537 KB.
   → the dispatch's "404" is stale by ~7 days of work. Card body never updated.

2. **Build model honoured** — `pins.tsv` is DATA carrying all four pins exactly as
   recorded in `hermes-orchestration docs/plans/2026-10-16-net4sats-UPSTREAM-PINS.md`
   (`b042a239` base + `a72a4f66`, `049b689` cherry + `41ada960` module). No pin
   re-pointed, no tag moved. All three installer pins re-fetched from the remote
   this pass and confirmed to resolve to the recorded SHAs.

3. **Pin independence RE-MEASURED, not assumed** — `git merge-base --is-ancestor`
   over all 6 ordered pin pairs fired **zero** times ⇒ mutually independent.
   Matches the plan's VERIFIED TRAP.

4. **All 10 shell gates GREEN** (77 ok / 0 FAIL) under `bash` (the interpreter the
   repo's own runner and CI use). NOTE: running them under `sh` produces 9 spurious
   failures — the tests are bash, not POSIX. Harness bug, not a repo defect;
   recorded so it is not rediscovered. `shellcheck --severity=error` = clean.

5. **DEFECT FOUND + FIXED (TDD, RED observed first)** — piped introspection printed
   a ragged filesystem path: `brand=net4sats descriptor=/net4sats.json`.
   `BRAND_DIR` is `""` when piped, so `${BRAND_DIR}/${BRAND}.json` collapsed to
   `/net4sats.json` — a path at the ROOT of the caller's machine, which does not
   exist and is not what the piped path reads. New gate
   `tests/shell/test-piped-descriptor.sh`: RED (1 fail) → fix → GREEN (6 pass).
   Proven live over the real network from the pushed branch, with `main` shown
   defective in the same run for contrast.

6. **My own new test tripped the de-brand carrier scan** (it spelled the brand in
   an `N4S_REPO_SLUG` default). Fixed by **deriving** the id and slug from
   `brand/active`, never by exempting `tests/` from the scan.

7. **Gate was not in CI** — the first PR CI run executed only 4 steps; the new gate
   was not wired. Made it HERMETIC (`file://` base, no network) and added it as a
   CI step; GitHub's clean runner now passes it (step 5), which is the proof of
   hermeticity. `scripts/local-gates.sh` also ran only 2 of the 10 tests — now runs
   all of them and exits non-zero on failure.

8. **HONEST GAP RE-CONFIRMED AT THE PIN (load-bearing)** — `TOLLGATE_BRAND` is
   **forwarded but INERT**. At the composed base pin `b042a239`:
   `git grep 'TOLLGATE_BRAND|TOLLGATE_NO_BRAND' -- '*.go'` = **0 hits**; the only
   `os.Getenv` in `internal/app/deploy.go` is the credential-file path. Upstream's
   "brand" step is **hardcoded**: `Hostname: "tollgate-" + code`,
   `gatewayname=nodogsplash[0].gatewayname='<id.SSID>'`. This is the named trap — a
   same-named upstream step that means something else. `docs/VALIDATION.md` §3
   ALREADY discloses this accurately; no overstatement to correct.

9. **RELEASE ASSET STALENESS (open — needs a release, not a PR)** — v0.1.1
   (2026-10-16T23:59Z) predates **6 commits** on main. Measured: asset `install.sh`
   8043 B vs main 9524 B; lacks `_PIPED_BRAND` (0 hits vs 2) and the portable
   `_sha256`/`shasum` path (0 vs 2); its embedded launcher pin is `7cd397a4…` while
   main pins `6595640e…` (launcher 39492 B vs 39712 B). Consequence: installing from
   the v0.1.1 RELEASE ASSETS still installs **de-branded** over a pipe and still
   **fails on macOS** — both already fixed on main. The DOCUMENTED one-liner points
   at `raw.../main/install.sh`, so the advertised command is fine; only the release
   artifacts lag. I did NOT cut a release: that is an operator decision, and the
   card forbids pushing to main.

## Status per acceptance criterion

| Criterion | Status |
|---|---|
| Repo exists, tagged, binaries published | EXISTS + tagged v0.1.1 + 7 assets — but assets STALE (F9) |
| Vanilla OpenWrt deploys via net4sats/installer + upstream feed | NOT EXERCISED — needs hardware |
| Router read-back (brand/hostname/SSID/NDS) | NOT EXERCISED — and BLOCKED by F8 (inert brand) |
| Real payment e2e on hardware | NOT EXERCISED — needs hardware |
| `curl -sL one-liner \| sh` on clean macOS AND Linux | Linux: EXERCISED live (A–H matrix). macOS: NOT EXERCISED (no host); fix present + unit-gated + CI |
| Portal renders net4sats skin, zero app-logic diff | Admin half shipped as overlay; contract-gated. Guest portal out of scope |
| De-brand default not regressed | **PROVEN** — 21 assertions, argv byte-identical |

## Files touched this pass

- `install.sh` — truthful piped descriptor (mode printer only, 7 lines)
- `tests/shell/test-piped-descriptor.sh` — NEW hermetic gate, written RED first
- `.github/workflows/gates.yml` — wire the new gate into CI
- `scripts/local-gates.sh` — run ALL gates, exit non-zero on failure
- `PROGRESS.md`, `REPORT.md` — this record
- scratch (untracked, not delivered): `.wpb-*.sh`, `.commitmsg*.txt`, `.pr-body.md`
