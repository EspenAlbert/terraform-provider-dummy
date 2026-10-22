# Finding: a resource type the installed provider does not define is a hard
# error, and count = 0 does not make it go away.
#
# Expected:
#   Error: Invalid resource type
#   The provider ... does not support resource type "hashicups_not_a_resource".

terraform {
  required_version = ">= 1.4"
  required_providers {
    hashicups = {
      source = "hashicorp.com/edu/hashicups"
    }
  }
}

resource "hashicups_not_a_resource" "example" {
  count = 0
}
