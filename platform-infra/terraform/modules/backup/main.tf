resource "azurerm_storage_account" "velero_storage" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "GRS" # Geo-redundant storage for DR capability

  # Secure transfer and TLS version enforcement
  enable_https_traffic_only = true
  min_tls_version           = "TLS1_2"

  tags = {
    Environment = var.environment
    Component   = "backup"
  }
}

resource "azurerm_storage_container" "velero_container" {
  name                  = "velero"
  storage_account_name  = azurerm_storage_account.velero_storage.name
  container_access_type = "private"
}
