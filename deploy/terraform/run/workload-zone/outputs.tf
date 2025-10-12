###############################################################################
# Run Workload Zone - Outputs
# Network infrastructure outputs
###############################################################################

# ============================================================================
# Resource Group Outputs
# ============================================================================

output "resource_group_name" {
  description = "Name of the resource group"
  value       = local.resource_group_name
}

output "resource_group_id" {
  description = "ID of the resource group"
  value       = local.resource_group_id
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = local.resource_group_location
}

# ============================================================================
# Virtual Network Outputs
# ============================================================================

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.workload_zone.name
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.workload_zone.id
}

output "vnet_address_space" {
  description = "Address space of the virtual network"
  value       = azurerm_virtual_network.workload_zone.address_space
}

output "vnet_guid" {
  description = "GUID of the virtual network"
  value       = azurerm_virtual_network.workload_zone.guid
}

# ============================================================================
# Subnet Outputs
# ============================================================================

output "subnet_ids" {
  description = "Map of subnet names to IDs"
  value = {
    for name, subnet in azurerm_subnet.workload_zone : name => subnet.id
  }
}

output "subnet_names" {
  description = "Map of subnet keys to names"
  value = {
    for name, subnet in azurerm_subnet.workload_zone : name => subnet.name
  }
}

output "subnet_address_prefixes" {
  description = "Map of subnet names to address prefixes"
  value = {
    for name, subnet in azurerm_subnet.workload_zone : name => subnet.address_prefixes
  }
}

output "subnets" {
  description = "Complete subnet information"
  value = {
    for name, subnet in azurerm_subnet.workload_zone : name => {
      id               = subnet.id
      name             = subnet.name
      address_prefixes = subnet.address_prefixes
      service_endpoints = subnet.service_endpoints
    }
  }
}

# ============================================================================
# Network Security Group Outputs
# ============================================================================

output "nsg_ids" {
  description = "Map of NSG names to IDs"
  value = var.enable_nsg ? {
    for name, nsg in azurerm_network_security_group.subnets : name => nsg.id
  } : {}
}

output "nsg_names" {
  description = "Map of NSG keys to names"
  value = var.enable_nsg ? {
    for name, nsg in azurerm_network_security_group.subnets : name => nsg.name
  } : {}
}

# ============================================================================
# Route Table Outputs
# ============================================================================

output "route_table_ids" {
  description = "Map of route table names to IDs"
  value = var.enable_route_table ? {
    for name, rt in azurerm_route_table.subnets : name => rt.id
  } : {}
}

output "route_table_names" {
  description = "Map of route table keys to names"
  value = var.enable_route_table ? {
    for name, rt in azurerm_route_table.subnets : name => rt.name
  } : {}
}

# ============================================================================
# DDoS Protection Outputs
# ============================================================================

output "ddos_protection_plan_id" {
  description = "ID of the DDoS protection plan (if created)"
  value       = var.enable_ddos_protection && var.ddos_protection_plan_id == null ? azurerm_network_ddos_protection_plan.workload_zone[0].id : null
}

output "ddos_protection_enabled" {
  description = "Whether DDoS protection is enabled"
  value       = var.enable_ddos_protection
}

# ============================================================================
# VNet Peering Outputs
# ============================================================================

output "vnet_peering_id" {
  description = "ID of the VNet peering (if created)"
  value       = var.enable_vnet_peering && var.peering_config != null ? azurerm_virtual_network_peering.workload_zone_to_remote[0].id : null
}

output "vnet_peering_enabled" {
  description = "Whether VNet peering is enabled"
  value       = var.enable_vnet_peering
}

# ============================================================================
# Private DNS Outputs
# ============================================================================

output "private_dns_zone_ids" {
  description = "Map of private DNS zone names to IDs"
  value = var.enable_private_dns_zones ? {
    for name, zone in azurerm_private_dns_zone.workload_zone : name => zone.id
  } : {}
}

output "private_dns_zones_enabled" {
  description = "Whether private DNS zones are enabled"
  value       = var.enable_private_dns_zones
}

# ============================================================================
# Control Plane Integration Outputs
# ============================================================================

output "control_plane_subscription_id" {
  description = "Subscription ID of the control plane"
  value       = local.control_plane_subscription_id
}

output "control_plane_resource_group" {
  description = "Resource group of the control plane"
  value       = local.control_plane_resource_group
}

output "control_plane_key_vault_name" {
  description = "Key Vault name from control plane"
  value       = local.control_plane_key_vault_name
}

output "control_plane_key_vault_id" {
  description = "Key Vault ID from control plane"
  value       = local.control_plane_key_vault_id
}

# ============================================================================
# Deployment Metadata Outputs
# ============================================================================

output "deployment_id" {
  description = "Unique deployment identifier"
  value       = formatdate("YYYYMMDDhhmmss", timestamp())
}

output "deployment_timestamp" {
  description = "Timestamp of deployment"
  value       = timestamp()
}

output "automation_version" {
  description = "Version of the VM automation framework"
  value       = var.automation_version
}

# ============================================================================
# State Storage Information (for VM deployments)
# ============================================================================

output "state_backend_config" {
  description = "Backend configuration for VM deployment modules"
  value = {
    subscription_id      = local.state_storage_subscription_id
    resource_group_name  = local.state_storage_resource_group
    storage_account_name = local.state_storage_account_name
    container_name       = local.state_storage_container_name
    key                  = "workload-zone-${var.environment}-${var.location}.tfstate"
  }
}

# ============================================================================
# Naming Module Outputs (for reference)
# ============================================================================

output "naming_module_outputs" {
  description = "All naming module outputs"
  value       = module.naming.names
}

# ============================================================================
# Network Configuration Summary
# ============================================================================

output "network_summary" {
  description = "Summary of network configuration"
  value = {
    vnet_name         = azurerm_virtual_network.workload_zone.name
    vnet_id           = azurerm_virtual_network.workload_zone.id
    address_space     = azurerm_virtual_network.workload_zone.address_space
    subnet_count      = length(var.subnets)
    subnet_names      = [for name, subnet in azurerm_subnet.workload_zone : subnet.name]
    nsg_enabled       = var.enable_nsg
    route_table_enabled = var.enable_route_table
    ddos_enabled      = var.enable_ddos_protection
    peering_enabled   = var.enable_vnet_peering
    dns_zones_enabled = var.enable_private_dns_zones
    environment       = var.environment
    location          = var.location
  }
}
