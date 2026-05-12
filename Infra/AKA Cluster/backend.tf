terraform {
  #   backend "azurerm" {
  #   resource_group_name  = "rg-westeu-sandbox-apipro"  # Can be passed via `-backend-config=`"resource_group_name=<resource group name>"` in the `init` command.
  #   storage_account_name = "testtfstorageacct12345"                      # Can be passed via `-backend-config=`"storage_account_name=<storage account name>"` in the `init` command.
  #   container_name       = "tfstate"                       # Can be passed via `-backend-config=`"container_name=<container name>"` in the `init` command.
  #   key                  = "dev.terraform.tfstate"        # Can be passed via `-backend-config=`"key=<blob key name>"` in the `init` command.
  # }
  }
# Note: This is a template. Actual values should be provided via backend-config or environment variables.
# Example initialization:
# terraform init -backend-config="resource_group_name=tfstate-rg" \
#                -backend-config="storage_account_name=tfstate12345" \
#                -backend-config="container_name=tfstate" \
#                -backend-config="key=prod.terraform.tfstate"