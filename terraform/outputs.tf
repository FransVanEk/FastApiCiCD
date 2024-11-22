# Output voor Kubernetes kubeconfig
output "kubeconfig" {
  value     = digitalocean_kubernetes_cluster.my_cluster.kube_config[0].raw_config
  sensitive = true
  description = "Kubeconfig voor toegang tot het Kubernetes-cluster"
}