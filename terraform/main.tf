# Configureer de DigitalOcean provider
terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "~> 2.0"  # Of gebruik de laatste versie die je nodig hebt
    }
  }
}

provider "helm" {
  kubernetes {
    host                   = digitalocean_kubernetes_cluster.my-devops-cluster2.endpoint
    token                  = digitalocean_kubernetes_cluster.my-devops-cluster2.kube_config[0].token
    cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.my-devops-cluster2.kube_config[0].cluster_ca_certificate)
  }
}


provider "digitalocean" {
  token = var.do_token
}

provider "kubernetes" {
  host                   = digitalocean_kubernetes_cluster.my-devops-cluster2.endpoint
  token                  = digitalocean_kubernetes_cluster.my-devops-cluster2.kube_config[0].token
  cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.my-devops-cluster2.kube_config[0].cluster_ca_certificate)
}

# Kubernetes-cluster aanmaken
resource "digitalocean_kubernetes_cluster" "my-devops-cluster2" {
  name     = var.cluster_name
  region   = var.region
  version  = "1.31.1-do.4"  # Specificeer de gewenste Kubernetes-versie
  node_pool {
    name       = "website-with-db"
    size       = "s-1vcpu-2gb"
    node_count      = var.node_count
  }
}

resource "kubernetes_namespace" "namespace_creation" {
  metadata {
    name = var.namespace  
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}


# Kubernetes Secret voor Docker-registry
resource "kubernetes_secret" "do_secret" {
  metadata {
    name      = "do-secret"
    namespace = kubernetes_namespace.namespace_creation.metadata[0].name
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


# PersistentVolumeClaim voor PostgreSQL-opslag
resource "kubernetes_persistent_volume_claim" "postgres_pvc" {
  metadata {
    name      = "postgres-pvc"
    namespace = var.namespace
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

# PostgreSQL Deployment binnen het Kubernetes-cluster
resource "kubernetes_deployment" "postgres" {
  metadata {
    name      = "postgres"
    namespace = var.namespace
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "postgres"
      }
    }
    template {
      metadata {
        labels = {
          app = "postgres"
        }
      }
      spec {
        container {
          name  = "postgres"
          image = "postgres:16"
          port {
            container_port = 5432
          }
          env {
            name  = "POSTGRES_DB"
            value = var.db_name
          }
          env {
            name  = "POSTGRES_USER"
            value = var.db_user
          }
          env {
            name  = "POSTGRES_PASSWORD"
            value = var.db_password
          }
          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }
          volume_mount {
            name       = "postgres-storage"
            mount_path = "/var/lib/postgresql/data"
          }
        }
        volume {
          name = "postgres-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.postgres_pvc.metadata[0].name
          }
        }
      }
    }
  }
}

# Service om PostgreSQL binnen het cluster bereikbaar te maken
resource "kubernetes_service" "postgres" {
  metadata {
    name      = "postgres"
    namespace = var.namespace
  }
  spec {
    selector = {
      app = "postgres"
    }
    port {
      port        = 5432
      target_port = 5432
    }
    type = "ClusterIP"
  }
}

# Website Deployment binnen het Kubernetes-cluster
resource "kubernetes_deployment" "website" {
  metadata {
    name      = "website"
    namespace = var.namespace
  }
  spec {
    replicas = 1
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
          name = kubernetes_secret.do_secret.metadata[0].name
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
            value = "postgresql://${var.db_user}:${var.db_password}@postgres.${var.namespace}.svc.cluster.local:5432/${var.db_name}"
          }
        }
          image_pull_secrets {
          name = "do-secret"
        }
      }
    }
  }
}

# Service om de website extern beschikbaar te maken op poort 8000
resource "kubernetes_service" "website" {
  metadata {
    name      = "website"
    namespace = var.namespace
  }
  spec {
    selector = {
      app = "website"
    }
    port {
      port        = 80
      target_port = 8000
    }
    type = "LoadBalancer"
  }
}
resource "helm_release" "prometheus" {
#  depends_on = [kubernetes_namespace.monitoring, time_sleep.wait_for_kubernetes]
  chart      = "kube-prometheus-stack"
  name       = "prometheus"
  namespace  = "monitoring"
  repository = "https://prometheus-community.github.io/helm-charts"
  version    = "56.3.0"
  values = [
    file("values.yaml")
  ]
  timeout = 2000

  set {
    name  = "podSecurityPolicy.enabled"
    value = true
  }

  set {
    name  = "server.persistentVolume.enabled"
    value = false
  }


  # You can provide a map of value using yamlencode. Don't forget to escape the last element after point in the name
  set {
    name = "server\\.resources"
    value = yamlencode({
      limits = {
        cpu    = "200m"
        memory = "50Mi"
      }
      requests = {
        cpu    = "100m"
        memory = "30Mi"
      }
    })
  }
  set {
    name  = "prometheusOperator.createCustomResource"
    value = true
  }
}