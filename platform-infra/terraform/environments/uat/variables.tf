variable "resource_group_name" {
  description = "The Resource Group name for UAT resources"
  type        = string
  default     = "rg-platform-uat-eus"
}

variable "location" {
  description = "The Azure region for UAT deployment"
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
  default     = "aks-uat-cluster"
}

variable "dns_prefix" {
  description = "The DNS prefix for AKS cluster API"
  type        = string
  default     = "aksuat"
}

variable "environment" {
  description = "Environment identifier"
  type        = string
  default     = "uat"
}
