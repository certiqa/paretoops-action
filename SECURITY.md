# Security policy

Please report security issues privately to **team@paretoops.dev**, not in a public issue. Include the
action version (or commit SHA), the runner OS and steps to reproduce. We aim to acknowledge reports
within 3 business days.

This covers the action in this repository and the `pareto-ops` software it installs. For how the
software handles your data and what it does on the network, see https://paretoops.dev/trust/ and the
security overview at https://paretoops.dev/legal/security/.

## Using the action safely

- Store your license key as an encrypted secret (`secrets.PARETO_LICENSE_KEY`); the action masks it in logs.
- Pin the action to a full commit SHA and set the `version` input to an exact release if you need
  reproducible, reviewed runs.
- Never run it from `pull_request_target` on untrusted fork code to get secrets: fork pull requests are
  gated when the change reaches your base branch.
