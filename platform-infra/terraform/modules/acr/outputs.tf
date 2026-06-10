output "id" {
  value       = azurerm_container_registry.acr.id
  description = "The ID of the Azure Container Registry"
}

output "login_server" {
  value       = azurerm_container_registry.acr.login_server
  description = "The login server URL for the ACR"
}
