# Finding: with the 3.x build the attribute is implemented and the config is
# valid.
#
# Expected with the 3.x build: Success! The configuration is valid
# Expected with the 2.x build: Error: channel requires provider 3.x

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
  channel = "partner"
  items = [{
    coffee   = { id = 3 }
    quantity = 2
  }]
}
