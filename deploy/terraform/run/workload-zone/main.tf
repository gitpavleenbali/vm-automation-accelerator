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
    #   -backend-config="key=workload-zone-{env}-{region}.tfstate" \
    #   -backend-config="use_azuread_auth=true"
    use_azuread_auth = true
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
  storage_use_azuread = true
  
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  
  subscription_id = var.control_plane_subscription_id
}

# Default provider (aliases to main)
provider "azurerm" {
  storage_use_azuread = true
  
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
  
  environment      = var.environment
  location         = var.location
  project_code     = var.project_code
  workload_name    = var.workload_name
  instance_number  = var.instance_number
  
  resource_prefixes = {
    # Compute
    vm                    = "vm"
    vmss                  = "vmss"
    nic                   = "nic"
    pip                   = "pip"
    
    # Storage
    storage_account       = "st"
    disk                  = "disk"
    
    # Networking
    vnet                  = "vnet"
    subnet                = "snet"
    nsg                   = "nsg"
    route_table           = "rt"
    load_balancer         = "lb"
    application_gateway   = "agw"
    
    # Security
    key_vault             = "kv"
    managed_identity      = "id"
    
    # Monitoring
    log_analytics         = "log"
    application_insights  = "appi"
    action_group          = "ag"
    
    # Resource Group
    resource_group        = "rg"
  }
  
  resource_suffixes = {
    vm                    = ""
    vmss                  = ""
    nic                   = ""
    pip                   = ""
    storage_account       = ""
    disk                  = ""
    vnet                  = ""
    subnet                = ""
    nsg                   = ""
    route_table           = ""
    load_balancer         = ""
    application_gateway   = ""
    key_vault             = ""
    managed_identity      = ""
    log_analytics         = ""
    application_insights  = ""
    action_group          = ""
    resource_group        = ""
  }
}

# ============================================================================
# Resource Group
# ============================================================================

resource "azurerm_resource_group" "workload_zone" {
  count    = var.resource_group_name != null ? 0 : 1
  provider = azurerm.main
  
  name     = module.naming.resource_group_names["network"]
  location = var.location
  tags     = merge(local.common_tags, { Purpose = "Network Infrastructure" })
}

# ============================================================================
# DDoS Protection Plan (Optional)
# ============================================================================

resource "azurerm_network_ddos_protection_plan" "workload_zone" {
  count               = var.enable_ddos_protection && var.ddos_protection_plan_id == null ? 1 : 0
  provider            = azurerm.main
  
  name                = "${module.naming.resource_group_names["network"]}-ddos"
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  
  tags = merge(
    local.common_tags,
    { Purpose = "DDoS Protection" }
  )
  
  depends_on = [azurerm_resource_group.workload_zone]
}

# ============================================================================
# Virtual Network
# ============================================================================

resource "azurerm_virtual_network" "workload_zone" {
  provider            = azurerm.main
  
  name                = module.naming.vnet_name
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  address_space       = var.vnet_address_space
  dns_servers         = var.dns_servers
  
  dynamic "ddos_protection_plan" {
    for_each = var.enable_ddos_protection ? [1] : []
    content {
      id     = var.ddos_protection_plan_id != null ? var.ddos_protection_plan_id : azurerm_network_ddos_protection_plan.workload_zone[0].id
      enable = true
    }
  }
  
  tags = merge(
    local.common_tags,
    {
      Purpose     = "Virtual Network"
      Criticality = var.environment == "prod" ? "Critical" : "Medium"
    }
  )
  
  depends_on = [
    azurerm_resource_group.workload_zone,
    azurerm_network_ddos_protection_plan.workload_zone
  ]
}

# ============================================================================
# Network Security Groups
# ============================================================================

resource "azurerm_network_security_group" "subnets" {
  for_each = var.enable_nsg ? var.subnets : {}
  provider = azurerm.main
  
  name                = module.naming.nsg_names[each.key]
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  
  tags = merge(local.common_tags, { Purpose = "Network Security" })
  
  depends_on = [azurerm_resource_group.workload_zone]
}

