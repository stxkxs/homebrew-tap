#!/usr/bin/env bash
#
# Tests for script/classify-audit-findings.sh.
#
# That script's entire job is noticing when audit output changes. Verifying it
# by hand once proves nothing about the next change, and it is the component
# most likely to rot silently: an allowance that stops matching, or a parser
# that stops attributing findings to formulae, both fail open.
#
# Runs on synthetic audit output. No Homebrew, no network.

# The fixtures below are verbatim `brew audit` output, backticks included.
# Rewriting them to avoid the backticks shellcheck reads as command
# substitution would stop them being real audit output, which is the only
# thing that makes them worth testing against.
# shellcheck disable=SC2016

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
classifier="${here}/classify-audit-findings.sh"

failures=0

check() {
  local name="$1" want="$2" input="$3" got=0
  printf '%s\n' "${input}" | "${classifier}" >/dev/null 2>&1 || got=$?
  if [[ ${got} -eq ${want} ]]
  then
    printf 'ok    %s\n' "${name}"
  else
    printf 'FAIL  %s: want exit %s, got %s\n' "${name}" "${want}" "${got}"
    failures=$((failures + 1))
  fi
}

check "clean audit passes" 0 ""

check "known finding on its own formula passes" 0 \
  'Error: 1 problem in 1 formula detected.
nanohype/tap/cloudgov
  * line 48, col 12: Use `bin/"cloudgov"` instead of `"#{bin}/cloudgov"`'

check "unknown finding fails" 1 \
  'Error: 1 problem in 1 formula detected.
nanohype/tap/cloudgov
  * line 12, col 3: `desc` should not start with an article'

# The allowance is keyed by formula. A second formula must not inherit it.
check "known finding text on a different formula fails" 1 \
  'Error: 1 problem in 1 formula detected.
nanohype/tap/othertool
  * line 48, col 12: Use `bin/"othertool"` instead of `"#{bin}/cloudgov"`'

check "known plus unknown fails" 1 \
  'Error: 2 problems in 1 formula detected.
nanohype/tap/cloudgov
  * line 48, col 12: Use `bin/"cloudgov"` instead of `"#{bin}/cloudgov"`
  * line 12, col 3: `desc` should not start with an article'

# An untrusted tap makes `brew audit --tap` skip every formula and exit 0.
# A classifier that only counts findings would call that clean.
check "audit that did not run cleanly fails" 1 \
  'Error: Refusing to load formula nanohype/tap/cloudgov from untrusted tap nanohype/tap.'

check "finding with no formula attributed fails" 1 \
  '  * line 48, col 12: Use `bin/"cloudgov"` instead of `"#{bin}/cloudgov"`'

check "two formulae, one clean one allowed, passes" 0 \
  'Error: 1 problem in 2 formulae detected.
nanohype/tap/cloudgov
  * line 48, col 12: Use `bin/"cloudgov"` instead of `"#{bin}/cloudgov"`
nanohype/tap/othertool'

echo
if [[ ${failures} -ne 0 ]]
then
  echo "${failures} test(s) failed" >&2
  exit 1
fi
echo "all tests passed"
