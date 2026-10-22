#!/usr/bin/env bash
# Reproduces the staged-opt-in migration. Uses terraform_data, so it needs no
# provider and no network.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export CHECKPOINT_DISABLE=1
# The app configs reference a local module, so init has to install it.
export TF_CLI_ARGS_init=

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

v1_module() {
  cat >"$1/main.tf" <<'EOF'
terraform { required_version = ">= 1.4" }
resource "terraform_data" "old" { input = "order" }
EOF
}

caller() {
  cat >"$1/main.tf" <<'EOF'
terraform { required_version = ">= 1.4" }
module "order" { source = "./module" }
EOF
}

app="$work/app"
mkdir -p "$app/module"
v1_module "$app/module"
caller "$app"
(cd "$app" && terraform init -no-color >/dev/null 2>&1 && terraform apply -auto-approve -no-color >/dev/null 2>&1)

# Upgrade to the module version with count and the move.
cp "$here/module/main.tf" "$app/module/main.tf"
out=$(cd "$app" && terraform plan -no-color 2>&1)
check "existing caller upgrades with a move" 'module.order.terraform_data.old has moved to module.order.terraform_data.old\[0\]' "$out"
check "existing caller upgrade has no changes" '0 to add, 0 to change, 0 to destroy' "$out"
(cd "$app" && terraform apply -auto-approve -no-color >/dev/null 2>&1)

# The same upgrade with the module's move block stripped out. Terraform still
# moves the singleton, so that block is for readability only.
nomove="$work/nomove"
mkdir -p "$nomove/module"
v1_module "$nomove/module"
caller "$nomove"
(cd "$nomove" && terraform init -no-color >/dev/null 2>&1 && terraform apply -auto-approve -no-color >/dev/null 2>&1)
sed '/^moved {/,/^}/d' "$here/module/main.tf" >"$nomove/module/main.tf"
out=$(cd "$nomove" && terraform plan -no-color 2>&1)
check "upgrade without the module's move still moves the singleton" 'module.order.terraform_data.old has moved to module.order.terraform_data.old\[0\]' "$out"
check "upgrade without the module's move has no changes" '0 to add, 0 to change, 0 to destroy' "$out"

# Opt in: variable flip plus the root-level move, in one apply.
# The repo copy points at ../module; the app has the module at ./module.
sed 's#"\.\./module"#"./module"#' "$here/opt-in/main.tf" >"$app/main.tf"
out=$(cd "$app" && terraform plan -no-color 2>&1)
check "opt-in move is clean" 'module.order.terraform_data.old\[0\] has moved to module.order.terraform_data.new\[0\]' "$out"
check "opt-in move has no changes" '0 to add, 0 to change, 0 to destroy' "$out"

# Footgun: opt in without the root-level move.
bad="$work/bad"
mkdir -p "$bad/module"
v1_module "$bad/module"
caller "$bad"
(cd "$bad" && terraform init -no-color >/dev/null 2>&1 && terraform apply -auto-approve -no-color >/dev/null 2>&1)
cp "$here/module/main.tf" "$bad/module/main.tf"
(cd "$bad" && terraform apply -auto-approve -no-color >/dev/null 2>&1)
cat >"$bad/main.tf" <<'EOF'
terraform { required_version = ">= 1.4" }
module "order" {
  source          = "./module"
  use_3x_features = true
}
EOF
out=$(cd "$bad" && terraform plan -no-color 2>&1)
check "opting in without the move destroys the legacy resource" 'will be destroyed' "$out"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
