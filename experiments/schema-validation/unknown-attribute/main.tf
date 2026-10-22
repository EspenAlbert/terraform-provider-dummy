# Finding: an attribute the installed provider does not define is a hard error,
# and the error does not depend on count or on the value being null.
#
# Expected:
#   Error: Unsupported argument
#   An argument named "not_a_real_field" is not expected here.

terraform {
  required_version = ">= 1.4"
  required_providers {
    hashicups = {
      source = "hashicorp.com/edu/hashicups"
    }
  }
}

provider "hashicups" {
  host     = "http://localhost:19090"
  username = "education"
  password = "test123"
}

resource "hashicups_order" "example" {
  not_a_real_field = "x"
  items = [{
    coffee   = { id = 3 }
    quantity = 2
  }]
}
