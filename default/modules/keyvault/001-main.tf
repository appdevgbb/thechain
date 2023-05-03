resource "random_integer" "uid" {
  min = 0
  max = 99
}

locals {
  prefix    = var.prefix
  suffix    = var.suffix
  uid       = random_integer.uid.result
}

data "azurerm_client_config" "current" {}
data "azuread_client_config" current {}