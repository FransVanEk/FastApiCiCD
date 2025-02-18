# Providers
terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

provider "kubernetes" {
  host                   = digitalocean_kubernetes_cluster.my_cluster.endpoint
  token                  = digitalocean_kubernetes_cluster.my_cluster.kube_config[0].token
  cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.my_cluster.kube_config[0].cluster_ca_certificate)
}

# Kubernetes Cluster
resource "digitalocean_kubernetes_cluster" "my_cluster" {
  name    = var.cluster_name
  region  = var.region
  version = "1.32.1-do.0"

  node_pool {
    name       = "webapi-compleet"
    size       = "s-1vcpu-2gb"
    node_count = var.node_count
  }
}

# Kubernetes Namespaces
resource "kubernetes_namespace" "app_namespace" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_namespace" "monitoring_namespace" {
  metadata {
    name = var.monitoring_namespace
  }
}

# Docker Registry Secret
resource "kubernetes_secret" "docker_registry" {
  metadata {
    name      = "docker-registry"
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
  }
  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "${var.docker_server}" = {
          username = var.docker_username
          password = var.do_token
          email    = var.docker_email
        }
      }
    })
  }
}

# Website Deployment
resource "kubernetes_deployment" "website" {
  metadata {
    name      = "website"
    namespace = var.namespace
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "website"
      }
    }
    template {
      metadata {
        labels = {
          app = "website"
        }
      }
      spec {
        image_pull_secrets {
          name = kubernetes_secret.docker_registry.metadata[0].name
        }
        container {
          name  = "website"
          image = "registry.digitalocean.com/devops-cicd/fast-api:latest"
          image_pull_policy = "Always"
          port {
            container_port = 8000
          }
          env {
            name  = "DATABASE_URL"
            value = "postgresql://${var.db_user}:${var.db_password}@${var.db_host}:${var.db_port}/${var.db_name}?sslmode=${var.sslmode}"
          }
        }
      }
    }
  }
}

# Kubernetes Service
resource "kubernetes_service" "webapi-loadbalancer" {
  metadata {
    name      = "webapi-loadbalancer"
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
  }

  spec {
    selector = {
      app = "website"
    }

    port {
      protocol    = "TCP"
      port        = 80
      target_port = 8000
    }

    type = "LoadBalancer"
  }
}
