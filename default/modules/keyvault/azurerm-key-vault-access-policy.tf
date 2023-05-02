data "azurerm_client_config" "current" {}

resource "azurerm_key_vault_access_policy" "spAccessPolicy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azuread_service_principal.example.object_id

  key_permissions = [
    "Get", "Sign"
  ]

  secret_permissions = [
    "Get", "Set", "List", "Delete", "Purge"
  ]

  certificate_permissions = [
    "Get", "Create", "Delete", "Purge"
  ]
}

resource "azurerm_key_vault_access_policy" "currentUserAccesPolicy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azuread_client_config.current.object_id

  key_permissions = [
    "Get", "Sign"
  ]

  secret_permissions = [
    "Get", "Set", "List", "Delete", "Purge"
  ]

  certificate_permissions = [
    "Get", "Create", "Delete", "Purge"
  ]
}