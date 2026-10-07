#!/usr/bin/env bash
# Exercises run.sh against a real pareto-ops binary, without GitHub.
#
# By default it installs the published launcher from npm (the same way the action does), so it tests
# exactly what users get. To test another build instead, set PARETO_OPS_LAUNCHER (the launcher's
# bin/pareto-ops.js) and, optionally, PARETO_OPS_BINARY (a native binary the launcher should run).
#
# Usage: test/run-tests.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS="$ROOT/test/fixtures/eval_benchmark.json"

work="$(mktemp -d "${TMPDIR:-/tmp}/paretoops-action.XXXXXX")" || exit 2
trap 'rm -rf "$work"' EXIT
cd "$work"

if [ -z "${PARETO_OPS_LAUNCHER:-}" ]; then
  echo "Installing pareto-ops@${PARETO_OPS_VERSION:-1} from npm..."
  RUNNER_TEMP="$work" GITHUB_ENV="$work/env" bash "$ROOT/install.sh" || exit 2
  PARETO_OPS_LAUNCHER="$(sed -n 's/^PARETO_OPS_LAUNCHER=//p' "$work/env")"
fi
export PARETO_OPS_LAUNCHER
export GITHUB_OUTPUT="$work/output" GITHUB_STEP_SUMMARY="$work/summary"
node "$PARETO_OPS_LAUNCHER" --version || exit 2

fails=0
check() { # description, condition-exit-code
  if [ "$2" -eq 0 ]; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi
}
fresh() { : > "$GITHUB_OUTPUT"; : > "$GITHUB_STEP_SUMMARY"; }
run() { env -u PARETO_LICENSE_KEY "$@" bash "$ROOT/run.sh" > "$work/log" 2>&1; }
run_keyed() { env PARETO_LICENSE_KEY=POL2-not-a-real-key "$@" bash "$ROOT/run.sh" > "$work/log" 2>&1; }

# 1. Keyless gate that passes.
fresh
run IN_RESULTS="$RESULTS" IN_CONFIG=claude-haiku-4-5 IN_MIN_ACC=0.5
check "keyless gate passes (exit 0)" $?
grep -q '^gate-status=PASSED$' "$GITHUB_OUTPUT"; check "gate-status=PASSED output" $?
grep -q 'paretoops.dev/free?ref=action' "$GITHUB_STEP_SUMMARY"; check "summary carries the ?ref=action nudge" $?
grep -q $'\033' "$GITHUB_STEP_SUMMARY"; [ $? -ne 0 ]; check "summary has no ANSI color codes" $?

# 2. Keyless gate that fails the bar.
fresh
run IN_RESULTS="$RESULTS" IN_CONFIG=claude-haiku-4-5 IN_MIN_ACC=0.999
[ $? -ne 0 ]; check "keyless gate failing the bar exits non-zero" $?
grep -q '^gate-status=FAILED$' "$GITHUB_OUTPUT"; check "gate-status=FAILED output" $?

# 3. Keyless analyze when no config is given.
fresh
run IN_RESULTS="$RESULTS" IN_MIN_ACC=0.5
check "keyless analyze runs without a config (exit 0)" $?
[ -s "$GITHUB_STEP_SUMMARY" ]; check "analyze writes a job summary" $?

# 4. Inputs that need a key are reported as ignored without one.
fresh
run IN_RESULTS="$RESULTS" IN_CONFIG=claude-haiku-4-5 IN_MIN_ACC=0.5 IN_BASELINE=auto IN_STRICT=true
grep -q '::warning.*baseline strict' "$work/log"; check "keyless warns about ignored inputs" $?
fresh
run IN_RESULTS="$RESULTS" IN_CONFIG=claude-haiku-4-5 IN_MIN_ACC=0.5 IN_BASELINE_SUITE=nightly
grep -q '::warning.*baseline-suite' "$work/log"; check "keyless warns about baseline-suite" $?

# 5. Input values are arguments, never shell code.
fresh
run IN_RESULTS="$RESULTS" IN_CONFIG='x; touch injected' IN_MIN_ACC=0.5
[ ! -e "$work/injected" ]; check "config input is not interpreted by the shell" $?

# 6. Empty results input is rejected.
fresh
run IN_RESULTS="" IN_CONFIG=claude-haiku-4-5
[ $? -ne 0 ]; check "empty results input fails" $?

# 7. With a key, the action hands off to `ci` (a bogus key must be rejected, not crash arg building).
fresh
run_keyed IN_RESULTS="$RESULTS" IN_CONFIG=claude-haiku-4-5 IN_MIN_ACC=0.5 IN_SAVE_BASELINE=false IN_STRICT=false
[ $? -ne 0 ]; check "keyed run rejects an invalid key" $?
grep -v '^::add-mask::' "$work/log" | grep -q 'not-a-real-key'; [ $? -ne 0 ]; check "key is only ever printed in the ::add-mask:: command" $?

# 8. With a key and no config, the sweet spot is gated (not every configuration in the file).
fresh
run_keyed IN_RESULTS="$RESULTS" IN_MIN_ACC=0.9
grep -q '::notice.*gating the sweet spot: claude-haiku-4-5' "$work/log"; check "keyed run without config picks the sweet spot" $?

# 9. The sweet spot is still found when --reprice prints a status line before the JSON.
fresh
run_keyed IN_RESULTS="$RESULTS" IN_MIN_ACC=0.9 IN_REPRICE=true
grep -q '::notice.*gating the sweet spot: ' "$work/log"; check "sweet spot is found with reprice on" $?

echo
[ "$fails" -eq 0 ] && echo "all action checks passed" || { echo "$fails check(s) failed"; echo "--- last log ---"; cat "$work/log"; }
exit "$fails"
