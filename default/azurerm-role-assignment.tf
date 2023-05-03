/* Provide access to ACR from the Notary Service Principal*/
resource "azurerm_role_assignment" "notary-sp-access-to-acr" {
  scope                = azurerm_container_registry.demo.id
  role_definition_name = "AcrPush"
  principal_id         = azuread_service_principal.demo-application.object_id
    
  }