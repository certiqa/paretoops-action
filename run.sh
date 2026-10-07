#!/usr/bin/env bash
# Runs ParetoOps for the action. Inputs arrive as IN_* environment variables and are passed to the
# CLI as separate arguments, never interpolated into a shell string.
#
#   With a license key:  `pareto-ops ci` (job summary, PR comment, frontier chart, baselines).
#   Without a key:       `pareto-ops gate` (or `analyze` when no config is given); the action writes
#                        the job summary itself and nudges toward a free key.
set -euo pipefail

FREE_KEY_URL="https://paretoops.dev/free?ref=action"
: "${PARETO_OPS_LAUNCHER:?PARETO_OPS_LAUNCHER is not set (the install step did not run)}"

github_output() { [ -n "${GITHUB_OUTPUT:-}" ] && printf '%s=%s\n' "$1" "$2" >> "$GITHUB_OUTPUT" || true; }

pareto() { node "$PARETO_OPS_LAUNCHER" "$@"; }

is_true() { [ "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" = "true" ]; }

# Results may be several files or patterns separated by spaces. Split without expanding globs;
# the CLI expands patterns itself.
set -f
read -r -a results <<< "${IN_RESULTS:-}"
set +f
if [ "${#results[@]}" -eq 0 ]; then
  echo "::error title=ParetoOps::The results input is empty."
  exit 1
fi

# Appends "--flag value" to `args` when the value is non-empty (no namerefs: macOS bash is 3.2).
add_opt() { # flag value
  if [ -n "${2:-}" ]; then args+=("$1" "$2"); fi
}

# Prints the sweet spot's configId: the cheapest configuration per success that clears min-acc (or,
# when none does, the most accurate one, which the gate then fails).
sweet_spot() {
  local args=(analyze "${results[@]}" --json)
  add_opt --format "${IN_FORMAT:-}"
  add_opt --min-acc "${IN_MIN_ACC:-}"
  is_true "${IN_REPRICE:-}" && args+=(--reprice)
  NO_COLOR=1 pareto "${args[@]}" 2>/dev/null | node -e '
    let s = ""; process.stdin.on("data", (c) => (s += c)).on("end", () => {
      try { const d = JSON.parse(s.slice(s.indexOf("{"))); process.stdout.write((d.sweetSpot && d.sweetSpot.configId) || ""); }
      catch (e) { process.exit(1); }
    });'
}

if [ -n "${PARETO_LICENSE_KEY:-}" ]; then
  echo "::add-mask::$PARETO_LICENSE_KEY"

  # Without a config, gate the sweet spot rather than every configuration in the file, so adding a
  # key never fails a job just because some configuration you are only comparing misses the bar.
  config="${IN_CONFIG:-}"
  if [ -z "$config" ]; then
    config="$(sweet_spot)" || config=""
    if [ -z "$config" ]; then
      echo "::error title=ParetoOps::No config was given and the sweet spot could not be determined from the results. Set the config input."
      exit 1
    fi
    echo "::notice title=ParetoOps::No config input, so gating the sweet spot: $config"
  fi

  args=(ci "${results[@]}")
  add_opt --format "${IN_FORMAT:-}"
  add_opt --config "$config"
  add_opt --min-acc "${IN_MIN_ACC:-}"
  add_opt --max-cost-per-success "${IN_MAX_COST:-}"
  add_opt --baseline "${IN_BASELINE:-}"
  add_opt --baseline-file "${IN_BASELINE_FILE:-}"
  add_opt --baseline-suite "${IN_BASELINE_SUITE:-}"
  add_opt --baseline-strategy "${IN_BASELINE_STRATEGY:-}"
  add_opt --accuracy-margin "${IN_ACCURACY_MARGIN:-}"
  add_opt --cost-margin "${IN_COST_MARGIN:-}"
  add_opt --pr-comment "${IN_PR_COMMENT:-}"
  is_true "${IN_SAVE_BASELINE:-}" && args+=(--save-baseline)
  is_true "${IN_STRICT:-}" && args+=(--strict)
  is_true "${IN_REPRICE:-}" && args+=(--reprice)

  # `ci` writes the job summary, the PR comment and every output itself.
  exec node "$PARETO_OPS_LAUNCHER" "${args[@]}"
fi

# ---- Keyless mode -------------------------------------------------------------------------------
ignored=()
for pair in baseline:IN_BASELINE baseline-file:IN_BASELINE_FILE baseline-suite:IN_BASELINE_SUITE baseline-strategy:IN_BASELINE_STRATEGY \
  accuracy-margin:IN_ACCURACY_MARGIN cost-margin:IN_COST_MARGIN pr-comment:IN_PR_COMMENT; do
  name="${pair%%:*}"; var="${pair##*:}"
  [ -n "${!var:-}" ] && ignored+=("$name")
done
is_true "${IN_SAVE_BASELINE:-}" && ignored+=(save-baseline)
is_true "${IN_STRICT:-}" && ignored+=(strict)
if [ "${#ignored[@]}" -gt 0 ]; then
  echo "::warning title=ParetoOps::No license key set, so these inputs are ignored: ${ignored[*]}. Get a free key at ${FREE_KEY_URL}"
fi

if [ -n "${IN_CONFIG:-}" ]; then
  mode=gate
  args=(gate "${results[@]}" --config "$IN_CONFIG")
  add_opt --format "${IN_FORMAT:-}"
  add_opt --min-acc "${IN_MIN_ACC:-}"
  add_opt --max-cost-per-success "${IN_MAX_COST:-}"
else
  mode=analyze
  args=(analyze "${results[@]}")
  add_opt --format "${IN_FORMAT:-}"
  add_opt --min-acc "${IN_MIN_ACC:-}"
  add_opt --max-cost "${IN_MAX_COST:-}"
fi
is_true "${IN_REPRICE:-}" && args+=(--reprice)

out="$(mktemp "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/paretoops-out.XXXXXX")"
trap 'rm -f "$out"' EXIT

rc=0
NO_COLOR=1 pareto "${args[@]}" > "$out" 2>&1 || rc=$?
cat "$out"

if [ "$mode" = gate ]; then
  if [ "$rc" -eq 0 ]; then github_output gate-status PASSED; else github_output gate-status FAILED; fi
fi

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### ParetoOps"
    echo
    echo '```'
    cat "$out"
    echo '```'
    echo
    echo "> Running without a license key, so this is the threshold check only. A [free key](${FREE_KEY_URL}) adds the full job summary, the frontier chart and a comment on the pull request."
  } >> "$GITHUB_STEP_SUMMARY"
fi

exit "$rc"
