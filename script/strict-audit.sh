#!/usr/bin/env bash
#
# Run `brew audit --strict` and allow only the findings already known to come
# from GoReleaser's generated output.
#
# A permanently-failing advisory job is a false-green generator: "1 problem" and
# "3 problems" render identically, so a second, real finding hides behind the
# expected one. This asserts which findings are expected, so anything new fails
# the build instead of blending in.
#
# Exits 0 when the only findings are the known ones, 0 with a prompt when the
# upstream fix has landed and there are none, and 1 on anything unexpected.

set -euo pipefail

formula="${1:?usage: strict-audit.sh <tap>/<formula>}"

# Known generator-side findings, one per line, matched as fixed substrings.
# `Formula/cloudgov.rb` uses "#{bin}/cloudgov" in its test block because that is
# what nanohype/cloudgov/.goreleaser.yaml's brews[].test emits. Fixing it here
# is reverted by the next generated formula, so the fix belongs upstream and
# this entry tracks it until then.
# Matched without the backticks audit wraps the code in, so this stays a plain
# single-quoted string; "#{bin}/cloudgov" is the anti-pattern audit names and is
# unambiguous on its own.
expected_findings='#{bin}/cloudgov'

is_expected() {
  local candidate="$1" allowed
  while IFS= read -r allowed
  do
    if [[ -n ${allowed} ]] && [[ ${candidate} == *"${allowed}"* ]]
    then
      return 0
    fi
  done <<<"${expected_findings}"
  return 1
}

output="$(brew audit --strict --online --except=version "${formula}" 2>&1 || true)"
echo "${output}"

findings_total=0
unexpected_total=0
unexpected_list=""

while IFS= read -r line
do
  if [[ ${line} =~ ^[[:space:]]*\*[[:space:]]+(.+)$ ]]
  then
    finding="${BASH_REMATCH[1]}"
    findings_total=$((findings_total + 1))
    if is_expected "${finding}"
    then
      continue
    fi
    unexpected_total=$((unexpected_total + 1))
    unexpected_list="${unexpected_list}  * ${finding}"$'\n'
  fi
done <<<"${output}"

echo
if [[ ${unexpected_total} -ne 0 ]]
then
  echo "strict audit reported ${unexpected_total} finding(s) that are not known" >&2
  echo "generator output:" >&2
  printf '%s' "${unexpected_list}" >&2
  exit 1
fi

if [[ ${findings_total} -eq 0 ]]
then
  echo "strict audit is clean: the upstream fix has landed."
  echo "Drop script/strict-audit.sh and run brew audit --strict directly."
  exit 0
fi

echo "${findings_total} known generator-side finding(s), all tracked upstream."
echo "No new findings."
