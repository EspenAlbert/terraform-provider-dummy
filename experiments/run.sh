#!/usr/bin/env bash
# Builds the provider variants and runs every experiment.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$root/.." && pwd)"
export CHECKPOINT_DISABLE=1

# Keep every terraform init offline. Local module installs clear this explicitly.
export TF_CLI_ARGS_init=-get=false

echo "== building provider variants =="
make -C "$repo" build build-2x

export DEV_3X_TFRC="$root/dev-3x.tfrc"
export DEV_2X_TFRC="$root/dev-2x.tfrc"
printf 'provider_installation {\n  dev_overrides {\n    "hashicorp.com/edu/hashicups" = "%s/bin"\n  }\n  direct {}\n}\n' "$repo" >"$DEV_3X_TFRC"
printf 'provider_installation {\n  dev_overrides {\n    "hashicorp.com/edu/hashicups" = "%s/bin-2x"\n  }\n  direct {}\n}\n' "$repo" >"$DEV_2X_TFRC"

status=0
for experiment in schema-validation backport-gate moved-matrix staged-opt-in; do
  echo
  echo "===== $experiment ====="
  bash "$root/$experiment/run.sh" || status=1
done

echo
if [ "$status" -eq 0 ]; then
  echo "all experiments passed"
else
  echo "some experiments failed"
fi
exit "$status"
