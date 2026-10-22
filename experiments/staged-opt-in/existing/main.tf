# Existing caller: uses the default, so it keeps the legacy resource. Upgrading
# to the module version above moves the resource with no other change.
terraform {
  required_version = ">= 1.4"
}

module "order" {
  source = "../module"
}
