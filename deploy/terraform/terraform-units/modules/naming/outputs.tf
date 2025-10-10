###############################################################################
# Naming Module - Outputs
###############################################################################

output "location_code" {
  description = "Abbreviated location code"
  value       = local.location_code
}

output "resource_group_names" {
  description = "Map of resource group names by type"
  value       = local.resource_group_names
}

output "vm_names" {
  description = "Map of VM names by OS type"
  value       = local.vm_names
}

output "vmss_name" {
  description = "Virtual Machine Scale Set name"
  value       = local.vmss_name
}

output "nic_names" {
  description = "List of Network Interface names"
  value       = local.nic_names
}

output "pip_names" {
  description = "List of Public IP names"
  value       = local.pip_names
}

output "storage_account_names" {
  description = "Map of storage account names by type"
  value       = local.storage_account_names
}

output "disk_names" {
  description = "List of managed disk names"
  value       = local.disk_names
}

output "vnet_name" {
  description = "Virtual Network name"
  value       = local.vnet_name
}

output "subnet_names" {
  description = "Map of subnet names by tier"
  value       = local.subnet_names
}

output "nsg_names" {
  description = "Map of Network Security Group names by tier"
  value       = local.nsg_names
}

output "route_table_name" {
  description = "Route Table name"
  value       = local.route_table_name
}

output "load_balancer_name" {
  description = "Load Balancer name"
  value       = local.load_balancer_name
}

output "application_gateway_name" {
  description = "Application Gateway name"
  value       = local.application_gateway_name
}

output "key_vault_name" {
  description = "Key Vault name"
  value       = local.key_vault_name
}

output "managed_identity_name" {
  description = "Managed Identity name"
  value       = local.managed_identity_name
}

output "log_analytics_name" {
  description = "Log Analytics Workspace name"
  value       = local.log_analytics_name
}

output "application_insights_name" {
  description = "Application Insights name"
  value       = local.application_insights_name
}

output "action_group_name" {
  description = "Action Group name"
  value       = local.action_group_name
}

output "common_tags" {
  description = "Common tags to apply to all resources"
  value       = local.common_tags
}

output "naming_convention" {
  description = "Naming convention used"
  value       = var.naming_convention
}

# Convenience outputs for direct resource creation
output "names" {
  description = "All resource names consolidated"
  value = {
    resource_groups       = local.resource_group_names
    vms                   = local.vm_names
    vmss                  = local.vmss_name
    nics                  = local.nic_names
    pips                  = local.pip_names
    storage_accounts      = local.storage_account_names
    disks                 = local.disk_names
    vnet                  = local.vnet_name
    subnets               = local.subnet_names
    nsgs                  = local.nsg_names
    route_table           = local.route_table_name
    load_balancer         = local.load_balancer_name
    application_gateway   = local.application_gateway_name
    key_vault             = local.key_vault_name
    managed_identity      = local.managed_identity_name
    log_analytics         = local.log_analytics_name
    application_insights  = local.application_insights_name
    action_group          = local.action_group_name
  }
}
