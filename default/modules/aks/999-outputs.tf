output "cluster_name" {
  value = azurerm_kubernetes_cluster.dev.name
}

data "azurerm_kubernetes_cluster" "dev-cluster" {
  name                = azurerm_kubernetes_cluster.dev.name
  resource_group_name = var.resource_group.name
}

output "kube_config" {
  value = data.azurerm_kubernetes_cluster.dev-cluster.kube_config
}