/**
 * Azure Backup Policy Module
 * 
 * Purpose:
 *   - Creates and manages Azure Backup policies for VMs
 *   - Configures Recovery Services Vault
 *   - Implements backup schedules and retention policies
 *   - Enables VM backup protection
 * 
 * Usage:
 *   module "vm_backup" {
 *     source = "../../terraform-units/modules/backup-policy"
 *     
 *     resource_group_name = azurerm_resource_group.main.name
 *     location            = azurerm_resource_group.main.location
 *     vault_name          = "rsv-backup-prod"
 *     
 *     backup_policies = {
 *       daily = {
 *         name      = "daily-backup-policy"
 *         frequency = "Daily"
 *         time      = "23:00"
 *         retention_daily_count = 30
 *       }
 *     }
 *     
 *     protected_vms = {
 *       vm1 = {
 *         vm_id         = azurerm_linux_virtual_machine.vm.id
 *         policy_name   = "daily"
 *       }
 *     }
 *     
 *     tags = var.tags
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
# RECOVERY SERVICES VAULT
#=============================================================================

resource "azurerm_recovery_services_vault" "vault" {
  name                = var.vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.vault_sku
  
  storage_mode_type         = var.storage_mode_type
  cross_region_restore_enabled = var.enable_cross_region_restore
  soft_delete_enabled       = var.enable_soft_delete
  
  # Encryption configuration
  dynamic "encryption" {
    for_each = var.encryption_key_id != null ? [1] : []
    content {
      key_id                            = var.encryption_key_id
      infrastructure_encryption_enabled = var.enable_infrastructure_encryption
    }
  }
  
  tags = var.tags
}

#=============================================================================
# BACKUP POLICIES
#=============================================================================

resource "azurerm_backup_policy_vm" "policy" {
  for_each = var.backup_policies
  
  name                = each.value.name
  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.vault.name
  
  # Backup schedule
  backup {
    frequency = each.value.frequency
    time      = each.value.time
    weekdays  = try(each.value.weekdays, null)
  }
  
  # Daily retention
  dynamic "retention_daily" {
    for_each = try(each.value.retention_daily_count, null) != null ? [1] : []
    content {
      count = each.value.retention_daily_count
    }
  }
  
  # Weekly retention
  dynamic "retention_weekly" {
    for_each = try(each.value.retention_weekly, null) != null ? [1] : []
    content {
      count    = each.value.retention_weekly.count
      weekdays = each.value.retention_weekly.weekdays
    }
  }
  
  # Monthly retention
  dynamic "retention_monthly" {
    for_each = try(each.value.retention_monthly, null) != null ? [1] : []
    content {
      count    = each.value.retention_monthly.count
      weekdays = try(each.value.retention_monthly.weekdays, null)
      weeks    = try(each.value.retention_monthly.weeks, null)
    }
  }
  
  # Yearly retention
  dynamic "retention_yearly" {
    for_each = try(each.value.retention_yearly, null) != null ? [1] : []
    content {
      count    = each.value.retention_yearly.count
      weekdays = try(each.value.retention_yearly.weekdays, null)
      weeks    = try(each.value.retention_yearly.weeks, null)
      months   = each.value.retention_yearly.months
    }
  }
  
  # Instant restore settings
  instant_restore_retention_days = try(each.value.instant_restore_days, 5)
  
  # Timezone
  timezone = try(each.value.timezone, "UTC")
}

#=============================================================================
# VM BACKUP PROTECTION
#=============================================================================

resource "azurerm_backup_protected_vm" "vm_backup" {
  for_each = var.protected_vms
  
  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.vault.name
  source_vm_id        = each.value.vm_id
  backup_policy_id    = azurerm_backup_policy_vm.policy[each.value.policy_name].id
}
