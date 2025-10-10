#=============================================================================
# BACKUP MODULE OUTPUTS
#=============================================================================

output "vault_id" {
  description = "Azure resource ID of the Recovery Services Vault"
  value       = azurerm_recovery_services_vault.vault.id
}

output "vault_name" {
  description = "Name of the Recovery Services Vault"
  value       = azurerm_recovery_services_vault.vault.name
}

output "backup_policy_ids" {
  description = "Map of backup policy names to their resource IDs"
  value = {
    for k, v in azurerm_backup_policy_vm.policy : k => v.id
  }
}

output "backup_policy_names" {
  description = "Map of backup policy keys to their Azure names"
  value = {
    for k, v in azurerm_backup_policy_vm.policy : k => v.name
  }
}

output "protected_vm_ids" {
  description = "List of protected VM resource IDs"
  value = [
    for k, v in azurerm_backup_protected_vm.vm_backup : v.source_vm_id
  ]
}

output "backup_configuration" {
  description = "Summary of backup configuration"
  value = {
    vault_name               = azurerm_recovery_services_vault.vault.name
    vault_sku                = var.vault_sku
    storage_mode             = var.storage_mode_type
    cross_region_restore     = var.enable_cross_region_restore
    soft_delete_enabled      = var.enable_soft_delete
    policy_count             = length(var.backup_policies)
    protected_vm_count       = length(var.protected_vms)
    encryption_enabled       = var.encryption_key_id != null
    infrastructure_encrypted = var.enable_infrastructure_encryption
  }
}
