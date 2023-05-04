output "ip_address" {
  value = azurerm_public_ip.jumpbox-pip.ip_address
}

output "fqdn" {
  value = azurerm_public_ip.jumpbox-pip.reverse_fqdn
}

output "admin_username" {
  value = var.admin_username
}
