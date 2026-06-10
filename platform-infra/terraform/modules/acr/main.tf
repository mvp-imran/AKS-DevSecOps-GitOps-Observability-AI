resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Premium" # Premium required for private link & geo-replication
  admin_enabled       = false

  georeplications {
    location                = var.replica_location
    zone_redundancy_enabled = true
    tags = {
      Environment = var.environment
    }
  }

  tags = {
    Environment = var.environment
    Component   = "acr"
  }
}
