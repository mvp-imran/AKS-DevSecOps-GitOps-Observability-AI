resource "azurerm_container_registry" "acr" {
  name                          = var.acr_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = "Premium" # Premium required for private link & geo-replication
  admin_enabled                 = false
  public_network_access_enabled = false

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

# Private Endpoint for ACR
resource "azurerm_private_endpoint" "acr_pe" {
  name                = "pe-${var.acr_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_endpoint_id

  private_service_connection {
    name                           = "psc-${var.acr_name}"
    private_connection_resource_id = azurerm_container_registry.acr.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  tags = {
    Environment = var.environment
  }
}

# Private DNS Zone for ACR
resource "azurerm_private_dns_zone" "acr_dns" {
  name                = "privatelink.azurecr.io"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr_dns_link" {
  name                  = "link-${var.acr_name}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.acr_dns.name
  virtual_network_id    = var.vnet_id
}

resource "azurerm_private_dns_a_record" "acr_dns_a" {
  name                = lower(var.acr_name)
  zone_name           = azurerm_private_dns_zone.acr_dns.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.acr_pe.private_service_connection[0].private_ip_address]
}

# Diagnostic setting for ACR
resource "azurerm_monitor_diagnostic_setting" "acr_diag" {
  name                       = "diag-${var.acr_name}"
  target_resource_id         = azurerm_container_registry.acr.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "ContainerRegistryRepositoryEvents"
  }

  enabled_log {
    category = "ContainerRegistryLoginEvents"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
