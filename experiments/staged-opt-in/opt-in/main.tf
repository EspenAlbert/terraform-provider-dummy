# Opt-in caller: the variable flip and the root-level move must land in the same
# apply. Without the move the legacy resource is destroyed and recreated. See
# run.sh for that case.
terraform {
  required_version = ">= 1.4"
}

moved {
  from = module.order.terraform_data.old[0]
  to   = module.order.terraform_data.new[0]
}

module "order" {
  source          = "../module"
  use_3x_features = true
}
