###############################################################################
# Run Control Plane - Outputs
# Production deployment outputs
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
  value       = local.computed.resource_group_id
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = local.resource_group_location
}

# ============================================================================
# State Storage Outputs
# ============================================================================

output "state_storage_resource_group" {
  description = "Resource group containing state storage"
  value       = local.resource_group_name
}

output "state_storage_account_name" {
  description = "Name of the state storage account"
  value       = azurerm_storage_account.tfstate.name
}

output "state_storage_container_name" {
  description = "Name of the state storage container"
  value       = "tfstate"  # Using existing backend container
}

output "state_storage_access_key" {
  description = "Access key for state storage account (sensitive)"
  value       = azurerm_storage_account.tfstate.primary_access_key
  sensitive   = true
}

output "state_storage_connection_string" {
  description = "Connection string for state storage account (sensitive)"
  value       = azurerm_storage_account.tfstate.primary_connection_string
  sensitive   = true
}

# ============================================================================
# Key Vault Outputs
# ============================================================================

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.control_plane.name
}

output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = azurerm_key_vault.control_plane.id
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.control_plane.vault_uri
}

# ============================================================================
# Deployment Metadata Outputs
# ============================================================================

output "subscription_id" {
  description = "Azure subscription ID"
  value       = local.subscription_id
}

output "tenant_id" {
  description = "Azure tenant ID"
  value       = data.azurerm_client_config.current.tenant_id
}

output "random_id" {
  description = "Random ID used for resource naming"
  value       = local.random_id
}

output "automation_version" {
  description = "Version of the VM automation framework"
  value       = local.deployment.framework_version
}

output "deployment_id" {
  description = "Unique deployment identifier"
  value       = local.deployment.id
}

output "deployment_timestamp" {
  description = "Timestamp of deployment"
  value       = local.deployment.timestamp
}

# ============================================================================
# Backend Configuration Output (for subsequent deployments)
# ============================================================================

output "backend_config" {
  description = "Backend configuration for subsequent Terraform deployments"
  value = {
    subscription_id      = local.subscription_id
    resource_group_name  = "rg-vmaut-mgmt-eus-main-rg"
    storage_account_name = "stvmautmgmteustfstatef9e"
    container_name       = "tfstate"
    key                  = "control-plane.tfstate"
  }
}

output "backend_config_file_content" {
  description = "Content for backend-config.tfvars file"
  value = <<-EOT
    subscription_id      = "${local.subscription_id}"
    resource_group_name  = "rg-vmaut-mgmt-eus-main-rg"
    storage_account_name = "stvmautmgmteustfstatef9e"
    container_name       = "tfstate"
    key                  = "control-plane.tfstate"
  EOT
}

# ============================================================================
# Naming Module Outputs (for reference)
# ============================================================================

output "naming_module_outputs" {
  description = "All naming module outputs"
  value       = module.naming.names
}
