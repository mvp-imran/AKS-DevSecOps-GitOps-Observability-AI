variable "resource_group_name" {
  description = "The Resource Group name for DEV resources"
  type        = string
  default     = "rg-platform-dev-eus"
}

variable "location" {
  description = "The Azure region for DEV deployment"
  type        = string
  default     = "eastus"
}

variable "tenant_id" {
  description = "The Microsoft Entra ID tenant ID"
  type        = string
}

variable "acr_name" {
  description = "Globally unique name for the Azure Container Registry"
  type        = string
}

variable "keyvault_name" {
  description = "Globally unique name for the Azure Key Vault"
  type        = string
}

variable "velero_storage_account_name" {
  description = "Globally unique name for the Velero backup Storage Account"
  type        = string
}

variable "cluster_name" {
  description = "The AKS cluster name"
  type        = string
  default     = "aks-dev-cluster"
}

variable "dns_prefix" {
  description = "The DNS prefix for AKS cluster API"
  type        = string
  default     = "aksdev"
}

variable "environment" {
  description = "Environment identifier"
  type        = string
  default     = "dev"
}

variable "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace"
  type        = string
  default     = "law-platform-dev-eus"
}
