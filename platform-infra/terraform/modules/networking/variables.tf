variable "resource_group_name" {
  description = "Name of the resource group to deploy networking resources"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "hub_vnet_name" {
  description = "Name of the Hub Virtual Network"
  type        = string
  default     = "vnet-hub-shared-eus"
}

variable "hub_address_space" {
  description = "Address space for the Hub VNet"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "spoke_vnet_name" {
  description = "Name of the Spoke Virtual Network"
  type        = string
  default     = "vnet-platform-dev-eus"
}

variable "spoke_address_space" {
  description = "Address space for the Spoke VNet"
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

variable "environment" {
  description = "Deployment environment (e.g., dev, qa, uat, prod)"
  type        = string
  default     = "dev"
}
