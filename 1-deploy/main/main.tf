# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A GKE PRIVATE CLUSTER IN GOOGLE CLOUD PLATFORM
# This is an example of how to use the gke-cluster module to deploy a private Kubernetes cluster in GCP
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  required_version = ">= 0.13"

  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# PREPARE PROVIDERS
# ---------------------------------------------------------------------------------------------------------------------

provider "google" {
  version = "~> 3.43.0"
  project = var.project
  region  = var.region

  scopes = [
    # Default scopes
    "https://www.googleapis.com/auth/compute",
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/ndev.clouddns.readwrite",
    "https://www.googleapis.com/auth/devstorage.full_control",

    # Required for google_client_openid_userinfo
    "https://www.googleapis.com/auth/userinfo.email",
  ]
}

provider "google-beta" {
  version = "~> 3.43.0"
  project = var.project
  region  = var.region

  scopes = [
    # Default scopes
    "https://www.googleapis.com/auth/compute",
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/ndev.clouddns.readwrite",
    "https://www.googleapis.com/auth/devstorage.full_control",

    # Required for google_client_openid_userinfo
    "https://www.googleapis.com/auth/userinfo.email",
  ]
}

# We use this data provider to expose an access token for communicating with the GKE cluster.
data "google_client_config" "client" {}

data "google_container_cluster" "my_cluster" {
  name     = var.cluster_name
  project  = var.project
  location = var.location
}

provider "kubernetes" {
  version = "~> 1.7.0"

  load_config_file       = false
  host                   = "https://${data.google_container_cluster.my_cluster.endpoint}"
  token                  = data.google_client_config.client.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.my_cluster.master_auth.0.cluster_ca_certificate)
}

provider "kubernetes-alpha" {
  server_side_planning = true

  # load_config_file       = false
  host                   = "https://${data.google_container_cluster.my_cluster.endpoint}"
  token                  = data.google_client_config.client.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.my_cluster.master_auth.0.cluster_ca_certificate)
}

provider "kubectl" {

  load_config_file       = false
  host                   = "https://${data.google_container_cluster.my_cluster.endpoint}"
  token                  = data.google_client_config.client.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.my_cluster.master_auth.0.cluster_ca_certificate)
}