# Custom NSG Rules
resource "azurerm_network_security_rule" "custom" {
  for_each = var.enable_nsg ? {
    for rule in flatten([
      for subnet_name, rules in var.nsg_rules : [
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
  for_each = var.enable_route_table ? var.subnets : {}
  provider = azurerm.main
  
  name                = "${module.naming.route_table_name}-${each.key}"
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  
  tags = merge(local.common_tags, { Purpose = "Network Routing" })
  
  depends_on = [azurerm_resource_group.workload_zone]
}

# Custom Routes
resource "azurerm_route" "custom" {
  for_each = var.enable_route_table ? {
    for route in flatten([
      for subnet_name, routes in var.routes : [
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
  for_each = var.subnets
  provider = azurerm.main
  
  name                 = module.naming.subnet_names[each.key]
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
  for_each = var.enable_nsg ? var.subnets : {}
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
  for_each = var.enable_route_table ? var.subnets : {}
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
  count                        = var.enable_vnet_peering && var.peering_config != null ? 1 : 0
  provider                     = azurerm.main
  
  name                         = "${azurerm_virtual_network.workload_zone.name}-to-remote"
  resource_group_name          = local.resource_group_name
  virtual_network_name         = azurerm_virtual_network.workload_zone.name
  remote_virtual_network_id    = var.peering_config.remote_vnet_id
  
  allow_virtual_network_access = var.peering_config.allow_virtual_network_access
  allow_forwarded_traffic      = var.peering_config.allow_forwarded_traffic
  allow_gateway_transit        = var.peering_config.allow_gateway_transit
  use_remote_gateways          = var.peering_config.use_remote_gateways
  
  depends_on = [azurerm_virtual_network.workload_zone]
}

# ============================================================================
# Private DNS Zones (Optional)
# ============================================================================

resource "azurerm_private_dns_zone" "workload_zone" {
  for_each = var.enable_private_dns_zones ? toset(var.private_dns_zones) : []
  provider = azurerm.main
  
  name                = each.value
  resource_group_name = local.resource_group_name
  
  tags = merge(local.common_tags, { Purpose = "Private DNS" })
  
  depends_on = [azurerm_resource_group.workload_zone]
}

resource "azurerm_private_dns_zone_virtual_network_link" "workload_zone" {
  for_each = var.enable_private_dns_zones ? toset(var.private_dns_zones) : []
  provider = azurerm.main
  
  name                  = "${azurerm_virtual_network.workload_zone.name}-link"
  resource_group_name   = local.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.workload_zone[each.key].name
  virtual_network_id    = azurerm_virtual_network.workload_zone.id
  
  tags = merge(local.common_tags, { Purpose = "Private DNS" })
  
  depends_on = [
    azurerm_private_dns_zone.workload_zone,
    azurerm_virtual_network.workload_zone
  ]
}

# ============================================================================
# ARM Deployment Tracking (for Azure Portal visibility)
# ============================================================================

resource "azurerm_resource_group_template_deployment" "workload_zone" {
  count               = var.enable_arm_deployment_tracking ? 1 : 0
  provider            = azurerm.main
  
  name                = "vm-automation-workload-zone-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  resource_group_name = local.resource_group_name
  deployment_mode     = "Incremental"
  
  template_content = jsonencode({
    "$schema"      = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
    contentVersion = "1.0.0.0"
    resources      = []
    outputs = {
      deploymentType = {
        type  = "string"
        value = "run-workload-zone"
      }
      frameworkVersion = {
        type  = "string"
        value = var.automation_version
      }
      vnetId = {
        type  = "string"
        value = azurerm_virtual_network.workload_zone.id
      }
      subnetCount = {
        type  = "int"
        value = length(var.subnets)
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
