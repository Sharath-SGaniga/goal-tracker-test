data "azurerm_resource_group" "example" {
  name = "rg-westeu-sandbox-apipro"
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-demo-cluster"
  location            = data.azurerm_resource_group.example.location
  resource_group_name = data.azurerm_resource_group.example.name
  dns_prefix          = "aksdemo"

  default_node_pool {
    name       = "system"
    node_count = 1
    vm_size    = "Standard_B2s"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
  }

  tags = {
    environment = "dev"
  }
}