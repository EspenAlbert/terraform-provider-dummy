#!/usr/bin/env bash
# Runs the schema-validation experiments against the 3.x build.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${DEV_3X_TFRC:?run experiments/run.sh, or export DEV_3X_TFRC to a dev_overrides CLI config}"
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

out=$(cd "$here/unknown-attribute" && TF_CLI_CONFIG_FILE="$DEV_3X_TFRC" terraform validate -no-color 2>&1)
check "an unknown attribute is rejected" 'An argument named "not_a_real_field" is not expected here' "$out"

out=$(cd "$here/unknown-resource-type" && TF_CLI_CONFIG_FILE="$DEV_3X_TFRC" terraform validate -no-color 2>&1)
check "an unknown resource type is rejected at count = 0" 'does not support resource type' "$out"

(cd "$here/count-zero-and-submodule" && TF_CLI_ARGS_init= TF_CLI_CONFIG_FILE="$DEV_3X_TFRC" terraform init -no-color >/dev/null 2>&1)
out=$(cd "$here/count-zero-and-submodule" && TF_CLI_CONFIG_FILE="$DEV_3X_TFRC" terraform validate -no-color 2>&1)
check "an unknown type in a count = 0 submodule is rejected" 'does not support resource type' "$out"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
