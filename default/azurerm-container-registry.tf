resource "azurerm_container_registry" "demo" {
  name                          = "${var.prefix}demoACR${var.suffix}"
  location                      = azurerm_resource_group.demo.location
  resource_group_name           = azurerm_resource_group.demo.name
  sku                           = "Premium"
  admin_enabled                 = false
  public_network_access_enabled = true
}