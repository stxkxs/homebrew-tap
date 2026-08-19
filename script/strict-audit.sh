#!/usr/bin/env bash
#
# Run `brew audit --strict` over every formula in the tap and classify the
# findings. See script/classify-audit-findings.sh for what is allowed and why.
#
# Formulae are named explicitly rather than via `brew audit --tap`: Homebrew
# skips an untrusted tap's formulae under --tap and exits 0 having audited
# nothing, which reads as a clean run.

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

formulae="$("${here}/tap-formulae.sh" "$@")"
output="$(echo "${formulae}" | xargs brew audit --strict --online --except=version 2>&1 || true)"

echo "${output}"
echo
printf '%s\n' "${output}" | "${here}/classify-audit-findings.sh"
