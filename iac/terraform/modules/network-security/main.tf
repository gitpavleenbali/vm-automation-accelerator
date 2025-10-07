# Network Security Group Module
# Creates NSG with FCR rules for Active Directory and DNS

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85.0"
    }
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = var.nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name
  
  tags = var.tags
}

# Active Directory Rules (FCR - Firewall Change Request approved)
resource "azurerm_network_security_rule" "ad_kerberos" {
  count                       = var.enable_ad_rules ? 1 : 0
  name                        = "Allow-AD-Kerberos"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "88"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg.name
  description                 = "FCR: Allow Kerberos authentication"
}

resource "azurerm_network_security_rule" "ad_ldap" {
  count                       = var.enable_ad_rules ? 1 : 0
  name                        = "Allow-AD-LDAP"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "389"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg.name
  description                 = "FCR: Allow LDAP"
}

resource "azurerm_network_security_rule" "ad_ldaps" {
  count                       = var.enable_ad_rules ? 1 : 0
  name                        = "Allow-AD-LDAPS"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "636"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg.name
  description                 = "FCR: Allow LDAP over SSL"
}

resource "azurerm_network_security_rule" "ad_global_catalog" {
  count                       = var.enable_ad_rules ? 1 : 0
  name                        = "Allow-AD-GlobalCatalog"
  priority                    = 130
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3268"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg.name
  description                 = "FCR: Allow Global Catalog"
}

resource "azurerm_network_security_rule" "ad_global_catalog_ssl" {
  count                       = var.enable_ad_rules ? 1 : 0
  name                        = "Allow-AD-GlobalCatalog-SSL"
  priority                    = 140
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3269"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg.name
  description                 = "FCR: Allow Global Catalog over SSL"
}

# DNS Rules (FCR approved)
resource "azurerm_network_security_rule" "dns" {
  count                       = var.enable_dns_rules ? 1 : 0
  name                        = "Allow-DNS"
  priority                    = 150
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "53"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg.name
  description                 = "FCR: Allow DNS queries"
}

# Custom Rules (variable driven)
resource "azurerm_network_security_rule" "custom" {
  count = length(var.custom_rules)
  
  name                        = var.custom_rules[count.index].name
  priority                    = var.custom_rules[count.index].priority
  direction                   = var.custom_rules[count.index].direction
  access                      = var.custom_rules[count.index].access
  protocol                    = var.custom_rules[count.index].protocol
  source_port_range           = var.custom_rules[count.index].source_port_range
  destination_port_range      = var.custom_rules[count.index].destination_port_range
  source_address_prefix       = var.custom_rules[count.index].source_address_prefix
  destination_address_prefix  = var.custom_rules[count.index].destination_address_prefix
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg.name
  description                 = "Custom rule: ${var.custom_rules[count.index].name}"
}

# Default Deny Inbound (explicit)
resource "azurerm_network_security_rule" "deny_all_inbound" {
  name                        = "Deny-All-Inbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg.name
  description                 = "Explicit deny all inbound traffic"
}
