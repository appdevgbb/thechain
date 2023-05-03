resource "azurerm_key_vault" "kv" {
  name                = var.kv_name
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name                    = "standard"
}