provider "helm" {
  # Use provider with Helm 3.x support
  version = "~> 1.1.1"

  kubernetes {

    load_config_file       = false
    host                   = "https://${data.google_container_cluster.my_cluster.endpoint}"
    token                  = data.google_client_config.client.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.my_cluster.master_auth.0.cluster_ca_certificate)
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# RESOURCES
# ---------------------------------------------------------------------------------------------------------------------
locals {
  container = {
    static = {
      name = "static-content"
      image = "gcr.io/ageless-fire-302600/hello-app:latest"
      port = {
        container = 8080
        service = 80
      }
      instances = {
        intial = 2
        min = 1
        max = 5
      }
    }
    dynamic = {
      name = "dynamic-content"
      image = "gcr.io/ageless-fire-302600/hello-app"
      port = {
        container = 8080
        service = 80
      }
      instances = {
        intial = 2
        min = 1
        max = 5
      }
    }
  }
} 

## workaround
resource "null_resource" "namespace-auto-inject-development" {
  provisioner "local-exec" {
    command = "kubectl label namespace development istio-injection=enabled --overwrite"
  }
}

## workaround
resource "null_resource" "namespace-auto-inject-production" {
  provisioner "local-exec" {
    command = "kubectl label namespace production istio-injection=enabled --overwrite"
  }
}

resource "kubernetes_deployment" "static-content" {
  provider = kubernetes

  metadata {
    name      = local.container.static.name
    namespace = var.environment
    labels = {
      app = local.container.static.name
    }
  }

  spec {
    replicas = local.container.static.instances.intial

    selector {
      match_labels = {
        app = local.container.static.name
      }
    }

    template {
      metadata {
        labels = {
          app = local.container.static.name
        }
      }

      spec {
        container {
          image = local.container.static.image
          name  = local.container.static.name

          port {
            container_port = local.container.static.port.container
          }
        }
      }
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "static-content" {
  metadata {
    name = local.container.static.name
  }

  spec {
    max_replicas = local.container.static.instances.max
    min_replicas = local.container.static.instances.min

    scale_target_ref {
      kind = "Deployment"
      name = local.container.static.name
    }
  }
}

resource "kubernetes_service" "static-content" {
  provider = kubernetes

  metadata {
    name      = local.container.static.name
    namespace = var.environment
  }
  spec {
    selector = {
      app = local.container.static.name
    }
    type = "NodePort"
    port {
      port        = local.container.static.port.service
      target_port = local.container.static.port.container
    }
  }
}

resource "kubernetes_manifest" "static-content-gateway" {
  provider = kubernetes-alpha

  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "Gateway"
    metadata = {
      name      = "${local.container.static.name}-gateway"
      namespace = var.environment
      labels = {
        app = local.container.static.name
      }
    }
    spec = {
      selector = {
        istio = "ingressgateway"
      }
      servers = [
        {
          port = {
            number   = local.container.static.port.service
            protocol = "HTTP"
            name     = "http"
          }
          hosts = ["*"]
        }
      ]
    }
  }
}

resource "kubernetes_manifest" "static-content-virtual-service" {
  provider = kubernetes-alpha

  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "VirtualService"
    metadata = {
      name      = "${local.container.static.name}-virtual-service"
      namespace = var.environment
      labels = {
        app = local.container.static.name
      }
    }
    spec = {
      hosts = ["*"]
      gateways = ["${local.container.static.name}-gateway"]
      http = [
        {
          match = [
            {
              uri = {
                prefix = "/static"
              }
            }
          ]
          route = [
            {
              destination = {
                host = local.container.static.name
                port = {
                  number = local.container.static.port.service
                }
              }
              timeouts = "5s"
              retries = {
                attempts = 2
                perTryTimeout = "5s"
                retryOn = "5xx"
              }
            }
          ]
        }
      ]
    }
  }
}

resource "kubernetes_deployment" "dynamic-content-v1" {
  provider = kubernetes

  metadata {
    name      = "${local.container.dynamic.name}-v1"
    namespace = var.environment
    labels = {
      app = local.container.dynamic.name
      version = "v1"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = local.container.dynamic.name
        version = "v1"
      }
    }

    template {
      metadata {
        labels = {
          app = local.container.dynamic.name
          version = "v1"
        }
      }

      spec {
        container {
          image = "${local.container.dynamic.image}:v1"
          name  = local.container.dynamic.name

          port {
            container_port = local.container.dynamic.port.container
          }
        }
      }
    }
  }
}

resource "kubernetes_deployment" "dynamic-content-v2" {
  provider = kubernetes

  metadata {
    name      = "${local.container.dynamic.name}-v2"
    namespace = var.environment
    labels = {
      app = local.container.dynamic.name
      version = "v2"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = local.container.dynamic.name
        version = "v2"
      }
    }

    template {
      metadata {
        labels = {
          app = local.container.dynamic.name
          version = "v2"
        }
      }

      spec {
        container {
          image = "${local.container.dynamic.image}:v2"
          name  = local.container.dynamic.name

          port {
            container_port = local.container.dynamic.port.container
          }
        }
      }
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "dynamic-content" {
  metadata {
    name = local.container.dynamic.name
  }

  spec {
    max_replicas = local.container.dynamic.instances.max
    min_replicas = local.container.dynamic.instances.min

    scale_target_ref {
      kind = "Deployment"
      name = local.container.dynamic.name
    }
  }
}

resource "kubernetes_service" "dynamic-content" {
  provider = kubernetes

  metadata {
    name      = local.container.dynamic.name
    namespace = var.environment
  }
  spec {
    selector = {
      app = local.container.dynamic.name
    }
    type = "NodePort"
    port {
      port        = local.container.dynamic.port.service
      target_port = local.container.dynamic.port.container
    }
  }
}

resource "kubernetes_manifest" "dynamic-content-gateway" {
  provider = kubernetes-alpha

  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "Gateway"
    metadata = {
      name      = "${local.container.dynamic.name}-gateway"
      namespace = var.environment
      labels = {
        app = local.container.dynamic.name
      }
    }
    spec = {
      selector = {
        istio = "ingressgateway"
      }
      servers = [
        {
          port = {
            number   = local.container.dynamic.port.service
            protocol = "HTTP"
            name     = "http"
          }
          hosts = ["*"]
        }
      ]
    }
  }
}

resource "kubernetes_manifest" "dynamic-content-virtual-service" {
  provider = kubernetes-alpha

  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "VirtualService"
    metadata = {
      name      = "${local.container.dynamic.name}-virtual-service"
      namespace = var.environment
      labels = {
        app = local.container.dynamic.name
      }
    }
    spec = {
      hosts = ["*"]
      gateways = ["${local.container.dynamic.name}-gateway"]
      http = [
        {
          match = [
            {
              uri = {
                prefix = "/"
              }
            },
            {
              headers = {
                end-user = {
                  exact = "tester"
                }
              }
            }
          ]
          route = [
            {
              destination = {
                host = local.container.dynamic.name
                subset = "v2"
                port = {
                  number = local.container.dynamic.port.service
                }
              }
            }
          ]
        }
      ]
    }
  }
}

resource "kubernetes_manifest" "dynamic-content-destination-rule" {
  provider = kubernetes-alpha

  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "DestinationRule"
    metadata = {
      name      = "${local.container.dynamic.name}-destination-rule"
      namespace = var.environment
      labels = {
        app = local.container.dynamic.name
      }
    }
    spec = {
      host = local.container.dynamic.name
      trafficPolicy = {
        tls = {
          mode = "ISTIO_MUTUAL"
        }
      }
      subnets = [
        {
          name = "v1"
          labels = {
            version = "v1"
          }
        },
        {
          name = "v2"
          labels = {
            version = "v2"
          }
        }
      ]
    }
  }
}
