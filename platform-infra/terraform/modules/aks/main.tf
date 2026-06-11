data "azurerm_client_config" "current" {}

resource "azurerm_kubernetes_cluster" "aks" {
  name                    = var.cluster_name
  location                = var.location
  resource_group_name     = var.resource_group_name
  dns_prefix              = var.dns_prefix
  private_cluster_enabled = true
  local_accounts_enabled  = var.local_accounts_enabled

  # Default system node pool
  default_node_pool {
    name       = "systempool"
    node_count = 3
    vm_size    = "Standard_D4s_v5"
    vnet_subnet_id = var.subnet_system_id
    zones      = ["1", "2", "3"]

    # Prevent application pods from running on system pool
    node_labels = {
      "role" = "system"
    }
    only_critical_addons_enabled = true
  }

  identity {
    type = "SystemAssigned"
  }

  azure_active_directory_role_based_access_control {
    tenant_id              = var.tenant_id
    azure_rbac_enabled     = true
    admin_group_object_ids = length(var.admin_group_object_ids) > 0 ? var.admin_group_object_ids : [data.azurerm_client_config.current.object_id]
  }

  microsoft_defender {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  # CNI Overlay configuration
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "azure" # Azure NPM
    outbound_type       = "userDefinedRouting" # Outbound goes through Hub Firewall UDR
    pod_cidr            = "10.244.0.0/16"
    service_cidr        = "10.2.0.0/16"
    dns_service_ip      = "10.2.0.10"
  }

  # Workload Identity + OIDC Issuer support
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  tags = {
    Environment = var.environment
    Component   = "aks"
  }
}

# Dedicated Application Node Pool
resource "azurerm_kubernetes_cluster_node_pool" "app" {
  name                  = "apppool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = "Standard_D4s_v5"
  vnet_subnet_id        = var.subnet_app_id
  zones                 = ["1", "2", "3"]
  
  # Autoscaling settings
  enable_auto_scaling   = true
  min_count             = 2
  max_count             = 10

  node_labels = {
    "role" = "application"
  }

  tags = {
    Environment = var.environment
  }
}

# Cost-Saving Spot Node Pool for CI/CD / Non-critical workloads
resource "azurerm_kubernetes_cluster_node_pool" "spot" {
  name                  = "spotpool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = "Standard_D4s_v5" # Spot node size
  vnet_subnet_id        = var.subnet_app_id
  
  priority              = "Spot"
  eviction_policy       = "Delete"
  spot_max_price        = -1 # Pay up to standard pricing

  enable_auto_scaling   = true
  min_count             = 1
  max_count             = 5

  node_labels = {
    "role"        = "batch-ci"
    "kubernetes.azure.com/scalesetpriority" = "spot"
  }

  node_taints = [
    "sku=spot:NoSchedule"
  ]

  tags = {
    Environment = var.environment
    CostType    = "spot"
  }
}

resource "azurerm_monitor_diagnostic_setting" "aks_diag" {
  name                       = "diag-${var.cluster_name}"
  target_resource_id         = azurerm_kubernetes_cluster.aks.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "kube-apiserver"
  }

  enabled_log {
    category = "kube-audit"
  }

  enabled_log {
    category = "kube-audit-admin"
  }

  enabled_log {
    category = "kube-controller-manager"
  }

  enabled_log {
    category = "cluster-autoscaler"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
