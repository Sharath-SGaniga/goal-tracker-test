terraform {
  required_providers {
    azurerm = {
        source = "hashicorp/azurerm"
        version = "~> 4.8.0"
    }
  }
  required_version = ">=1.9.0"
}


provider "azurerm" {
    subscription_id = "7f7b6ecc-9988-498a-b3f3-bd79a0674935"

    features {
      
    }
    
    resource_provider_registrations = "none"
  
}