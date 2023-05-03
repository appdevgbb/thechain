data "azuread_client_config" "current" {}

resource "random_id" "main" {
  byte_length = 4
  prefix      = "notary-"
}

resource "azuread_application" "demo-application" {
  display_name = "${random_id.main.hex}-sp"
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "demo-application" {
  application_id = azuread_application.demo-application.application_id
  owners         = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal_password" "demo-application" {
  service_principal_id = azuread_service_principal.demo-application.object_id
}