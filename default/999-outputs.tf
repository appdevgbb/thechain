output "jumpbox" {
  value = {
    public_ip_address = module.jumpbox.ip_address
    fqdn = module.jumpbox.fqdn
    username          = module.jumpbox.admin_username
    ssh               = "${module.jumpbox.admin_username}@${module.jumpbox.ip_address}"
  }
}

output "kubernetes_cluster_name" {
  value = module.aks.cluster_name
}

output "aks_managed_id" {
  value = {
    client_id = azurerm_user_assigned_identity.managed-id.client_id
    object_id = azurerm_user_assigned_identity.managed-id.principal_id
    name = azurerm_user_assigned_identity.managed-id.name
  }
}

data "azurerm_client_config" "current" {}
output "azure" {
  value = {
    tenant_id = data.azurerm_client_config.current.tenant_id
  }
}

output "service_principal" {
  value = {
    service_principal_object_id = azuread_service_principal.demo-application.object_id
    service_principal_client_id = azuread_service_principal.demo-application.application_id
    service_principal_password  = azuread_service_principal_password.demo-application.value
  }
  sensitive = true
}

output "container_registry_name" {
  value = azurerm_container_registry.demo.name
}

output "azure_key_vault_name" {
  value = module.keyvault.azure_key_vault_name
}

output "notation_username" {
  value     = module.keyvault.notation_username
  sensitive = true
}

output "notation_password" {
  value     = module.keyvault.notation_password
  sensitive = true
}

output "signing_key_name" {
  value = module.keyvault.signing_cert
}

output "rg_name" {
  value = azurerm_resource_group.demo.name
}