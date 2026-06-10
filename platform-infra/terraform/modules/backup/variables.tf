variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "storage_account_name" {
  description = "Name of the Storage Account for Velero backups (must be globally unique)"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}
