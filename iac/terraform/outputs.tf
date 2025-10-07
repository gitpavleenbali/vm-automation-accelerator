# Terraform Outputs
# These outputs are used for ServiceNow integration and pipeline validation

output "vm_id" {
  description = "Resource ID of the virtual machine"
  value       = module.virtual_machine.vm_id
}

output "vm_name" {
  description = "Name of the virtual machine"
  value       = module.virtual_machine.vm_name
}

output "vm_private_ip" {
  description = "Private IP address of the virtual machine"
  value       = module.network_interface.private_ip_address
}

output "vm_public_ip" {
  description = "Public IP address of the virtual machine (if enabled)"
  value       = var.enable_public_ip ? module.network_interface.public_ip_address : null
}

output "vm_fqdn" {
  description = "Fully qualified domain name of the virtual machine"
  value       = var.enable_domain_join && var.os_type == "Windows" ? "${var.vm_name}.${var.domain_name}" : null
}

output "nic_id" {
  description = "Resource ID of the network interface"
  value       = module.network_interface.nic_id
}

output "nsg_id" {
  description = "Resource ID of the network security group"
  value       = module.network_security.nsg_id
}

output "admin_username" {
  description = "Administrator username (supports both account_credentials and legacy pattern)"
  value       = local.admin_username
}

output "admin_password_keyvault_secret_id" {
  description = "Key Vault secret ID for admin password (AVM pattern)"
  value       = local.should_store_in_keyvault ? azurerm_key_vault_secret.vm_admin_password[0].id : null
  sensitive   = true
}

output "admin_password_keyvault_secret_name" {
  description = "Key Vault secret name for admin password"
  value       = local.should_store_in_keyvault ? azurerm_key_vault_secret.vm_admin_password[0].name : null
  sensitive   = false
}

output "credential_auto_generated" {
  description = "Whether credentials were auto-generated"
  value       = local.should_generate_password
}

output "backup_enabled" {
  description = "Whether Azure Backup is enabled"
  value       = var.enable_backup
}

output "backup_policy_id" {
  description = "Backup policy ID (if backup enabled)"
  value       = var.enable_backup ? var.backup_policy_id : null
}

output "asr_enabled" {
  description = "Whether Azure Site Recovery is enabled"
  value       = var.enable_asr
}

output "monitoring_enabled" {
  description = "Whether Azure Monitor agents are installed"
  value       = true
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID"
  value       = data.azurerm_log_analytics_workspace.main.id
}

output "resource_group_name" {
  description = "Resource group name"
  value       = data.azurerm_resource_group.main.name
}

output "location" {
  description = "Azure region"
  value       = data.azurerm_resource_group.main.location
}

output "tags" {
  description = "Resource tags applied"
  value       = local.common_tags
}

output "terraform_state_info" {
  description = "Terraform state information for tracking"
  value = {
    backend_type    = "azurerm"
    state_key       = "vm-automation/${var.environment}/terraform.tfstate"
    workspace       = terraform.workspace
    last_updated    = timestamp()
  }
}
