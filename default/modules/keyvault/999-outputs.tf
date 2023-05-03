output "azure_key_vault_name" {
  value = azurerm_key_vault.kv.name
}

## Name of secrets not values
output "notation_username" {
  value = azurerm_key_vault_secret.notationUser.value
}

output "notation_password" {
  value = azurerm_key_vault_secret.notationPassword.value
}

output "signing_cert" {
  value = azurerm_key_vault_certificate.signingCert.name
}