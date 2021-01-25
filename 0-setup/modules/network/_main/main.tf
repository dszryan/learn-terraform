terraform {
  required_version = ">= 0.12.26"
}

module "management_network" {
  source = "../vpc"

  name_prefix = var.name_prefix
  project     = var.project
  region      = var.region
}
