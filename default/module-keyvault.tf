module "keyvault" {
  source = "./modules/keyvault"

  prefix = local.prefix

  suffix         = local.suffix
  resource_group = azurerm_resource_group.demo

  acr_name                    = azurerm_container_registry.demo.name
  service_principal_object_id = azuread_service_principal.demo-application.object_id
  service_principal_client_id = azuread_service_principal.demo-application.application_id
  service_principal_password  = azuread_service_principal_password.demo-application.value

  kv_name = "${local.prefix}demokv${local.suffix}"
  kv_settings = {
    enabled_for_disk_encryption = true
    soft_delete_retention_days  = 7
    purge_protection_enabled    = false
    sku_name                    = "standard"
  }
}
