data "external" "token" {
  program = ["${path.module}/createtoken.sh"]
  query = {
    registry  = "${var.acr_name}"
    tokenName = "exampletoken"
  }
}

/* Secrets */
resource "azurerm_key_vault_secret" "spClientId" {
  name         = "AZURE-CLIENT-ID"
  value        = var.service_principal_client_id
  key_vault_id = azurerm_key_vault.kv.id
  depends_on = [
    azurerm_key_vault_access_policy.currentUserAccesPolicy
  ]
}

resource "azurerm_key_vault_secret" "spClientSecret" {
  name         = "AZURE-CLIENT-SECRET"
  value        = var.service_principal_password
  key_vault_id = azurerm_key_vault.kv.id
  depends_on = [
    azurerm_key_vault_access_policy.currentUserAccesPolicy
  ]
}

resource "azurerm_key_vault_secret" "tenantId" {
  name         = "AZURE-TENANT-ID"
  value        = data.azurerm_client_config.current.tenant_id
  key_vault_id = azurerm_key_vault.kv.id
  depends_on = [
    azurerm_key_vault_access_policy.currentUserAccesPolicy
  ]
}

resource "azurerm_key_vault_secret" "notationUser" {
  name         = "NOTATION-USERNAME"
  value        = data.external.token.result["name"]
  key_vault_id = azurerm_key_vault.kv.id
  depends_on = [
    data.external.token,
    azurerm_key_vault_access_policy.currentUserAccesPolicy
  ]
}

resource "azurerm_key_vault_secret" "notationPassword" {
  name         = "NOTATION-PASSWORD"
  value        = data.external.token.result["password"]
  key_vault_id = azurerm_key_vault.kv.id
  depends_on = [
    data.external.token,
    azurerm_key_vault_access_policy.spAccessPolicy,
    azurerm_key_vault_access_policy.currentUserAccesPolicy
    ]
}

/* Certificate */
resource "azurerm_key_vault_certificate" "signingCert" {
  name         = "example"
  key_vault_id = azurerm_key_vault.kv.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }

      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pem-file"
    }

    x509_certificate_properties {
      extended_key_usage = ["1.3.6.1.5.5.7.3.3"]

      key_usage = [
        "digitalSignature",
      ]


      subject            = "CN=example,C=US,ST=WA,O=notation"
      validity_in_months = 12
    }
  }
  depends_on = [
    azurerm_key_vault_access_policy.spAccessPolicy,
    azurerm_key_vault_access_policy.currentUserAccesPolicy
  ]
}