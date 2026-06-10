resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = var.environment
    Owner       = "Platform-Team"
  }
}

# 1. Networking Module
module "networking" {
  source              = "../../modules/networking"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  environment         = var.environment
  
  # Default address spaces
  hub_vnet_name       = "vnet-hub-shared-eus"
  hub_address_space   = ["10.0.0.0/16"]
  spoke_vnet_name     = "vnet-platform-dev-eus"
  spoke_address_space = ["10.1.0.0/16"]
}

# 2. Azure Container Registry Module
module "acr" {
  source              = "../../modules/acr"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  acr_name            = var.acr_name
  environment         = var.environment
  replica_location    = "westus" # Secondary DR Region
}

# 3. Key Vault Module
module "keyvault" {
  source              = "../../modules/keyvault"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  keyvault_name       = var.keyvault_name
  tenant_id           = var.tenant_id
  environment         = var.environment
  subnet_endpoint_id  = module.networking.subnet_spoke_endpoints_id
  vnet_id             = module.networking.spoke_vnet_id
}

# 4. Storage for Backups (Velero) Module
module "backup" {
  source               = "../../modules/backup"
  resource_group_name  = azurerm_resource_group.rg.name
  location             = azurerm_resource_group.rg.location
  storage_account_name = var.velero_storage_account_name
  environment          = var.environment
}

# 5. Private AKS Cluster Module
module "aks" {
  source              = "../../modules/aks"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  cluster_name        = var.cluster_name
  dns_prefix          = var.dns_prefix
  subnet_system_id    = module.networking.subnet_aks_system_id
  subnet_app_id       = module.networking.subnet_aks_app_id
  environment         = var.environment
}

# 6. Role Assignment: Grant AKS permission to pull images from ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = module.aks.kubelet_identity_object_id
  role_definition_name             = "AcrPull"
  scope                            = module.acr.id
  skip_service_principal_aad_check = true
}
