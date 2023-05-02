resource "azurerm_resource_group" "demo" {
  name     = "rg-${var.prefix}-${var.suffix}"
  location = var.location
}