#!/usr/bin/env bash
# Termination item 5 requires `curl -sL <url> | sh` to work. This asserts every
# invocation shape a user can actually reach, and it exists because the original
# install.sh used BASH_SOURCE and arrays with only a bash shebang: it was correct
# from disk under bash but broke under `sh`, which is precisely what the
# documented one-liner uses.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$here"
ok=0; fail=0
check() { # check <label> <expected-substring> <cmd...>
  local label="$1" want="$2"; shift 2
  local out; out="$(timeout 25 "$@" </dev/null 2>&1)"; local rc=$?
  if [ $rc -eq 0 ] && printf '%s' "$out" | grep -qF "$want"; then
    printf 'ok   - %s\n' "$label"; ok=$((ok+1))
  else
    printf 'FAIL - %s (rc=%s, wanted %s)\n' "$label" "$rc" "$want"; fail=$((fail+1))
  fi
}
WANT="vendor/upstream-install-and-test.sh"

check "runs from disk under sh"    "$WANT" sh   install.sh --print-launcher-path
check "runs from disk under bash"  "$WANT" bash install.sh --print-launcher-path
check "runs from disk under dash"  "$WANT" dash install.sh --print-launcher-path

# The documented one-liner shape: the script arrives on stdin.
# NOTE on shape: the redirection must be on the SHELL, not on an outer `timeout`,
# or the file never reaches the shell's stdin. `sh -s ARG` would pass ARG to sh
# itself, so args go after `--`.
run_piped() { # run_piped <shell> <args...>  -- args may be empty
  local sh="$1"; shift
  if [ "$#" -gt 0 ]; then
    timeout 25 "$sh" -s -- "$@" < install.sh 2>&1
  else
    timeout 25 "$sh" -s < install.sh 2>&1
  fi
}

out_sh="$(export N4S_REPO_SLUG="${N4S_TEST_SLUG:-$(tr -d "\n\r" < brand/active)/installer}"; run_piped sh --print-launcher-path </dev/null)"; rc=$?
if printf '%s' "$out_sh" | grep -qF "$WANT"; then echo "ok   - piped under sh (the documented one-liner)"; ok=$((ok+1));
else echo "FAIL - piped under sh: $(printf '%s' "$out_sh" | tail -1)"; fail=$((fail+1)); fi

out_ba="$(export N4S_REPO_SLUG="${N4S_TEST_SLUG:-$(tr -d "\n\r" < brand/active)/installer}"; run_piped bash --print-launcher-path </dev/null)"
if printf '%s' "$out_ba" | grep -qF "$WANT"; then echo "ok   - piped under bash"; ok=$((ok+1));
else echo "FAIL - piped under bash: $(printf '%s' "$out_ba" | tail -1)"; fail=$((fail+1)); fi

out_da="$(export N4S_REPO_SLUG="${N4S_TEST_SLUG:-$(tr -d "\n\r" < brand/active)/installer}"; run_piped dash --print-launcher-path </dev/null)"
if printf '%s' "$out_da" | grep -qF "$WANT"; then echo "ok   - piped under dash"; ok=$((ok+1));
else echo "FAIL - piped under dash: $(printf '%s' "$out_da" | tail -1)"; fail=$((fail+1)); fi

# No invocation shape may hang waiting on a terminal.
if timeout 25 sh -s < install.sh </dev/null >/dev/null 2>&1; then
  echo "ok   - a piped no-arg run terminates (never waits on a TTY)"; ok=$((ok+1))
else
  echo "FAIL - a piped no-arg run hung or errored"; fail=$((fail+1))
fi

echo
echo "ok=$ok fail=$fail"
[ "$fail" -eq 0 ] || exit 2
