/**
 * Reusable Network Module
 * 
 * Purpose:
 *   - Provides reusable patterns for deploying Azure Virtual Networks
 *   - Supports multiple subnets with custom configuration
 *   - Network Security Groups with rule templates
 *   - Route tables and user-defined routes
 *   - VNet peering capabilities
 * 
 * Usage:
 *   module "network" {
 *     source = "../../terraform-units/modules/network"
 *     
 *     resource_group_name = azurerm_resource_group.main.name
 *     location            = azurerm_resource_group.main.location
 *     
 *     vnet_name          = "vnet-dev-eastus"
 *     vnet_address_space = ["10.0.0.0/16"]
 *     
 *     subnets = {
 *       web = {
 *         name             = "snet-web"
 *         address_prefixes = ["10.0.1.0/24"]
 *         nsg_rules = {
 *           allow_http = {
 *             priority  = 100
 *             direction = "Inbound"
 *             access    = "Allow"
 *             protocol  = "Tcp"
 *             source_port_range = "*"
 *             destination_port_range = "80"
 *             source_address_prefix = "*"
 *             destination_address_prefix = "*"
 *           }
 *         }
 *       }
 *     }
 *   }
 */

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

#=============================================================================
# TRANSFORM LAYER - Input Normalization
#=============================================================================

locals {
  # Normalize VNet configuration
  vnet = {
    name           = var.vnet_name
    address_space  = var.vnet_address_space
    dns_servers    = try(var.vnet_dns_servers, [])
    ddos_protection_plan_id = try(var.ddos_protection_plan_id, null)
  }
  
  # Normalize subnet configurations
  normalized_subnets = {
    for subnet_key, subnet_config in var.subnets : subnet_key => merge(
      {
        # Required fields
        name             = subnet_config.name
        address_prefixes = subnet_config.address_prefixes
        
        # Optional fields with defaults
        service_endpoints = try(subnet_config.service_endpoints, [])
        delegation        = try(subnet_config.delegation, null)
        
        # Network policies
        private_endpoint_network_policies_enabled     = try(subnet_config.private_endpoint_network_policies_enabled, true)
        private_link_service_network_policies_enabled = try(subnet_config.private_link_service_network_policies_enabled, true)
        
        # NSG and Route Table
        create_nsg             = try(subnet_config.create_nsg, true)
        nsg_name               = try(subnet_config.nsg_name, "${subnet_config.name}-nsg")
        nsg_rules              = try(subnet_config.nsg_rules, {})
        
        create_route_table     = try(subnet_config.create_route_table, false)
        route_table_name       = try(subnet_config.route_table_name, "${subnet_config.name}-rt")
        routes                 = try(subnet_config.routes, {})
        
        # Tags
        tags = merge(
          var.tags,
          try(subnet_config.tags, {})
        )
      }
    )
  }
  
  # Flatten NSG rules for creation
  nsg_rules = flatten([
    for subnet_key, subnet_config in local.normalized_subnets : [
      for rule_key, rule_config in subnet_config.nsg_rules : {
        subnet_key = subnet_key
        rule_key   = rule_key
        nsg_name   = subnet_config.nsg_name
        
        # Rule properties
        name                         = try(rule_config.name, rule_key)
        priority                     = rule_config.priority
        direction                    = rule_config.direction
        access                       = rule_config.access
        protocol                     = rule_config.protocol
        source_port_range            = try(rule_config.source_port_range, null)
        source_port_ranges           = try(rule_config.source_port_ranges, null)
        destination_port_range       = try(rule_config.destination_port_range, null)
        destination_port_ranges      = try(rule_config.destination_port_ranges, null)
        source_address_prefix        = try(rule_config.source_address_prefix, null)
        source_address_prefixes      = try(rule_config.source_address_prefixes, null)
        destination_address_prefix   = try(rule_config.destination_address_prefix, null)
        destination_address_prefixes = try(rule_config.destination_address_prefixes, null)
        description                  = try(rule_config.description, "Managed by Terraform")
      }
    ] if subnet_config.create_nsg
  ])
  
  # Flatten routes for creation
  routes = flatten([
    for subnet_key, subnet_config in local.normalized_subnets : [
      for route_key, route_config in subnet_config.routes : {
        subnet_key       = subnet_key
        route_key        = route_key
        route_table_name = subnet_config.route_table_name
        
        # Route properties
        name                   = try(route_config.name, route_key)
        address_prefix         = route_config.address_prefix
        next_hop_type          = route_config.next_hop_type
        next_hop_in_ip_address = try(route_config.next_hop_in_ip_address, null)
      }
    ] if subnet_config.create_route_table
  ])
}

#=============================================================================
# VIRTUAL NETWORK
#=============================================================================

resource "azurerm_virtual_network" "vnet" {
  name                = local.vnet.name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = local.vnet.address_space
  dns_servers         = local.vnet.dns_servers
  
  dynamic "ddos_protection_plan" {
    for_each = local.vnet.ddos_protection_plan_id != null ? [1] : []
    content {
      id     = local.vnet.ddos_protection_plan_id
      enable = true
    }
  }
  
  tags = var.tags
  
  lifecycle {
    ignore_changes = [
      tags["created_date"],
      tags["created_by"]
    ]
  }
}

