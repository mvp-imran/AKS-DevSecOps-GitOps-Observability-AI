variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "keyvault_name" {
  description = "Name of the Key Vault"
  type        = string
}

variable "tenant_id" {
  description = "Tenant ID for subscription"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "subnet_endpoint_id" {
  description = "Subnet ID where Key Vault Private Endpoint will be mapped"
  type        = string
}

variable "vnet_id" {
  description = "ID of the Spoke VNet for Private DNS Zone binding"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "The Resource ID of the Log Analytics Workspace for diagnostics"
  type        = string
}
