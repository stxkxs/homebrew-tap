#!/usr/bin/env bash
#
# Read `brew audit` output on stdin and allow only the findings already known to
# come from GoReleaser's generated formulae, scoped to the formula that produces
# them.
#
# A permanently-failing advisory step is a false-green generator: "1 problem" and
# "3 problems" render identically, so a second, real finding hides behind the
# expected one. This asserts which findings are expected, per formula, so
# anything new fails the build instead of blending in.
#
# Exits 0 when the only findings are known ones, 0 with a prompt when there are
# none, and 1 on anything unexpected or on an audit that did not run cleanly.

set -euo pipefail

# "<formula>|<substring>", one per line. `Formula/cloudgov.rb` uses
# "#{bin}/cloudgov" in its test block because that is what
# nanohype/cloudgov/.goreleaser.yaml's brews[].test emits. Fixing it in the tap
# is reverted by the next generated formula, so the fix belongs upstream and this
# entry tracks it until then.
#
# Keyed by formula so a second formula cannot inherit another's allowance.
expected_findings='cloudgov|#{bin}/cloudgov'

is_expected() {
  local formula="$1" finding="$2" entry key pattern
  while IFS= read -r entry
  do
    if [[ -z ${entry} ]]
    then
      continue
    fi
    key="${entry%%|*}"
    pattern="${entry#*|}"
    if [[ ${formula} == "${key}" ]] && [[ ${finding} == *"${pattern}"* ]]
    then
      return 0
    fi
  done <<<"${expected_findings}"
  return 1
}

current=""
findings=0
unexpected=0
unexpected_list=""

while IFS= read -r line
do
  # Any brew error other than its own findings summary means the audit did not
  # run as intended. An untrusted tap reports "Refusing to load formula" and
  # produces no findings at all, which would otherwise read as a clean audit.
  if [[ ${line} == Error:* ]] && [[ ! ${line} =~ ^Error:[[:space:]][0-9]+[[:space:]]problem ]]
  then
    echo "audit did not run cleanly: ${line}" >&2
    exit 1
  fi

  if [[ ${line} =~ ^([^[:space:]/]+/[^[:space:]]+)$ ]]
  then
    current="${BASH_REMATCH[1]##*/}"
    continue
  fi

  if [[ ${line} =~ ^[[:space:]]*\*[[:space:]]+(.+)$ ]]
  then
    finding="${BASH_REMATCH[1]}"
    findings=$((findings + 1))
    if [[ -z ${current} ]]
    then
      unexpected=$((unexpected + 1))
      unexpected_list="${unexpected_list}  * (unattributed) ${finding}"$'\n'
      continue
    fi
    if is_expected "${current}" "${finding}"
    then
      continue
    fi
    unexpected=$((unexpected + 1))
    unexpected_list="${unexpected_list}  * ${current}: ${finding}"$'\n'
  fi
done

if [[ ${unexpected} -ne 0 ]]
then
  echo "audit reported ${unexpected} finding(s) that are not known generator output:" >&2
  printf '%s' "${unexpected_list}" >&2
  exit 1
fi

if [[ ${findings} -eq 0 ]]
then
  echo "audit is clean: the upstream fix has landed."
  echo "Drop the allowance in script/classify-audit-findings.sh and run brew audit directly."
  exit 0
fi

echo "${findings} known generator-side finding(s), all tracked upstream. No new findings."
