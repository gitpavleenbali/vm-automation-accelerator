###############################################################################
# Run Workload Zone - Main Configuration
# Network infrastructure with remote state backend
###############################################################################

terraform {
  required_version = ">= 1.5.0"
  
  # Remote backend configuration (parameters provided via backend-config)
  backend "azurerm" {
    # Configuration provided via:
    # terraform init \
    #   -backend-config="subscription_id=xxx" \
    #   -backend-config="resource_group_name=xxx" \
    #   -backend-config="storage_account_name=xxx" \
    #   -backend-config="container_name=tfstate" \
    #   -backend-config="key=workload-zone-{env}-{region}.tfstate"
  }
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.10"
    }
  }
}

# Main provider for workload zone resources
provider "azurerm" {
  alias = "main"
  
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  
  subscription_id = var.control_plane_subscription_id
}

# Default provider (aliases to main)
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  
  subscription_id = var.control_plane_subscription_id
}

# AzAPI provider for advanced features
provider "azapi" {
  subscription_id = var.control_plane_subscription_id
}

# ============================================================================
# Naming Module
# ============================================================================

module "naming" {
  source = "../../terraform-units/modules/naming"
  
  environment      = local.environment.name
  location         = local.location.name
  project_code     = local.project.code
  workload_name    = local.workload.name
  instance_number  = local.workload.instance_number
  
  resource_prefixes = {
    resource_group  = "rg"
    vnet            = "vnet"
    subnet          = "snet"
    nsg             = "nsg"
    route_table     = "rt"
  }
  
  resource_suffixes = {
    resource_group  = "wz-rg"
    vnet            = "vnet"
    subnet          = "snet"
    nsg             = "nsg"
    route_table     = "rt"
  }
}

# ============================================================================
# Resource Group
# ============================================================================

resource "azurerm_resource_group" "workload_zone" {
  count    = local.resource_group.use_existing ? 0 : 1
  provider = azurerm.main
  
  name     = coalesce(local.resource_group.name, module.naming.resource_group_name)
  location = local.resource_group.location
  tags     = local.resource_group.tags
}

locals {
  resource_group_name = local.resource_group.use_existing ? (
    data.azurerm_resource_group.existing[0].name
  ) : (
    azurerm_resource_group.workload_zone[0].name
  )
  
  resource_group_location = local.resource_group.use_existing ? (
    data.azurerm_resource_group.existing[0].location
  ) : (
    azurerm_resource_group.workload_zone[0].location
  )
}

# ============================================================================
# DDoS Protection Plan (Optional)
# ============================================================================

resource "azurerm_network_ddos_protection_plan" "workload_zone" {
  count               = local.computed.create_ddos_plan ? 1 : 0
  provider            = azurerm.main
  
  name                = "${module.naming.resource_group_name}-ddos"
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  
  tags = merge(
    local.common_tags,
    { Purpose = "DDoS Protection" }
  )
  
  depends_on = [azurerm_resource_group.workload_zone]
}

locals {
  ddos_protection_plan = local.vnet.enable_ddos_protection ? {
    id     = local.computed.use_existing_ddos ? local.vnet.ddos_protection_plan_id : azurerm_network_ddos_protection_plan.workload_zone[0].id
    enable = true
  } : null
}

# ============================================================================
# Virtual Network
# ============================================================================

resource "azurerm_virtual_network" "workload_zone" {
  provider            = azurerm.main
  
  name                = module.naming.vnet_name
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  address_space       = local.vnet.address_space
  dns_servers         = local.vnet.dns_servers
  
  dynamic "ddos_protection_plan" {
    for_each = local.ddos_protection_plan != null ? [local.ddos_protection_plan] : []
    content {
      id     = ddos_protection_plan.value.id
      enable = ddos_protection_plan.value.enable
    }
  }
  
  tags = local.vnet.tags
  
  depends_on = [
    azurerm_resource_group.workload_zone,
    azurerm_network_ddos_protection_plan.workload_zone
  ]
}

# ============================================================================
# Network Security Groups
# ============================================================================

resource "azurerm_network_security_group" "subnets" {
  for_each = local.nsg.enabled ? local.subnets : {}
  provider = azurerm.main
  
  name                = "${module.naming.nsg_name}-${each.key}"
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  
  tags = local.nsg.tags
  
  depends_on = [azurerm_resource_group.workload_zone]
}

# Custom NSG Rules
resource "azurerm_network_security_rule" "custom" {
  for_each = local.nsg.enabled ? {
    for rule in flatten([
      for subnet_name, rules in local.nsg.rules : [
        for rule in rules : {
          key                        = "${subnet_name}-${rule.name}"
          subnet_name                = subnet_name
          name                       = rule.name
          priority                   = rule.priority
          direction                  = rule.direction
          access                     = rule.access
          protocol                   = rule.protocol
          source_port_range          = rule.source_port_range
          destination_port_range     = rule.destination_port_range
          source_address_prefix      = rule.source_address_prefix
          destination_address_prefix = rule.destination_address_prefix
        }
      ]
    ]) : rule.key => rule
  } : {}
  
  provider = azurerm.main
  
  name                        = each.value.name
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol
  source_port_range           = each.value.source_port_range
  destination_port_range      = each.value.destination_port_range
  source_address_prefix       = each.value.source_address_prefix
  destination_address_prefix  = each.value.destination_address_prefix
  resource_group_name         = local.resource_group_name
  network_security_group_name = azurerm_network_security_group.subnets[each.value.subnet_name].name
  
  depends_on = [azurerm_network_security_group.subnets]
}

# ============================================================================
# Route Tables
# ============================================================================

