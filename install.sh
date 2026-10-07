#!/usr/bin/env bash
# Installs the ParetoOps launcher from npm into the runner's temp dir and exports its path.
# The launcher picks the right prebuilt binary for the runner's OS and CPU.
set -euo pipefail

version="${PARETO_OPS_VERSION:-1}"
dir="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/paretoops-cli"

if ! command -v npm >/dev/null 2>&1; then
  echo "::error title=ParetoOps::npm was not found on this runner. Add actions/setup-node before this step."
  exit 1
fi

# --ignore-scripts: the launcher and its platform packages need no install scripts, so none may run.
npm install --prefix "$dir" --ignore-scripts --no-audit --no-fund --loglevel error "pareto-ops@${version}"

launcher="$dir/node_modules/pareto-ops/bin/pareto-ops.js"
if [ ! -f "$launcher" ]; then
  echo "::error title=ParetoOps::Installed pareto-ops@${version} but its launcher was not found."
  exit 1
fi

echo "PARETO_OPS_LAUNCHER=$launcher" >> "${GITHUB_ENV:?GITHUB_ENV is not set}"
