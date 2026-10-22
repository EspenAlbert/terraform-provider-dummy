#!/usr/bin/env bash
# Reproduces the moved-block findings. Uses terraform_data, so it needs no
# provider and no network.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export CHECKPOINT_DISABLE=1
# Keep init offline. The two module cases clear this, because a local module
# still has to be installed.
export TF_CLI_ARGS_init=-get=false

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

newdir() { local d="$work/$1"; mkdir -p "$d"; printf '%s' "$d"; }
init() { (cd "$1" && terraform init -no-color >/dev/null 2>&1); }
init_modules() { (cd "$1" && TF_CLI_ARGS_init= terraform init -no-color >/dev/null 2>&1); }
plan() { (cd "$1" && terraform plan -no-color 2>&1); }
apply() { (cd "$1" && terraform apply -auto-approve -no-color >/dev/null 2>&1); }

# B1: unconditional move, source in state, destination in config.
d=$(newdir b1)
cat >"$d/main.tf" <<'EOF'
terraform { required_version = ">= 1.4" }
resource "terraform_data" "old" { input = "hello" }
EOF
init "$d"; apply "$d"
cat >"$d/main.tf" <<'EOF'
terraform { required_version = ">= 1.4" }
moved {
  from = terraform_data.old
  to   = terraform_data.new
}
resource "terraform_data" "new" { input = "hello" }
EOF
check "B1 move with source in state is clean" '0 to add, 0 to change, 0 to destroy' "$(plan "$d")"

# B2: unconditional move, source absent.
d=$(newdir b2)
cat >"$d/main.tf" <<'EOF'
terraform { required_version = ">= 1.4" }
moved {
  from = terraform_data.old
  to   = terraform_data.new
}
resource "terraform_data" "new" { input = "hello" }
EOF
init "$d"
out=$(plan "$d")
check "B2 move with source absent is a no-op" '1 to add, 0 to change, 0 to destroy' "$out"
if printf '%s' "$out" | grep -q '^Error:'; then
  printf 'FAIL  B2 move with source absent reports no error\n'; fail=$((fail + 1))
else
  printf 'PASS  B2 move with source absent reports no error\n'; pass=$((pass + 1))
fi

# B3: conditional move.
d=$(newdir b3)
cat >"$d/main.tf" <<'EOF'
terraform { required_version = ">= 1.4" }
moved {
  count = 1
  from  = terraform_data.old
  to    = terraform_data.new
}
resource "terraform_data" "new" { input = "hello" }
EOF
init "$d"
check "B3 conditional move is rejected" 'An argument named "count" is not expected here' "$(plan "$d")"

# B4: source still declared.
d=$(newdir b4)
cat >"$d/main.tf" <<'EOF'
terraform { required_version = ">= 1.4" }
moved {
  from = terraform_data.old
  to   = terraform_data.new
}
resource "terraform_data" "new" { input = "hello" }
resource "terraform_data" "old" { input = "hello" }
EOF
init "$d"
check "B4 source still declared errors" 'Moved object still exists' "$(plan "$d")"

# B5: destination conditionally absent, source in state.
d=$(newdir b5)
cat >"$d/main.tf" <<'EOF'
terraform { required_version = ">= 1.4" }
resource "terraform_data" "old" { input = "hello" }
EOF
init "$d"; apply "$d"
cat >"$d/main.tf" <<'EOF'
terraform { required_version = ">= 1.4" }
moved {
  from = terraform_data.old
  to   = terraform_data.new
}
resource "terraform_data" "new" {
  count = 0
  input = "hello"
}
EOF
check "B5 conditional destination is destroyed, not moved" 'will be destroyed' "$(plan "$d")"

# B6: move shipped inside a module.
d=$(newdir b6); mkdir -p "$d/m"
cat >"$d/m/main.tf" <<'EOF'
terraform { required_version = ">= 1.4" }
resource "terraform_data" "old" { input = "hello" }
EOF
cat >"$d/main.tf" <<'EOF'
terraform { required_version = ">= 1.4" }
module "m" { source = "./m" }
EOF
init_modules "$d"; apply "$d"
cat >"$d/m/main.tf" <<'EOF'
terraform { required_version = ">= 1.4" }
moved {
  from = terraform_data.old
  to   = terraform_data.new
}
resource "terraform_data" "new" { input = "hello" }
EOF
check "B6 move shipped in a module is transparent" 'module.m.terraform_data.old has moved to module.m.terraform_data.new' "$(plan "$d")"

# B7: root-level move into a module.
d=$(newdir b7); mkdir -p "$d/m"
cat >"$d/m/main.tf" <<'EOF'
terraform { required_version = ">= 1.4" }
resource "terraform_data" "old" { input = "hello" }
EOF
cat >"$d/main.tf" <<'EOF'
terraform { required_version = ">= 1.4" }
module "m" { source = "./m" }
EOF
init_modules "$d"; apply "$d"
cat >"$d/m/main.tf" <<'EOF'
terraform { required_version = ">= 1.4" }
resource "terraform_data" "new" { input = "hello" }
EOF
cat >"$d/main.tf" <<'EOF'
terraform { required_version = ">= 1.4" }
moved {
  from = module.m.terraform_data.old
  to   = module.m.terraform_data.new
}
module "m" { source = "./m" }
EOF
check "B7 root-level move into a module works" 'module.m.terraform_data.old has moved to module.m.terraform_data.new' "$(plan "$d")"

# B8: adding count with an explicit move block.
d=$(newdir b8)
cat >"$d/main.tf" <<'EOF'
terraform { required_version = ">= 1.4" }
resource "terraform_data" "old" { input = "hello" }
EOF
init "$d"; apply "$d"
cat >"$d/main.tf" <<'EOF'
terraform { required_version = ">= 1.4" }
resource "terraform_data" "old" {
  count = 1
  input = "hello"
}
moved {
  from = terraform_data.old
  to   = terraform_data.old[0]
}
EOF
check "B8 explicit count conversion is accepted" 'terraform_data.old has moved to terraform_data.old\[0\]' "$(plan "$d")"

# B9: the same conversion with no move block. Terraform does it implicitly.
d=$(newdir b9)
cat >"$d/main.tf" <<'EOF'
terraform { required_version = ">= 1.4" }
resource "terraform_data" "old" { input = "hello" }
EOF
init "$d"; apply "$d"
cat >"$d/main.tf" <<'EOF'
terraform { required_version = ">= 1.4" }
resource "terraform_data" "old" {
  count = 1
  input = "hello"
}
EOF
out=$(plan "$d")
check "B9 adding count moves the singleton with no move block" 'terraform_data.old has moved to terraform_data.old\[0\]' "$out"
check "B9 implicit count conversion has no changes" '0 to add, 0 to change, 0 to destroy' "$out"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
