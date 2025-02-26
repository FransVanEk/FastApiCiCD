variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "region" {
  description = "Region where the cluster will be deployed"
  type        = string
}

variable "node_count" {
  description = "Number of nodes in the Kubernetes cluster"
  type        = number
}

variable "namespace" {
  description = "Kubernetes namespace for the application"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_user" {
  description = "Database username"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
}

variable "db_host" {
  description = "Database host"
  type        = string
}

variable "db_port" {
  description = "Database port"
  type        = number
}

variable "sslmode" {
  description = "SSL mode for database connection"
  type        = string
}

variable "docker_server" {
  description = "Docker registry server"
  type        = string
}

variable "docker_username" {
  description = "Docker registry username"
  type        = string
}

variable "docker_email" {
  description = "Docker registry email"
  type        = string
}

variable "monitoring_namespace" {
  description = "Kubernetes namespace for monitoring"
  type        = string
}

variable "grafana_admin_password" {
  description = "Admin password for Grafana"
  type        = string
}