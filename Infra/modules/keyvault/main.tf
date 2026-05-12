/*
 * Key Vault Module
 * This module creates an Azure Key Vault for storing secrets used by the application,
 * such as database credentials, connection strings, and other sensitive information.
 */

# Generate a random string for uniqueness
resource "random_string" "kv_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Azure Key Vault
resource "azurerm_key_vault" "kv" {
  name                        = "${var.resource_name_prefix}-kv-${random_string.kv_suffix.result}"
  location                    = var.location
  resource_group_name         = var.resource_group_name
  enabled_for_disk_encryption = true
  tenant_id                   = var.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  enable_rbac_authorization   = false
  sku_name                    = "standard"
  tags                        = var.tags

  # Common access policies
  access_policy {
    tenant_id = var.tenant_id
    object_id = var.object_id

    key_permissions = [
      "Get", "List", "Create", "Delete", "Update", "Recover", "Backup", "Restore", "Purge"
    ]

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore", "Purge"
    ]

    certificate_permissions = [
      "Get", "List", "Create", "Delete", "Update", "Recover", "Backup", "Restore", "Import", "Purge"
    ]
  }

  # Access policy for backend VM managed identity (if provided)
  dynamic "access_policy" {
    for_each = var.backend_identity_principal_id != null ? [1] : []
    content {
      tenant_id = var.tenant_id
      object_id = var.backend_identity_principal_id

      secret_permissions = [
        "Get", "List"
      ]
    }
  }

  # Network access configuration
  network_acls {
    default_action = "Allow" # Consider changing to "Deny" in production and explicitly allowing needed IPs/VNets
    bypass         = "AzureServices"
  }
}
