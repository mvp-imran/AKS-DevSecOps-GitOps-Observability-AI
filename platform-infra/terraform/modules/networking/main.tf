resource "azurerm_virtual_network" "hub" {
  name                = var.hub_vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.hub_address_space

  tags = {
    Environment = var.environment
    Component   = "networking"
  }
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet" # Must be exactly this name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "firewall_mgmt" {
  name                 = "AzureFirewallManagementSubnet" # Must be exactly this name for forced tunneling
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet" # Must be exactly this name for Bastion
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet" # Must be exactly this name for VPN Gateway
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.3.0/24"]
}

resource "azurerm_subnet" "shared_services" {
  name                 = "snet-shared-services"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.4.0/22"]
}

resource "azurerm_subnet" "hub_endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.8.0/24"]
}

# Spoke Virtual Network
resource "azurerm_virtual_network" "spoke" {
  name                = var.spoke_vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.spoke_address_space

  tags = {
    Environment = var.environment
    Component   = "networking"
  }
}

resource "azurerm_subnet" "aks_system" {
  name                 = "snet-aks-system"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [cidrsubnet(var.spoke_address_space[0], 6, 0)] # e.g. 10.1.0.0/22
}

resource "azurerm_subnet" "aks_app" {
  name                 = "snet-aks-app"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [cidrsubnet(var.spoke_address_space[0], 4, 1)] # e.g. 10.1.4.0/20
}

resource "azurerm_subnet" "spoke_endpoints" {
  name                 = "snet-endpoints"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [cidrsubnet(var.spoke_address_space[0], 8, 20)] # e.g. 10.1.20.0/24
}

resource "azurerm_subnet" "spoke_ingress" {
  name                 = "snet-ingress"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [cidrsubnet(var.spoke_address_space[0], 8, 21)] # e.g. 10.1.21.0/24
}

# VNet Peering
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = "peering-hub-to-${var.environment}"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "peering-${var.environment}-to-hub"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

# Route Table (UDR) to redirect internet traffic to Azure Firewall (Private IP 10.0.0.4)
resource "azurerm_route_table" "spoke" {
  name                          = "rt-spoke-egress-${var.environment}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  disable_bgp_route_propagation = false

  route {
    name                   = "route-to-hub-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.0.0.4"
  }

  tags = {
    Environment = var.environment
  }
}

resource "azurerm_subnet_route_table_association" "system" {
  subnet_id      = azurerm_subnet.aks_system.id
  route_table_id = azurerm_route_table.spoke.id
}

resource "azurerm_subnet_route_table_association" "app" {
  subnet_id      = azurerm_subnet.aks_app.id
  route_table_id = azurerm_route_table.spoke.id
}

# Network Security Groups
resource "azurerm_network_security_group" "aks_app" {
  name                = "nsg-aks-app-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "allow-http-ingress"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443", "8080"]
    source_address_prefix      = "10.1.21.0/24" # Only allow ingress subnet
    destination_address_prefix = "10.1.4.0/20"
  }

  security_rule {
    name                       = "deny-external-inbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = var.environment
  }
}

resource "azurerm_subnet_network_security_group_association" "app_nsg" {
  subnet_id                 = azurerm_subnet.aks_app.id
  network_security_group_id = azurerm_network_security_group.aks_app.id
}

# NSG for system node pool subnet (only allow management from Hub)
resource "azurerm_network_security_group" "aks_system" {
  name                = "nsg-aks-system-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "allow-hub-management"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "10250"]
    source_address_prefix      = "10.0.0.0/16" # Hub VNet IP range
    destination_address_prefix = azurerm_subnet.aks_system.address_prefixes[0]
  }

  security_rule {
    name                       = "deny-all-other-inbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = var.environment
  }
}

resource "azurerm_subnet_network_security_group_association" "system_nsg" {
  subnet_id                 = azurerm_subnet.aks_system.id
  network_security_group_id = azurerm_network_security_group.aks_system.id
}

# NSG for Ingress Subnet
resource "azurerm_network_security_group" "spoke_ingress" {
  name                = "nsg-ingress-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "allow-http-https-inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-gateway-manager-probes"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "deny-all-other-inbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = var.environment
  }
}

resource "azurerm_subnet_network_security_group_association" "ingress_nsg" {
  subnet_id                 = azurerm_subnet.spoke_ingress.id
  network_security_group_id = azurerm_network_security_group.spoke_ingress.id
}
