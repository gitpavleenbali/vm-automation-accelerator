# Variables for Governance Module

variable "assign_to_subscription" {
  description = "Whether to assign the policy initiative to the subscription"
  type        = bool
  default     = true
}

variable "location" {
  description = "Azure region for the policy assignment identity"
  type        = string
  default     = "eastus"
}

variable "encryption_effect" {
  description = "Effect for encryption at host policy"
  type        = string
  default     = "Audit"
  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.encryption_effect)
    error_message = "Effect must be Audit, Deny, or Disabled"
  }
}

variable "tags_effect" {
  description = "Effect for mandatory tags policy"
  type        = string
  default     = "Audit"
  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.tags_effect)
    error_message = "Effect must be Audit, Deny, or Disabled"
  }
}

variable "naming_effect" {
  description = "Effect for naming convention policy"
  type        = string
  default     = "Audit"
  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.naming_effect)
    error_message = "Effect must be Audit, Deny, or Disabled"
  }
}

variable "naming_pattern" {
  description = "Regular expression pattern for VM naming convention"
  type        = string
  default     = "^(dev|uat|prod)-vm-[a-z0-9]+-[a-z]+-[0-9]{3}$"
}

variable "backup_effect" {
  description = "Effect for Azure Backup policy"
  type        = string
  default     = "Audit"
  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.backup_effect)
    error_message = "Effect must be Audit, Deny, or Disabled"
  }
}

variable "sku_effect" {
  description = "Effect for VM SKU restriction policy"
  type        = string
  default     = "Audit"
  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.sku_effect)
    error_message = "Effect must be Audit, Deny, or Disabled"
  }
}

variable "allowed_skus" {
  description = "List of allowed VM SKU sizes"
  type        = list(string)
  default = [
    "Standard_B2s",
    "Standard_B2ms",
    "Standard_D2s_v3",
    "Standard_D4s_v3",
    "Standard_D8s_v3",
    "Standard_E2s_v3",
    "Standard_E4s_v3",
    "Standard_F2s_v2",
    "Standard_F4s_v2"
  ]
}
