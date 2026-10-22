#!/usr/bin/env bash
# Compares the 2.x and 3.x builds on a config that sets a backported attribute.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${DEV_3X_TFRC:?run experiments/run.sh, or export DEV_3X_TFRC to a dev_overrides CLI config}"
: "${DEV_2X_TFRC:?run experiments/run.sh, or export DEV_2X_TFRC to a dev_overrides CLI config}"
export CHECKPOINT_DISABLE=1

pass=0
fail=0
check() {
  local label="$1" pattern="$2" out="$3"
  if printf '%s' "$out" | grep -qE "$pattern"; then
    printf 'PASS  %s\n' "$label"; pass=$((pass + 1))
  else
    printf 'FAIL  %s\n' "$label"; printf '%s\n' "$out" | sed 's/^/      /'; fail=$((fail + 1))
  fi
}

out=$(cd "$here/set" && TF_CLI_CONFIG_FILE="$DEV_3X_TFRC" terraform validate -no-color 2>&1)
check "3.x build accepts a set attribute" 'Success! The configuration is valid' "$out"

out=$(cd "$here/set" && TF_CLI_CONFIG_FILE="$DEV_2X_TFRC" terraform validate -no-color 2>&1)
check "2.x build rejects a set attribute" 'channel requires provider 3.x' "$out"

out=$(cd "$here/unset" && TF_CLI_CONFIG_FILE="$DEV_2X_TFRC" terraform validate -no-color 2>&1)
check "2.x build accepts an unset attribute" 'Success! The configuration is valid' "$out"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
