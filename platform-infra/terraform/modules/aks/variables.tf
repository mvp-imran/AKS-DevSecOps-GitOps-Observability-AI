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
