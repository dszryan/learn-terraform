##################################################################################
# MODULES / RESOURCSE
##################################################################################
module "gke" {
  source = "../modules/compute/_main"

  project = var.project
  location = var.location
  region = var.region
}