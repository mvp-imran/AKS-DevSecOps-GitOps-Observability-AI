output "hub_vnet_id" {
  value       = azurerm_virtual_network.hub.id
  description = "ID of the Hub Virtual Network"
}

output "spoke_vnet_id" {
  value       = azurerm_virtual_network.spoke.id
  description = "ID of the Spoke Virtual Network"
}

output "subnet_aks_system_id" {
  value       = azurerm_subnet.aks_system.id
  description = "ID of the System Node Pool subnet"
}

output "subnet_aks_app_id" {
  value       = azurerm_subnet.aks_app.id
  description = "ID of the Application Node Pool subnet"
}

output "subnet_spoke_endpoints_id" {
  value       = azurerm_subnet.spoke_endpoints.id
  description = "ID of the Spoke Private Endpoints subnet"
}

output "subnet_spoke_ingress_id" {
  value       = azurerm_subnet.spoke_ingress.id
  description = "ID of the Spoke Ingress subnet"
}
