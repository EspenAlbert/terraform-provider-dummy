# Module version 2: the legacy resource is wrapped in count and a move is
# shipped so an existing caller upgrades without a recreate. The new resource is
# gated by use_3x_features.
terraform {
  required_version = ">= 1.4"
}

variable "use_3x_features" {
  description = "Opt in to the new resource. The default keeps the legacy resource."
  type        = bool
  default     = false
}

resource "terraform_data" "old" {
  count = var.use_3x_features ? 0 : 1
  input = "order"
}

resource "terraform_data" "new" {
  count = var.use_3x_features ? 1 : 0
  input = "order"
}

# Optional. Terraform moves the singleton to old[0] on its own when count is
# added to a resource that had none; the block is here because the Terraform
# docs recommend writing it for readability. The move that actually matters is
# the caller's root-level one, in opt-in/main.tf.
moved {
  from = terraform_data.old
  to   = terraform_data.old[0]
}
