#=============================================================================
# REQUIRED VARIABLES
#=============================================================================

variable "resource_group_name" {
  description = "Name of the resource group where backup resources will be created"
  type        = string
}

variable "location" {
  description = "Azure region for backup resources"
  type        = string
}

variable "vault_name" {
  description = "Name of the Recovery Services Vault"
  type        = string
}

variable "backup_policies" {
  description = <<-EOT
    Map of backup policies to create. Each policy defines:
    
    Required:
      - name: Policy name
      - frequency: 'Daily' or 'Weekly'
      - time: Backup time in HH:MM format (24-hour)
      
    Optional:
      - weekdays: List of weekdays for weekly backups ['Monday', 'Wednesday', 'Friday']
      - retention_daily_count: Number of daily backups to retain (7-9999)
      - retention_weekly: Weekly retention configuration
      - retention_monthly: Monthly retention configuration
      - retention_yearly: Yearly retention configuration
      - instant_restore_days: Days to keep instant restore snapshots (1-5, default: 5)
      - timezone: Timezone for backup schedule (default: 'UTC')
    
    Example:
      {
        standard = {
          name      = "daily-standard-backup"
          frequency = "Daily"
          time      = "23:00"
          retention_daily_count = 30
          retention_weekly = {
            count    = 12
            weekdays = ["Sunday"]
          }
          retention_monthly = {
            count    = 12
            weekdays = ["Sunday"]
            weeks    = ["First"]
          }
        }
      }
  EOT
  
  type = map(object({
    name                  = string
    frequency             = string
    time                  = string
    weekdays              = optional(list(string))
    retention_daily_count = optional(number)
    retention_weekly = optional(object({
      count    = number
      weekdays = list(string)
    }))
    retention_monthly = optional(object({
      count    = number
      weekdays = optional(list(string))
      weeks    = optional(list(string))
    }))
    retention_yearly = optional(object({
      count    = number
      weekdays = optional(list(string))
      weeks    = optional(list(string))
      months   = list(string)
    }))
    instant_restore_days = optional(number, 5)
    timezone             = optional(string, "UTC")
  }))
  
  validation {
    condition = alltrue([
      for k, v in var.backup_policies : contains(["Daily", "Weekly"], v.frequency)
    ])
    error_message = "Backup frequency must be 'Daily' or 'Weekly'."
  }
}

variable "protected_vms" {
  description = <<-EOT
    Map of VMs to protect with backup. Each VM requires:
    
    Required:
      - vm_id: Azure resource ID of the VM
      - policy_name: Name of the backup policy to apply (must match a key in backup_policies)
    
    Example:
      {
        web01 = {
          vm_id       = azurerm_linux_virtual_machine.web01.id
          policy_name = "standard"
        }
      }
  EOT
  
  type = map(object({
    vm_id       = string
    policy_name = string
  }))
  default = {}
}

#=============================================================================
# OPTIONAL VARIABLES
#=============================================================================

variable "vault_sku" {
  description = "SKU for Recovery Services Vault: 'Standard' or 'RS0' (Azure Site Recovery)"
  type        = string
  default     = "Standard"
  
  validation {
    condition     = contains(["Standard", "RS0"], var.vault_sku)
    error_message = "Vault SKU must be 'Standard' or 'RS0'."
  }
}

variable "storage_mode_type" {
  description = "Storage redundancy for vault: 'GeoRedundant', 'LocallyRedundant', or 'ZoneRedundant'"
  type        = string
  default     = "GeoRedundant"
  
  validation {
    condition     = contains(["GeoRedundant", "LocallyRedundant", "ZoneRedundant"], var.storage_mode_type)
    error_message = "Storage mode must be 'GeoRedundant', 'LocallyRedundant', or 'ZoneRedundant'."
  }
}

variable "enable_cross_region_restore" {
  description = "Enable cross-region restore capability (requires GeoRedundant storage)"
  type        = bool
  default     = false
}

variable "enable_soft_delete" {
  description = "Enable soft delete for backup data (recommended for production)"
  type        = bool
  default     = true
}

variable "encryption_key_id" {
  description = "Azure Key Vault key ID for customer-managed key encryption (optional)"
  type        = string
  default     = null
}

variable "enable_infrastructure_encryption" {
  description = "Enable infrastructure encryption (double encryption) for backup data"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to backup resources"
  type        = map(string)
  default     = {}
}
