variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
}

variable "subnet_system_id" {
  description = "Subnet ID for the AKS system node pool"
  type        = string
}

variable "subnet_app_id" {
  description = "Subnet ID for the AKS app and spot node pools"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "tenant_id" {
  description = "The Microsoft Entra ID tenant ID for integration"
  type        = string
}

variable "admin_group_object_ids" {
  description = "List of Microsoft Entra ID group object IDs to be cluster admins"
  type        = list(string)
  default     = []
}

variable "local_accounts_enabled" {
  description = "Enable or disable local accounts for AKS cluster"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_id" {
  description = "The Resource ID of the Log Analytics Workspace for security and diagnostics"
  type        = string
}
