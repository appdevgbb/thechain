resource "azurerm_user_assigned_identity" "managed-id" {
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location

  name = "aks-user-assigned-managed-id"
}

# cluster
#
resource "azurerm_role_assignment" "aks-mi-roles-vnet-rg" {
  scope                = azurerm_resource_group.demo.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.managed-id.principal_id
}

# Network
resource "azurerm_role_assignment" "aks-mi-roles-aks-demo" {
  scope                = azurerm_virtual_network.demo-vnet.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.managed-id.principal_id
}

module "aks" {
  depends_on = [
    azurerm_virtual_network.demo-vnet
  ]

  source = "./modules/aks"

  prefix = local.prefix
  suffix = local.suffix

  user_assigned_identity  = azurerm_user_assigned_identity.managed-id
  admin_username = var.admin_username
  subnet_id      = azurerm_subnet.demo-cluster.id
  resource_group = azurerm_resource_group.demo

  # ACR
  container_registry_id = azurerm_container_registry.demo.id

  cluster_name        = "demo-cluster"
  aks_settings = {
    kubernetes_version      = "1.25.6"
    private_cluster_enabled = false
    identity                = "UserAssigned"
    outbound_type           = "loadBalancer"
    network_plugin          = "azure"
    network_policy          = "calico"
    load_balancer_sku       = "standard"
    service_cidr            = "10.174.128.0/17"
    dns_service_ip          = "10.174.128.10"
    admin_username          = var.admin_username
    ssh_key                 = "~/.ssh/id_rsa.pub"
  }

  default_node_pool = {
    name                         = "system"
    enable_auto_scaling          = true
    node_count                   = 2
    min_count                    = 2
    max_count                    = 3
    vm_size                      = "standard_d4_v5"
    type                         = "VirtualMachineScaleSets"
    os_disk_size_gb              = 30
    only_critical_addons_enabled = true
    zones                        = [1]
  }

  user_node_pools = {
    "notary" = {
      vm_size                      = "standard_d4_v5"
      node_count                   = 1
      node_labels                  = null
      node_taints                  = []
    }
  }
}