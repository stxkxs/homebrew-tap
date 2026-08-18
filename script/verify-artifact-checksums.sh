#!/usr/bin/env bash
#
# Verify that every (url, sha256) pair declared in this tap's formulae matches
# the artifact actually published at that URL.
#
# `brew test` only exercises the runner's own platform, which leaves the other
# platforms' checksums unverified. This tap is a channel that executes code on
# user machines, so every declared checksum gets checked, not just the one the
# CI runner happens to install.
#
# Fails on the first mismatch. A checksum gate that warns is not a gate.

set -euo pipefail

formula_dir="${1:-Formula}"

if [[ ! -d ${formula_dir} ]]
then
  echo "error: no formula directory at '${formula_dir}'" >&2
  exit 1
fi

sha256_of_stdin() {
  if command -v sha256sum >/dev/null 2>&1
  then
    sha256sum | cut -d' ' -f1
  else
    shasum -a 256 | cut -d' ' -f1
  fi
}

# `url` is always immediately followed by its `sha256` in a formula, so pairing
# them in document order is sound. Emits "<url> <sha256>" per line.
declared_pairs() {
  awk '
    /^[[:space:]]*url[[:space:]]+"/ {
      line = $0
      sub(/^[[:space:]]*url[[:space:]]+"/, "", line)
      sub(/".*$/, "", line)
      url = line
      next
    }
    /^[[:space:]]*sha256[[:space:]]+"/ {
      if (url == "") next
         line = $0
         sub(/^[[:space:]]*sha256[[:space:]]+"/, "", line)
         sub(/".*$/, "", line)
         print url " " line
         url = ""
         }
         ' "$1"
         }
         
         total=0
         failed=0
         
         for formula in "${formula_dir}"/*.rb; do
         if [[ ! -e ${formula} ]]
      then
    echo "error: no formulae in '${formula_dir}'" >&2
    exit 1
  fi

  pairs_in_formula=0
  while read -r url declared
  do
    if [[ -z ${url} ]]
    then
      continue
    fi
    pairs_in_formula=$((pairs_in_formula + 1))
    total=$((total + 1))

    printf '%s\n  %s\n' "${formula}" "${url}"

    actual="$(curl --fail --silent --show-error --location \
      --retry 3 --retry-delay 2 --retry-all-errors \
      "${url}" | sha256_of_stdin)"

    if [[ ${actual} == "${declared}" ]]
    then
      printf '  ok   %s\n' "${actual}"
    else
      printf '  FAIL declared %s\n       actual   %s\n' "${declared}" "${actual}"
      failed=$((failed + 1))
    fi
  done <<<"$(declared_pairs "${formula}")"

  if [[ ${pairs_in_formula} -eq 0 ]]
  then
    echo "error: no url/sha256 pairs parsed from '${formula}'" >&2
    exit 1
  fi
done

echo
if [[ ${failed} -ne 0 ]]
then
  echo "${failed} of ${total} declared checksums do not match the published artifact" >&2
  exit 1
fi

echo "all ${total} declared checksums match the published artifacts"
