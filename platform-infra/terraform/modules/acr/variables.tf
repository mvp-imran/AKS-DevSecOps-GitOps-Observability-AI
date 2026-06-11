variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for ACR"
  type        = string
}

variable "acr_name" {
  description = "Name of the Container Registry (must be globally unique)"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "replica_location" {
  description = "Azure region for secondary replica (e.g., westus)"
  type        = string
  default     = "westus"
}

variable "subnet_endpoint_id" {
  description = "Subnet ID for ACR Private Endpoint"
  type        = string
}

variable "vnet_id" {
  description = "ID of the Spoke VNet for Private DNS Zone link"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "The Resource ID of the Log Analytics Workspace for diagnostics"
  type        = string
}
