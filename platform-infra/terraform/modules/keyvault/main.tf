data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                        = var.keyvault_name
  location                    = var.location
  resource_group_name         = var.resource_group_name
  enabled_for_disk_encryption = true
  tenant_id                   = var.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = true

  # Disable public network access for security by default
  public_network_access_enabled = false

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
  }

  tags = {
    Environment = var.environment
    Component   = "security"
  }
}

# Private Endpoint for Key Vault
resource "azurerm_private_endpoint" "kv_pe" {
  name                = "pe-${var.keyvault_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_endpoint_id

  private_service_connection {
    name                           = "psc-${var.keyvault_name}"
    private_connection_resource_id = azurerm_key_vault.kv.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  tags = {
    Environment = var.environment
  }
}

# Private DNS Zone for Key Vault
resource "azurerm_private_dns_zone" "kv_dns" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv_dns_link" {
  name                  = "link-${var.keyvault_name}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.kv_dns.name
  virtual_network_id    = var.vnet_id
}

resource "azurerm_private_dns_a_record" "kv_dns_a" {
  name                = lower(var.keyvault_name)
  zone_name           = azurerm_private_dns_zone.kv_dns.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.kv_pe.private_service_connection[0].private_ip_address]
}

resource "azurerm_monitor_diagnostic_setting" "kv_diag" {
  name                       = "diag-${var.keyvault_name}"
  target_resource_id         = azurerm_key_vault.kv.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AuditEvent"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
