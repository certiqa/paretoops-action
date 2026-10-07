# ParetoOps for GitHub Actions

Gate CI on **cost per successful task** and accuracy for your LLM app, and see the Pareto frontier on every pull request.

This repository is a thin wrapper. The ParetoOps engine is proprietary and ships as a compiled binary through npm ([`pareto-ops`](https://www.npmjs.com/package/pareto-ops)); the action installs it and runs it. There is no engine source here. ParetoOps is made by [Certiqa](https://github.com/certiqa).

## Quick start

```yaml
- uses: actions/checkout@v7
- run: npm ci && npm run evals -- --output results.json
- uses: certiqa/paretoops-action@v1
  with:
    results: results.json
    config: claude-haiku-4-5
    min-acc: 0.9
    max-cost-per-success: 0.01
    license-key: ${{ secrets.PARETO_LICENSE_KEY }}
```

The job fails when the configuration misses a bar. Input formats (promptfoo, LangSmith, Braintrust, DeepEval, CSV, ParetoOps JSON) are detected automatically.

## With and without a license key

| | No key | Free key | Pro |
|---|---|---|---|
| Threshold gate (`min-acc`, `max-cost-per-success`) | yes | yes | yes |
| Basic job summary | yes | | |
| Full job summary with the frontier chart | | yes | yes |
| Sticky pull request comment | | yes | yes |
| Baselines and the paired regression check | | | yes |

Without a key the action still runs the threshold check and writes a short job summary, so you can try it in three lines. [Get a free key](https://paretoops.dev/free?ref=action) in a minute. Pro is coming soon; [join the interest list](https://paretoops.dev/interest).

Inputs that need a key (`baseline`, `save-baseline`, `strict`, `pr-comment`, and so on) are ignored without one, with a warning in the log.

With a **Free** key, the baseline inputs (`baseline`, `baseline-file`, `baseline-suite`, `baseline-strategy`, `save-baseline`, `accuracy-margin`, `cost-margin`, `strict`) are Pro: setting `baseline` or `baseline-file` fails the step with a message saying so. Leave them out until you have a Pro key.

Without `config`, the action gates the **sweet spot**: the cheapest configuration per success that clears `min-acc`. With a key it fails when no configuration clears the bar; without a key it only reports the analysis. Set `config` to gate a specific configuration.

## Pinning and supply chain

The action installs the `pareto-ops` launcher from npm on every run, with install scripts disabled (`--ignore-scripts`); the launcher picks a prebuilt native binary for the runner. For the strictest setup:

- pin the action to a full commit SHA instead of `@v1`, for example `certiqa/paretoops-action@<sha> # v1.0.0`;
- set `version` to an exact release, for example `1.1.0`, so every run uses the same binary.

## Permissions

```yaml
permissions:
  contents: write        # only to save baselines (merge_group / push runs)
  pull-requests: write   # the pull request comment
```

Pull requests from forks run without secrets. With a key, the action skips them with a notice instead of failing, and the change is gated when it reaches the base branch. Never use `pull_request_target` to work around this.

## Inputs

| Input | Description |
|---|---|
| `results` | **Required.** Results file(s), directory or pattern, space-separated. |
| `config` | Configuration to gate. Omitted: with a key, the sweet spot is gated; without a key, an analysis runs instead of a gate. |
| `min-acc` | Minimum success rate, for example `0.9`. |
| `max-cost-per-success` | Maximum cost per successful task, in USD. |
| `format` | `auto` (default), `promptfoo`, `langsmith`, `braintrust`, `deepeval`, `csv` or `pareto`. |
| `license-key` | Your key, from a secret. |
| `github-token` | Defaults to the workflow token. |
| `baseline`, `baseline-file`, `baseline-suite`, `baseline-strategy`, `save-baseline` | Baseline handling (Pro). |
| `accuracy-margin`, `cost-margin`, `strict` | Regression thresholds (Pro). |
| `reprice` | Recompute costs from token counts using the pricing catalog. |
| `pr-comment` | `auto`, `always` or `never`. |
| `version` | npm version range of `pareto-ops` to run. Default `1`; set an exact version (for example `1.1.0`) for reproducible runs. |

## Outputs

`gate-status` (`PASSED`, `FAILED`, `SKIPPED`), `baseline-verdict`, `anchor-verdict`, `baseline-sha`, `frontier-count`, `dominated-count`, `sweet-spot-config`, `cost-savings-estimate`. Without a key only `gate-status` is set; the baseline outputs need Pro.

```yaml
- id: paretoops
  uses: certiqa/paretoops-action@v1
  with: { results: results.json, config: claude-haiku-4-5 }
- run: echo "Gate ${{ steps.paretoops.outputs.gate-status }}"
```

## Runners

Linux, macOS and Windows runners. The action needs Node.js and npm, and on Windows it runs its scripts with Git Bash (`shell: bash`). GitHub-hosted runners have all three; on self-hosted Windows runners, install Git for Windows. To use the container image on Linux instead, see [the docs](https://paretoops.dev/docs).

## Support

Questions and bug reports: open an issue here, or email team@paretoops.dev. Report security issues privately; see [SECURITY.md](SECURITY.md).

## License

The files in this repository (the action wrapper) are MIT licensed; see [LICENSE](LICENSE). The `pareto-ops` software the action installs is proprietary and covered by the [ParetoOps EULA](https://paretoops.dev/legal/eula/).

## Development

`test/run-tests.sh` runs the action's scripts against the published npm package, the same way the action installs it. To test another build, set `PARETO_OPS_LAUNCHER` (and optionally `PARETO_OPS_BINARY`). CI runs it on Linux, macOS and Windows, plus end-to-end runs of the action itself (`.github/workflows/test.yml`). Publishing a `vX.Y.Z` release moves the `vX` tag to it.

The sample results in `test/fixtures/` are synthetic.
