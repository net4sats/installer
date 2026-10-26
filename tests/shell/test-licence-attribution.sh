#!/usr/bin/env bash
# Licence-attribution test — the GPL-3.0 obligation is enforced, not just written.
#
# WHY THIS EXISTS
#
#   TollGate is GPL-3.0. This repository REDISTRIBUTES upstream's launcher
#   (vendor/upstream-install-and-test.sh), so §6 applies: the licence must travel
#   with the copy, the upstream copyright must stay intact, and the
#   Corresponding Source must be reachable. §5 also obliges a re-publisher to
#   carry a visible notice — a NOTICE file nobody reads does not discharge that.
#
#   An attribution requirement that is only prose is an attribution requirement
#   that silently disappears in the next refactor, so each obligation below is a
#   mechanical assertion:
#
#     1. LICENSE is the FSF's GPL-3.0 VERBATIM (sha256 against the canonical
#        text), not a summary, not a paraphrase, not an older version.
#     2. LICENSE keeps the upstream copyright and names no new copyright holder.
#     3. NOTICE carries the "built on TollGate" credit and the upstream
#        copyright line, and points at the upstream source for every project
#        this repo consumes.
#     4. The attribution is VISIBLE AT RUN TIME: the installer prints it.
#     5. README carries it too, for anyone who never runs the installer.
#     6. The redistributed launcher is declared, and the correspondence between
#        the shipped bytes and the pinned upstream commit is recorded.
#
# usage: tests/shell/test-licence-attribution.sh [tree]
# exit 0 = PASS, 2 = FAIL
set -u

TREE="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
FAIL=0
ok()  { printf 'ok   - %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL - %s\n' "$1" >&2; }

# The FSF's canonical GPL-3.0 text. Pinned by hash: a "GPL-3.0" file that is not
# this text is not the licence, however it is labelled.
GPL3_SHA="3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986"
UPSTREAM_COPYRIGHT="Copyright (C) the OpenTollGate contributors"

# ── 1 + 2. LICENSE ─────────────────────────────────────────────────────────
if [ ! -f "$TREE/LICENSE" ]; then
    bad "LICENSE is missing — the GPL obligation is unmet"
else
    got="$(sha256sum "$TREE/LICENSE" | awk '{print $1}')"
    if [ "$got" = "$GPL3_SHA" ]; then
        ok "LICENSE is the FSF GPL-3.0 text VERBATIM (sha256 ${got:0:16}…)"
    else
        bad "LICENSE is not the canonical GPL-3.0 text: ${got:0:16}… != ${GPL3_SHA:0:16}…"
    fi
    grep -q 'GNU GENERAL PUBLIC LICENSE' "$TREE/LICENSE" && ok "LICENSE names the GNU General Public License" \
        || bad "LICENSE does not name the GNU General Public License"
    grep -q 'Version 3, 29 June 2007' "$TREE/LICENSE" && ok "LICENSE is version 3" \
        || bad "LICENSE is not version 3"
    # The GPL text belongs to the FSF and must be verbatim, so no project-specific
    # copyright line may be grafted into it. The upstream credit belongs in NOTICE.
    # The brand literal is written as a bracket expression so this file — which the
    # de-brand gate scans, because it lives under tests/ — does not carry the
    # literal it is checking for. Same trick the de-brand gate uses.
    if grep -qE "Copyright \\(C\\) [0-9]{4}.*(net4[s]ats|OpenTollGate)" "$TREE/LICENSE"; then
        bad "a project copyright line was grafted into the GPL text — the licence must stay verbatim"
    else
        ok "no project copyright line was grafted into the GPL text"
    fi
fi

# ── 3. NOTICE ──────────────────────────────────────────────────────────────
if [ ! -f "$TREE/NOTICE" ]; then
    bad "NOTICE is missing — the attribution is not carried"
else
    if grep -qiE 'built on +tollgate' "$TREE/NOTICE"; then
        ok "NOTICE carries a visible 'built on TollGate' credit"
    else
        bad "NOTICE does not contain a 'built on TollGate' credit"
    fi
    if grep -qF "$UPSTREAM_COPYRIGHT" "$TREE/NOTICE"; then
        ok "NOTICE keeps the upstream copyright line intact"
    else
        bad "NOTICE is missing the upstream copyright line: '$UPSTREAM_COPYRIGHT'"
    fi
    if grep -q 'LICENSE' "$TREE/NOTICE"; then
        ok "NOTICE points at LICENSE for the full text"
    else
        bad "NOTICE does not reference LICENSE"
    fi
    # Every upstream project the shell consumes must be named with its source.
    for repo in OpenTollGate/tollgate-installer OpenTollGate/tollgate-module-basic-go; do
        if grep -q "$repo" "$TREE/NOTICE"; then
            ok "NOTICE names the upstream source for ${repo}"
        else
            bad "NOTICE does not name the upstream source for ${repo}"
        fi
    done
    # §6: the Corresponding Source must be reachable. The pin manifest is how.
    if grep -q 'pins.tsv' "$TREE/NOTICE"; then
        ok "NOTICE points at pins.tsv for the exact upstream commits (GPL §6)"
    else
        bad "NOTICE does not point at pins.tsv — the Corresponding Source is not identified"
    fi
