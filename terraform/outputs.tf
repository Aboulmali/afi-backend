# Sorties Terraform - utiles pour le CD (kubectl) et la documentation
output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "aks_kube_config" {
  description = "Kubeconfig du cluster (base64) -> secret GitHub KUBE_CONFIG_B64"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "postgres_server" {
  value = azurerm_postgresql_flexible_server.db.fqdn
}