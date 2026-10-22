# Finding: the same hard error applies to a resource declared inside a module
# that is itself disabled with count = 0. Terraform validates a module's
# contents regardless of the module's count.

terraform {
  required_version = ">= 1.4"
  required_providers {
    hashicups = {
      source = "hashicorp.com/edu/hashicups"
    }
  }
}

module "child" {
  source = "./child"
  count  = 0
}
