# VNet Definition
resource "azurerm_virtual_network" "demo-vnet" {
  name                = "demo-vnet"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  address_space       = ["10.220.0.0/16"]
}

# Subnets
resource "azurerm_subnet" "demo-cluster" {
  name                                      = "snet-aks-demo-cluster"
  resource_group_name                       = azurerm_resource_group.demo.name
  virtual_network_name                      = azurerm_virtual_network.demo-vnet.name
  private_endpoint_network_policies_enabled = false
  address_prefixes                          = ["10.220.1.0/24"]
}
resource "azurerm_subnet" "jumpbox" {
  name                 = "JumpboxSubnet"
  resource_group_name  = azurerm_resource_group.demo.name
  virtual_network_name = azurerm_virtual_network.demo-vnet.name
  address_prefixes     = ["10.220.2.0/24"]
}

