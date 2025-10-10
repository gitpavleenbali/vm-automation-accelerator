###############################################################################
# Bootstrap Control Plane - Variables
# Initial deployment with local state backend
###############################################################################

variable "environment" {
  description = "Environment name (typically 'mgmt' for control plane)"
  type        = string
  default     = "mgmt"
}

variable "location" {
  description = "Azure region for control plane deployment"
  type        = string
}

variable "project_code" {
  description = "Project code or identifier"
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID for control plane"
  type        = string
  default     = ""
}

variable "resource_group_name" {
  description = "Resource group name (leave empty for auto-generation)"
  type        = string
  default     = ""
}

variable "create_resource_group" {
  description = "Whether to create a new resource group"
  type        = bool
  default     = true
}

variable "tfstate_storage_account_tier" {
  description = "Storage account tier for Terraform state"
  type        = string
  default     = "Standard"
  validation {
    condition     = contains(["Standard", "Premium"], var.tfstate_storage_account_tier)
    error_message = "Storage account tier must be Standard or Premium."
  }
}

variable "tfstate_storage_replication_type" {
  description = "Storage account replication type for Terraform state"
  type        = string
  default     = "LRS"
  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.tfstate_storage_replication_type)
    error_message = "Invalid replication type."
  }
}

variable "tfstate_container_name" {
  description = "Container name for Terraform state files"
  type        = string
  default     = "tfstate"
}

variable "create_key_vault" {
  description = "Whether to create a Key Vault for secrets"
  type        = bool
  default     = true
}

variable "key_vault_sku" {
  description = "Key Vault SKU"
  type        = string
  default     = "standard"
  validation {
    condition     = contains(["standard", "premium"], var.key_vault_sku)
    error_message = "Key Vault SKU must be standard or premium."
  }
}

variable "enable_purge_protection" {
  description = "Enable purge protection on Key Vault"
  type        = bool
  default     = true
}

variable "enable_soft_delete" {
  description = "Enable soft delete on Key Vault"
  type        = bool
  default     = true
}

variable "soft_delete_retention_days" {
  description = "Number of days to retain soft deleted secrets"
  type        = number
  default     = 7
  validation {
    condition     = var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 90
    error_message = "Soft delete retention must be between 7 and 90 days."
  }
}

variable "allowed_ip_ranges" {
  description = "Allowed IP ranges for Key Vault firewall"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "random_id" {
  description = "Random ID for globally unique resource names (auto-generated if empty)"
  type        = string
  default     = ""
}
