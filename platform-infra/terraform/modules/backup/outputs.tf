output "storage_account_name" {
  value       = azurerm_storage_account.velero_storage.name
  description = "Name of the storage account for Velero backups"
}

output "storage_container_name" {
  value       = azurerm_storage_container.velero_container.name
  description = "Name of the storage blob container for backups"
}

output "storage_account_id" {
  value       = azurerm_storage_account.velero_storage.id
  description = "The ID of the storage account"
}
