/* Provide access to ACR from AKS */
resource "azurerm_role_assignment" "mi-access-to-acr" {
  scope                = var.container_registry_id
  role_definition_name = "AcrPull"
  principal_id         = var.user_assigned_identity.principal_id
}

/* Provide access to ACR from the Notary Service Principal*/
resource "azurerm_role_assignment" "notary-sp-access-to-acr" {
  scope                = var.container_registry_id
  role_definition_name = "AcrPush"
  principal_id         = var.user_assigned_identity.principal_id
}