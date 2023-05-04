module "jumpbox" {
  source = "./modules/jumpbox-linux"

  prefix = local.prefix
  suffix = local.suffix

  subnet_id      = azurerm_subnet.jumpbox.id
  resource_group = azurerm_resource_group.demo

  admin_username = var.admin_username

  notation_version = "1.0.0-rc.4"
  kv_version = "0.6.0"
  arch = "linux_amd64"
}