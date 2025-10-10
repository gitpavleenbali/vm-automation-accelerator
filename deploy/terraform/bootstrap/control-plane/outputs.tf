###############################################################################
# Bootstrap Control Plane - Outputs
###############################################################################

output "resource_group_name" {
  description = "Control plane resource group name"
  value       = local.resource_group_name
}

output "resource_group_id" {
  description = "Control plane resource group ID"
  value       = local.resource_group_id
}

output "location" {
  description = "Deployment location"
  value       = var.location
}

output "tfstate_resource_group_name" {
  description = "Resource group containing Terraform state storage"
  value       = local.resource_group_name
}

output "tfstate_storage_account_name" {
  description = "Storage account name for Terraform state"
  value       = azurerm_storage_account.tfstate.name
}

output "tfstate_storage_account_id" {
  description = "Storage account ID for Terraform state"
  value       = azurerm_storage_account.tfstate.id
}

output "tfstate_container_name" {
  description = "Container name for Terraform state files"
  value       = azurerm_storage_container.tfstate.name
}

output "tfstate_storage_account_primary_access_key" {
  description = "Primary access key for Terraform state storage account"
  value       = azurerm_storage_account.tfstate.primary_access_key
  sensitive   = true
}

output "key_vault_name" {
  description = "Key Vault name"
  value       = var.create_key_vault ? azurerm_key_vault.control_plane[0].name : null
}

output "key_vault_id" {
  description = "Key Vault ID"
  value       = var.create_key_vault ? azurerm_key_vault.control_plane[0].id : null
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = var.create_key_vault ? azurerm_key_vault.control_plane[0].vault_uri : null
}

output "subscription_id" {
  description = "Azure subscription ID"
  value       = local.subscription_id
}

output "random_id" {
  description = "Random ID used for resource naming"
  value       = local.random_id
}

output "automation_version" {
  description = "VM Automation Accelerator version"
  value       = "1.0.0"
}

# Configuration for use in subsequent deployments
output "backend_config" {
  description = "Backend configuration for remote state"
  value = {
    subscription_id      = local.subscription_id
    resource_group_name  = local.resource_group_name
    storage_account_name = azurerm_storage_account.tfstate.name
    container_name       = azurerm_storage_container.tfstate.name
  }
}

output "naming_convention" {
  description = "Naming convention outputs"
  value = {
    location_code = module.naming.location_code
    environment   = var.environment
    project_code  = var.project_code
  }
}
