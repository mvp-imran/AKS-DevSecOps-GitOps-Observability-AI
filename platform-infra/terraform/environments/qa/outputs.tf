output "resource_group_name" {
  value       = azurerm_resource_group.rg.name
  description = "The name of the resource group"
}

output "hub_vnet_id" {
  value       = module.networking.hub_vnet_id
}

output "spoke_vnet_id" {
  value       = module.networking.spoke_vnet_id
}

output "acr_login_server" {
  value       = module.acr.login_server
}

output "keyvault_vault_uri" {
  value       = module.keyvault.vault_uri
}

output "velero_storage_account" {
  value       = module.backup.storage_account_name
}

output "aks_cluster_id" {
  value       = module.aks.id
}

output "aks_oidc_issuer_url" {
  value       = module.aks.oidc_issuer_url
}