#=============================================================================
# NETWORK SECURITY GROUPS
#=============================================================================

resource "azurerm_network_security_group" "nsg" {
  for_each = {
    for subnet_key, subnet_config in local.normalized_subnets : subnet_key => subnet_config
    if subnet_config.create_nsg
  }
  
  name                = each.value.nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name
  
  tags = each.value.tags
}

#=============================================================================
# NETWORK SECURITY RULES
#=============================================================================

resource "azurerm_network_security_rule" "nsg_rule" {
  for_each = {
    for rule in local.nsg_rules : "${rule.subnet_key}-${rule.rule_key}" => rule
  }
  
  name                        = each.value.name
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol
  source_port_range           = each.value.source_port_range
  source_port_ranges          = each.value.source_port_ranges
  destination_port_range      = each.value.destination_port_range
  destination_port_ranges     = each.value.destination_port_ranges
  source_address_prefix       = each.value.source_address_prefix
  source_address_prefixes     = each.value.source_address_prefixes
  destination_address_prefix  = each.value.destination_address_prefix
  destination_address_prefixes = each.value.destination_address_prefixes
  description                 = each.value.description
  
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg[each.value.subnet_key].name
}

#=============================================================================
# ROUTE TABLES
#=============================================================================

resource "azurerm_route_table" "rt" {
  for_each = {
    for subnet_key, subnet_config in local.normalized_subnets : subnet_key => subnet_config
    if subnet_config.create_route_table
  }
  
  name                              = each.value.route_table_name
  location                          = var.location
  resource_group_name               = var.resource_group_name
  bgp_route_propagation_enabled     = !var.disable_bgp_route_propagation
  
  tags = each.value.tags
}

#=============================================================================
# ROUTES
#=============================================================================

resource "azurerm_route" "route" {
  for_each = {
    for route in local.routes : "${route.subnet_key}-${route.route_key}" => route
  }
  
  name                   = each.value.name
  resource_group_name    = var.resource_group_name
  route_table_name       = azurerm_route_table.rt[each.value.subnet_key].name
  address_prefix         = each.value.address_prefix
  next_hop_type          = each.value.next_hop_type
  next_hop_in_ip_address = each.value.next_hop_in_ip_address
}

#=============================================================================
# SUBNETS
#=============================================================================

resource "azurerm_subnet" "subnet" {
  for_each = local.normalized_subnets
  
  name                 = each.value.name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = each.value.address_prefixes
  service_endpoints    = each.value.service_endpoints
  
  # Updated from deprecated boolean attributes
  private_endpoint_network_policies          = each.value.private_endpoint_network_policies_enabled != null ? (each.value.private_endpoint_network_policies_enabled ? "Enabled" : "Disabled") : "Disabled"
  private_link_service_network_policies_enabled = each.value.private_link_service_network_policies_enabled != null ? each.value.private_link_service_network_policies_enabled : true
  
  dynamic "delegation" {
    for_each = each.value.delegation != null ? [each.value.delegation] : []
    content {
      name = delegation.value.name
      service_delegation {
        name    = delegation.value.service_delegation.name
        actions = delegation.value.service_delegation.actions
      }
    }
  }
  
  depends_on = [
    azurerm_network_security_group.nsg,
    azurerm_route_table.rt
  ]
}

#=============================================================================
# SUBNET NSG ASSOCIATIONS
#=============================================================================

resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  for_each = {
    for subnet_key, subnet_config in local.normalized_subnets : subnet_key => subnet_config
    if subnet_config.create_nsg
  }
  
  subnet_id                 = azurerm_subnet.subnet[each.key].id
  network_security_group_id = azurerm_network_security_group.nsg[each.key].id
}

#=============================================================================
# SUBNET ROUTE TABLE ASSOCIATIONS
#=============================================================================

resource "azurerm_subnet_route_table_association" "rt_association" {
  for_each = {
    for subnet_key, subnet_config in local.normalized_subnets : subnet_key => subnet_config
    if subnet_config.create_route_table
  }
  
  subnet_id      = azurerm_subnet.subnet[each.key].id
  route_table_id = azurerm_route_table.rt[each.key].id
}

#=============================================================================
# VNET PEERING
#=============================================================================

resource "azurerm_virtual_network_peering" "peering" {
  for_each = var.vnet_peerings
  
  name                         = each.value.name
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.vnet.name
  remote_virtual_network_id    = each.value.remote_vnet_id
  
  allow_virtual_network_access = try(each.value.allow_virtual_network_access, true)
  allow_forwarded_traffic      = try(each.value.allow_forwarded_traffic, false)
  allow_gateway_transit        = try(each.value.allow_gateway_transit, false)
  use_remote_gateways          = try(each.value.use_remote_gateways, false)
}

#=============================================================================
# PRIVATE DNS ZONES
#=============================================================================

resource "azurerm_private_dns_zone" "dns_zone" {
  for_each = var.private_dns_zones
  
  name                = each.value.name
  resource_group_name = var.resource_group_name
  
  tags = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_link" {
  for_each = var.private_dns_zones
  
  name                  = "${each.value.name}-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.dns_zone[each.key].name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = try(each.value.registration_enabled, false)
  
  tags = var.tags
}