resource "azurerm_route_table" "subnets" {
  for_each = local.route_table.enabled ? local.subnets : {}
  provider = azurerm.main
  
  name                = "${module.naming.route_table_name}-${each.key}"
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  
  tags = local.route_table.tags
  
  depends_on = [azurerm_resource_group.workload_zone]
}

# Custom Routes
resource "azurerm_route" "custom" {
  for_each = local.route_table.enabled ? {
    for route in flatten([
      for subnet_name, routes in local.route_table.routes : [
        for route in routes : {
          key                    = "${subnet_name}-${route.name}"
          subnet_name            = subnet_name
          name                   = route.name
          address_prefix         = route.address_prefix
          next_hop_type          = route.next_hop_type
          next_hop_in_ip_address = route.next_hop_in_ip_address
        }
      ]
    ]) : route.key => route
  } : {}
  
  provider = azurerm.main
  
  name                   = each.value.name
  resource_group_name    = local.resource_group_name
  route_table_name       = azurerm_route_table.subnets[each.value.subnet_name].name
  address_prefix         = each.value.address_prefix
  next_hop_type          = each.value.next_hop_type
  next_hop_in_ip_address = each.value.next_hop_in_ip_address
  
  depends_on = [azurerm_route_table.subnets]
}

# ============================================================================
# Subnets
# ============================================================================

resource "azurerm_subnet" "workload_zone" {
  for_each = local.subnets
  provider = azurerm.main
  
  name                 = "${module.naming.subnet_name}-${each.key}"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.workload_zone.name
  address_prefixes     = [each.value.address_prefix]
  service_endpoints    = each.value.service_endpoints
  
  # Updated from deprecated boolean attributes to new string attributes
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
    azurerm_virtual_network.workload_zone
  ]
}

# Associate NSGs with Subnets
resource "azurerm_subnet_network_security_group_association" "workload_zone" {
  for_each = local.nsg.enabled ? local.subnets : {}
  provider = azurerm.main
  
  subnet_id                 = azurerm_subnet.workload_zone[each.key].id
  network_security_group_id = azurerm_network_security_group.subnets[each.key].id
  
  depends_on = [
    azurerm_subnet.workload_zone,
    azurerm_network_security_group.subnets
  ]
}

# Associate Route Tables with Subnets
resource "azurerm_subnet_route_table_association" "workload_zone" {
  for_each = local.route_table.enabled ? local.subnets : {}
  provider = azurerm.main
  
  subnet_id      = azurerm_subnet.workload_zone[each.key].id
  route_table_id = azurerm_route_table.subnets[each.key].id
  
  depends_on = [
    azurerm_subnet.workload_zone,
    azurerm_route_table.subnets
  ]
}

# ============================================================================
# VNet Peering (Optional)
# ============================================================================

resource "azurerm_virtual_network_peering" "workload_zone_to_remote" {
  count                        = local.peering.enabled && local.peering.config != null ? 1 : 0
  provider                     = azurerm.main
  
  name                         = "${azurerm_virtual_network.workload_zone.name}-to-remote"
  resource_group_name          = local.resource_group_name
  virtual_network_name         = azurerm_virtual_network.workload_zone.name
  remote_virtual_network_id    = local.peering.config.remote_vnet_id
  
  allow_virtual_network_access = local.peering.config.allow_virtual_network_access
  allow_forwarded_traffic      = local.peering.config.allow_forwarded_traffic
  allow_gateway_transit        = local.peering.config.allow_gateway_transit
  use_remote_gateways          = local.peering.config.use_remote_gateways
  
  depends_on = [azurerm_virtual_network.workload_zone]
}

# ============================================================================
# Private DNS Zones (Optional)
# ============================================================================

resource "azurerm_private_dns_zone" "workload_zone" {
  for_each = local.private_dns.enabled ? toset(local.private_dns.zones) : []
  provider = azurerm.main
  
  name                = each.value
  resource_group_name = local.resource_group_name
  
  tags = local.private_dns.tags
  
  depends_on = [azurerm_resource_group.workload_zone]
}

resource "azurerm_private_dns_zone_virtual_network_link" "workload_zone" {
  for_each = local.private_dns.enabled ? toset(local.private_dns.zones) : []
  provider = azurerm.main
  
  name                  = "${azurerm_virtual_network.workload_zone.name}-link"
  resource_group_name   = local.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.workload_zone[each.key].name
  virtual_network_id    = azurerm_virtual_network.workload_zone.id
  
  tags = local.private_dns.tags
  
  depends_on = [
    azurerm_private_dns_zone.workload_zone,
    azurerm_virtual_network.workload_zone
  ]
}

# ============================================================================
# ARM Deployment Tracking (for Azure Portal visibility)
# ============================================================================

resource "azurerm_resource_group_template_deployment" "workload_zone" {
  count               = local.computed.create_arm_tracking ? 1 : 0
  provider            = azurerm.main
  
  name                = "vm-automation-workload-zone-${local.deployment.id}"
  resource_group_name = local.resource_group_name
  deployment_mode     = "Incremental"
  
  template_content = jsonencode({
    "$schema"      = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
    contentVersion = "1.0.0.0"
    resources      = []
    outputs = {
      deploymentType = {
        type  = "string"
        value = local.deployment.type
      }
      frameworkVersion = {
        type  = "string"
        value = local.deployment.framework_version
      }
      vnetId = {
        type  = "string"
        value = azurerm_virtual_network.workload_zone.id
      }
      subnetCount = {
        type  = "int"
        value = length(local.subnets)
      }
    }
  })
  
  tags = merge(
    local.common_tags,
    {
      DeploymentTracking = "ARM"
    }
  )
  
  depends_on = [
    azurerm_virtual_network.workload_zone,
    azurerm_subnet.workload_zone
  ]
}
