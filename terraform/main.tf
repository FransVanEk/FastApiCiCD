# Providers instellen
terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"  # Definieert de bron van de DigitalOcean provider
      version = "~> 2.0"  # Specificeert de versie van de provider
    }
  }
}

provider "digitalocean" {
  token = var.do_token  # Gebruikt een variabele voor authenticatie bij DigitalOcean
}

provider "kubernetes" {
  host                   = digitalocean_kubernetes_cluster.my_cluster.endpoint  # Verbindt met de Kubernetes API
  token                  = digitalocean_kubernetes_cluster.my_cluster.kube_config[0].token  # Gebruikt de API-token van de cluster
  cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.my_cluster.kube_config[0].cluster_ca_certificate)  # Decodeert en gebruikt het CA-certificaat
}

# Kubernetes-cluster aanmaken
resource "digitalocean_kubernetes_cluster" "my_cluster" {
  name    = var.cluster_name  # Naam van de Kubernetes-cluster
  region  = var.region  # Locatie van de cluster
  version = "1.32.1-do.0"  # Versie van Kubernetes

  node_pool {
    name       = "webapi-compleet"  # Naam van de node pool
    size       = "s-1vcpu-2gb"  # Grootte van de nodes
    node_count = var.node_count  # Aantal nodes in de pool
  }
}

# Namespaces aanmaken voor applicaties en monitoring
resource "kubernetes_namespace" "app_namespace" {
  metadata {
    name = var.namespace  # Naam van de namespace voor de applicatie
  }
}

resource "kubernetes_namespace" "monitoring_namespace" {
  metadata {
    name = var.monitoring_namespace  # Namespace voor monitoring
  }
}

# Docker registry secret aanmaken
resource "kubernetes_secret" "docker_registry" {
  metadata {
    name      = "docker-registry"
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
  }
  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({  # Encodeert de Docker login gegevens
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

# PersistentVolumeClaim voor PostgreSQL
resource "kubernetes_persistent_volume_claim" "postgres_pvc" {
  metadata {
    name      = "postgres-pvc"
    namespace = var.namespace  # Koppelen aan de juiste namespace
  }
  spec {
    access_modes = ["ReadWriteOnce"]  # Toegangsmode van de storage
    resources {
      requests = {
        storage = "1Gi"  # Grootte van de storage
      }
    }
  }
}

# PostgreSQL Deployment
resource "kubernetes_deployment" "postgres" {
  metadata {
    name      = "postgres"
    namespace = var.namespace  # Toewijzen aan de juiste namespace
  }
  spec {
    replicas = 1  # Aantal replica's
    selector {
      match_labels = {
        app = "postgres"  # Labels voor selectie
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
          image = "postgres:16"  # PostgreSQL versie
          env {
            name  = "POSTGRES_DB"
            value = var.db_name  # Database naam
          }
          env {
            name  = "POSTGRES_USER"
            value = var.db_user  # Database gebruiker
          }
          env {
            name  = "POSTGRES_PASSWORD"
            value = var.db_password  # Database wachtwoord
          }
          volume_mount {
            name       = "postgres-storage"
            mount_path = "/var/lib/postgresql/data"  # Opslaglocatie
          }
        }
        volume {
          name = "postgres-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.postgres_pvc.metadata[0].name  # Koppeling met PVC
          }
        }
      }
    }
  }
}

# PostgreSQL Service
resource "kubernetes_service" "postgres" {
  metadata {
    name      = "postgres"
    namespace = var.namespace
  }
  spec {
    selector = {
      app = "postgres"  # Koppelt aan de juiste Pods
    }
    port {
      port        = 5432  # Externe poort
      target_port = 5432  # Interne poort in de container
    }
    type = "ClusterIP"  # Interne toegang binnen de cluster
  }
}

# Website Deployment binnen het Kubernetes-cluster
resource "kubernetes_deployment" "website" {
  metadata {
    name      = "website"
    namespace = var.namespace
  }
  spec {
    replicas = 2  # Aantal instances van de website
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
        container {
          name  = "website"
          image = "registry.digitalocean.com/devops-cicd/fast-api:latest"  # Docker image van de website
          image_pull_policy = "Always"
          port {
            container_port = 8000  # Poort waar de app op draait
          }
        }
      }
    }
  }
}
