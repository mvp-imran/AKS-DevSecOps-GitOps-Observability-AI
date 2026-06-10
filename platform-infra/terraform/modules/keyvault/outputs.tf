output "id" {
  value       = azurerm_key_vault.kv.id
  description = "The ID of the Azure Key Vault"
}

output "vault_uri" {
  value       = azurerm_key_vault.kv.vault_uri
  description = "The URI of the Key Vault for App Config"
}
