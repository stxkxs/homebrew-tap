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
# Every checksum in the file is checked; each mismatch is reported and the run
# exits non-zero if any failed. The parsed pair count is asserted against the
# number of sha256 lines in the formula, so a formula shape this parser does not
# understand fails loudly rather than being silently verified in part. A
# checksum gate that reports success over partial coverage is not a gate.

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

# A formula's `url` is always immediately followed by its `sha256`, so pairing
# them in document order is sound. Emits "<url> <sha256>" per line.
declared_pairs() {
  local line url=""
  while IFS= read -r line
  do
    if [[ ${line} =~ ^[[:space:]]*url[[:space:]]+\"([^\"]+)\" ]]
    then
      url="${BASH_REMATCH[1]}"
    elif [[ ${line} =~ ^[[:space:]]*sha256[[:space:]]+\"([^\"]+)\" ]]
    then
      if [[ -n ${url} ]]
      then
        printf '%s %s\n' "${url}" "${BASH_REMATCH[1]}"
        url=""
      fi
    fi
  done <"$1"
}

declared_sha256_count() {
  grep -c -E '^[[:space:]]*sha256[[:space:]]+"' "$1" || true
}

total=0
failed=0

for formula in "${formula_dir}"/*.rb
do
  if [[ ! -e ${formula} ]]
  then
    echo "error: no formulae in '${formula_dir}'" >&2
    exit 1
  fi

  verified_in_formula=0
  while read -r url declared
  do
    if [[ -z ${url} ]]
    then
      continue
    fi
    verified_in_formula=$((verified_in_formula + 1))
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

  # The guarantee is "every declared sha256 was checked", not "at least one
  # was". Anything this parser could not pair is a coverage hole, and a
  # coverage hole in a checksum gate reads as success.
  declared_count="$(declared_sha256_count "${formula}")"
  if [[ ${verified_in_formula} -ne ${declared_count} ]]
  then
    echo "error: '${formula}' declares ${declared_count} sha256 value(s) but" >&2
    echo "       ${verified_in_formula} could be paired with a url and checked." >&2
    echo "       Refusing to report success over partial coverage." >&2
    exit 1
  fi

  if [[ ${declared_count} -eq 0 ]]
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
