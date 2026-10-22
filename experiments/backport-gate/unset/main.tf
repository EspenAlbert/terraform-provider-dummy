# Finding: the final 2.x build accepts the config when the attribute is unset,
# so a caller who does not use the feature is unaffected.
#
# Expected with either build: Success! The configuration is valid

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
  items = [{
    coffee   = { id = 3 }
    quantity = 2
  }]
}
