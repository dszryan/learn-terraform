
##################################################################################
# CONFIGURATION - added for Terraform 0.14
##################################################################################
terraform {
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~>3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~>1.0"
    }
  }

#   backend "gcs" {     ## SHOULD REALLY BE VAULT
#     deploy_credentials = "./${var.deploy_service_account}-keyfile.json"
#     bucket      = "${var.project_id}-terraform-state"
#     prefix      = "terraform/state"
#   }  

}


##################################################################################
# PROVIDERS
##################################################################################
provider "google" {
  project   = var.project_id
  region    = var.region
}

provider "kubernetes" {
  host                   = "https://${module.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.ca_certificate,)
}

##################################################################################
# LOCALS
##################################################################################
locals {
  zones                   = ["${var.region}-a", "${var.region}-b", "${var.region}-c"]

  # node_pools_name         = "${var.cluster_name}-node-pool"

}

##################################################################################
# DATA SOURCES
##################################################################################

data "google_client_config" "default" {}

data "google_container_cluster" "deployed_cluster" {
  name      = var.cluster_name
  location  = var.region
}

# data "google_service_account_access_token" "deployed_cluster_sa" {
#   target_service_account = "${var.deploy_service_account}@${var.project_id}.iam.gserviceaccount.com"
#   scopes                 = ["userinfo-email", "cloud-platform"]
#   lifetime               = "3600s"
# }

##################################################################################
# MODULES / RESOURCSE
##################################################################################

## NETWORK
module "gcp-network" {
  source       = "terraform-google-modules/network/google"
  project_id   = var.project_id
  network_name = var.network

  subnets = [
    {
      subnet_name   = var.subnetwork
      subnet_ip     = "10.0.0.0/17"
      subnet_region = var.region
    },
  ]

  secondary_ranges = {
    "${var.subnetwork}" = [
      {
        range_name    = var.ip_range_pods_name
        ip_cidr_range = "192.168.0.0/18"        #should keep these are variables
      },
      {
        range_name    = var.ip_range_services_name
        ip_cidr_range = "192.168.64.0/18"       #should keep these are variabless
      },
    ]
  }
}

## CONTAINER ENGINE
module "gke" {
  source                        = "terraform-google-modules/kubernetes-engine/google"
  project_id                    = var.project_id
  name                          = var.cluster_name
  region                        = var.region
  zones                         = local.zones
  network                       = module.gcp-network.network_name
  subnetwork                    = module.gcp-network.subnets_names[0]
  ip_range_pods                 = var.ip_range_pods_name
  ip_range_services             = var.ip_range_services_name
  http_load_balancing           = false
  horizontal_pod_autoscaling    = true
  network_policy                = true
  remove_default_node_pool      = true

  node_pools = [
    {
      name                = "default-node-pool"
      machine_type        = var.machine_type
      min_count           = var.min_count
      max_count           = var.max_count
      disk_size_gb        = var.disk_size_gb
      disk_type           = "pd-standard"
      image_type          = "COS"
      auto_repair         = true
      auto_upgrade        = true
      service_account     = "${var.node_service_account}@${var.project_id}.iam.gserviceaccount.com"
      preemptible         = false
      initial_node_count  = var.initial_node_count
    },
  ]

  node_pools_oauth_scopes = {
    all = []

    default-node-pool = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  node_pools_labels = {
    all = {}

    default-node-pool = {
      default-node-pool = true
    }
  }

  node_pools_metadata = {
    all = {}

    default-node-pool = {
      node-pool-metadata-custom-value = "my-node-pool"
    }
  }

  node_pools_taints = {
    all = []

    default-node-pool = [
      {
        key    = "default-node-pool"
        value  = true
        effect = "PREFER_NO_SCHEDULE"
      },
    ]
  }

  node_pools_tags = {
    all = []

    default-node-pool = [
      "default-node-pool",
    ]
  }
}

## KUBE CONFIG
resource "null_resource" "set-kube-config" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${var.cluster_name} --region ${var.region}"
  }

  depends_on = [module.gke]
}

## K8S - NAMESPACE
resource "kubernetes_namespace" "istio_system" {
  provider = kubernetes
  metadata {
    name = "istio-system"
  }
}

## RANDOM PASSWORD
resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

## K8S - SETUP ACCOUNTS
resource "kubernetes_secret" "grafana" {
  provider = kubernetes
  metadata {
    name      = "grafana"
    namespace = "istio-system"
    labels = {
      app = "grafana"
    }
  }
  data = {
    username   = "admin"
    passphrase = random_password.password.result
  }
  type       = "Opaque"
  depends_on = [kubernetes_namespace.istio_system]
}

resource "kubernetes_secret" "kiali" {
  provider = kubernetes
  metadata {
    name      = "kiali"
    namespace = "istio-system"
    labels = {
      app = "kiali"
    }
  }
  data = {
    username   = "admin"
    passphrase = random_password.password.result
  }
  type       = "Opaque"
  depends_on = [kubernetes_namespace.istio_system]
}

# ## K8S - ISTIO
# resource "null_resource" "istio" {
#   triggers = {
#     always_run = "${timestamp()}"
#   }
#   provisioner "local-exec" {
#     command = "istioctl install -y -f .istio/istio.yaml"
#   }
#   depends_on = [kubernetes_secret.grafana, kubernetes_secret.kiali]
# }
