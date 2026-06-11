output "id" {
  value       = azurerm_log_analytics_workspace.law.id
  description = "The Resource ID of the Log Analytics Workspace"
}

output "workspace_id" {
  value       = azurerm_log_analytics_workspace.law.workspace_id
  description = "The Workspace ID (Client ID) of the Log Analytics Workspace"
}
