output "ip_address" {
  value = azurerm_public_ip.jumpbox-pip.ip_address
}

output "admin_username" {
  value = var.admin_username
}
