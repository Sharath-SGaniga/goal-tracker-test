terraform {
  backend "azurerm" {
    # These values should be configured via environment variables or command line when initializing
    # resource_group_name  = "tfstate-rg"
    # storage_account_name = "tfstate<unique_suffix>"
    # container_name       = "tfstate"
    # key                  = "terraform.tfstate"
    # use_azuread_auth     = true
  }
}

# Note: This is a template. Actual values should be provided via backend-config or environment variables.
# Example initialization:
# terraform init -backend-config="resource_group_name=tfstate-rg" \
#                -backend-config="storage_account_name=tfstate12345" \
#                -backend-config="container_name=tfstate" \
#                -backend-config="key=prod.terraform.tfstate"