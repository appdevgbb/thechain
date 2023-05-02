# resource "azurerm_route_table" "demo" {
#   name                = "defaultRouteTable"
#   location            = azurerm_resource_group.demo.location
#   resource_group_name = azurerm_resource_group.demo.name
# }

# resource "azurerm_route" "default-route" {
#   name                   = "defaultRoute"
#   resource_group_name    = azurerm_resource_group.demo.name
#   route_table_name       = azurerm_route_table.demo.name
#   address_prefix         = "0.0.0.0/0"
#   next_hop_type          = "Internet"
# }

# resource "azurerm_subnet_route_table_association" "jumpbox" {
#   subnet_id      = azurerm_subnet.jumpbox.id
#   route_table_id = azurerm_route_table.demo.id
# }

# resource "azurerm_subnet_route_table_association" "demo-cluster" {
#   subnet_id      = azurerm_subnet.demo-cluster.id
#   route_table_id = azurerm_route_table.demo.id
# }