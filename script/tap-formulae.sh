#!/usr/bin/env bash
#
# Print the fully-qualified name of every formula in this tap, one per line.
#
# Every gate step derives its subject from this rather than naming a formula, so
# adding a formula to the tap does not require remembering to edit CI. Exits
# non-zero on an empty tap: a step handed an empty list would pass while
# checking nothing.

set -euo pipefail

tap="${1:-nanohype/tap}"
formula_dir="${2:-Formula}"

count=0
for formula in "${formula_dir}"/*.rb
do
  if [[ ! -e ${formula} ]]
  then
    break
  fi
  echo "${tap}/$(basename "${formula}" .rb)"
  count=$((count + 1))
done

if [[ ${count} -eq 0 ]]
then
  echo "error: no formulae found in '${formula_dir}'" >&2
  exit 1
fi
