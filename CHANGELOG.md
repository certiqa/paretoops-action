# Changelog

## v1.0.0

First public release.

- Runs the ParetoOps threshold gate (`pareto-ops gate`) without a key, and the full CI gate
  (`pareto-ops ci`: job summary, pull request comment, frontier chart, baselines on Pro) with one.
- Without a `config` input and with a key, gates the sweet spot: the cheapest configuration per success
  that clears `min-acc`.
- Installs the `pareto-ops` launcher from npm with install scripts disabled; the `version` input pins it.
- Linux, macOS and Windows runners.