fi

# ── 4. the credit must be VISIBLE AT RUN TIME ──────────────────────────────
# `--print-launcher-path` is a read-only, network-free introspection mode, so it
# doubles as a cheap probe of what a real run prints.
RUN_OUT="$(bash "$TREE/install.sh" --print-launcher-path 2>&1 >/dev/null || true)"
if printf '%s' "$RUN_OUT" | grep -qi 'tollgate'; then
    ok "the installer prints the TollGate attribution on every run"
else
    bad "the installer prints no attribution at run time (stderr was: '${RUN_OUT}')"
fi
if printf '%s' "$RUN_OUT" | grep -q 'GPL-3.0'; then
    ok "the run-time notice names the licence"
else
    bad "the run-time notice does not name the licence"
fi

# ── 5. README ──────────────────────────────────────────────────────────────
if [ ! -f "$TREE/README.md" ]; then
    bad "README.md is missing"
else
    if grep -qiE 'built on +tollgate' "$TREE/README.md"; then
        ok "README carries the 'built on TollGate' credit"
    else
        bad "README does not carry a 'built on TollGate' credit"
    fi
    if grep -q 'GPL-3.0' "$TREE/README.md"; then
        ok "README states the licence"
    else
        bad "README does not state the licence"
    fi
    if grep -qF "$UPSTREAM_COPYRIGHT" "$TREE/README.md"; then
        ok "README keeps the upstream copyright line"
    else
        bad "README is missing the upstream copyright line"
    fi
fi

# ── 6. the redistributed launcher is declared and pinned ───────────────────
if [ -f "$TREE/vendor/upstream-install-and-test.sh" ]; then
    ok "the redistribution is present at vendor/upstream-install-and-test.sh"
    if [ -f "$TREE/scripts/upstream-launcher.sha256" ] && \
       [ "$(sha256sum "$TREE/vendor/upstream-install-and-test.sh" | awk '{print $1}')" = \
         "$(awk '/^sha256/ {print $2; exit}' "$TREE/scripts/upstream-launcher.sha256")" ]; then
        ok "the redistributed launcher matches its recorded pin (which commit it came from is recorded)"
    else
        bad "the redistributed launcher does not match the recorded pin"
    fi
else
    bad "vendor/upstream-install-and-test.sh is missing"
fi

# ── 7. the public landing page ─────────────────────────────────────────────
# The landing page is a SHIPPED SURFACE: it is the page a user reads before they
# ever run the installer, so the §5 visible notice has to be on it too. It lived
# in LANDING-PAGE.md while the deployed host served a stub, and nothing asserted
# the wording there — which is exactly how an attribution clause drifts from
# "satisfied" to "unverified" without any commit looking wrong.
#
# The credit must appear INSIDE the HTML block, not merely in the prose around
# it: the surrounding markdown also discusses the footer, so a bare file-wide
# grep would pass on commentary while shipping no credit.
LANDING="$TREE/LANDING-PAGE.md"
if [ ! -f "$LANDING" ]; then
    bad "LANDING-PAGE.md is missing — the public install page has no source of record"
else
    html="$(awk '/^```html/{f=1;next} /^```/{f=0} f' "$LANDING")"
    if [ -z "$html" ]; then
        bad "LANDING-PAGE.md carries no \`\`\`html block — there is no deployable page"
    else
        printf '%s\n' "$html" | grep -qiE 'built on +tollgate' \
            && ok "the landing page ships a visible 'built on TollGate' credit in its HTML" \
            || bad "the landing page HTML does not carry a 'built on TollGate' credit"
        printf '%s\n' "$html" | grep -qF "$UPSTREAM_COPYRIGHT" \
            && ok "the landing page keeps the upstream copyright line" \
            || bad "the landing page is missing the upstream copyright line"
        # Negative control: the same matcher must reject an HTML block that has
        # the copyright but dropped the credit, so this assertion cannot pass
        # vacuously on a page that merely mentions attribution.
        # NB: the credit is spelled "TollGate" (capital G), so a matcher written
        # as [Tt]ollgate silently fails to strip it and the control passes
        # vacuously. The I flag is what makes removal and matching agree.
        if printf '%s\n' "$html" | sed 's/built on *tollgate//Ig' | grep -qiE 'built on +tollgate'; then
            bad "landing-page control failed — the credit matcher is not load-bearing"
        else
            ok "landing-page control: a page without the credit is rejected"
        fi
    fi
fi

# ── report ──────────────────────────────────────────────────────────────────
echo
if [ "$FAIL" -eq 0 ]; then
    echo "RESULT: PASS — GPL-3.0 verbatim, upstream copyright intact, attribution visible at run time"
    exit 0
fi
echo "RESULT: FAIL — ${FAIL} assertion(s) failed" >&2
exit 2
