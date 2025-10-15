###############################################################################
# Run Control Plane - Variables
# Production deployment with remote state
###############################################################################

# ============================================================================
# Authentication Variables (for Azure DevOps Service Principal)
# ============================================================================

variable "arm_client_id" {
  description = "Azure Service Principal Client ID (set via ARM_CLIENT_ID env var in pipeline)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "arm_client_secret" {
  description = "Azure Service Principal Client Secret (set via ARM_CLIENT_SECRET env var in pipeline)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "arm_tenant_id" {
  description = "Azure Tenant ID (set via ARM_TENANT_ID env var in pipeline)"
  type        = string
  default     = ""
  sensitive   = true
}

# ============================================================================
# Core Configuration Variables
# ============================================================================

variable "environment" {
  description = "Environment name (dev, uat, prod, mgmt, shared)"
  type        = string
  
  validation {
    condition     = can(regex("^(dev|development|uat|test|prod|production|mgmt|management|shared)$", lower(var.environment)))
    error_message = "Environment must be one of: dev, uat, prod, mgmt, shared"
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "project_code" {
  description = "Project code for naming (3-8 alphanumeric characters)"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9]{3,8}$", lower(var.project_code)))
    error_message = "Project code must be 3-8 alphanumeric characters"
  }
}

# ============================================================================
# Subscription Configuration (Optional)
# ============================================================================

variable "subscription_id" {
  description = "Azure subscription ID (optional, uses current if not specified)"
  type        = string
  default     = ""
}

# ============================================================================
# Resource Group Configuration (Optional)
# ============================================================================

variable "resource_group_name" {
  description = "Name of existing resource group (optional, creates new if not specified)"
  type        = string
  default     = null
}

# ============================================================================
# State Storage Configuration (Optional)
# ============================================================================

variable "state_storage_account_tier" {
  description = "Storage account tier for Terraform state"
  type        = string
  default     = "Standard"
  
  validation {
    condition     = contains(["Standard", "Premium"], var.state_storage_account_tier)
    error_message = "Storage account tier must be Standard or Premium"
  }
}

variable "state_storage_account_replication" {
  description = "Storage account replication type"
  type        = string
  default     = "LRS"
  
  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.state_storage_account_replication)
    error_message = "Invalid replication type. Must be one of: LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS"
  }
}

variable "state_storage_container_name" {
  description = "Name of storage container for Terraform state"
  type        = string
  default     = "tfstate"
}

# ============================================================================
# Key Vault Configuration (Optional)
# ============================================================================

variable "key_vault_sku" {
  description = "Key Vault SKU"
  type        = string
  default     = "standard"
  
  validation {
    condition     = contains(["standard", "premium"], lower(var.key_vault_sku))
    error_message = "Key Vault SKU must be standard or premium"
  }
}

variable "key_vault_soft_delete_retention_days" {
  description = "Number of days to retain soft-deleted Key Vault (7-90)"
  type        = number
  default     = 7
  
  validation {
    condition     = var.key_vault_soft_delete_retention_days >= 7 && var.key_vault_soft_delete_retention_days <= 90
    error_message = "Soft delete retention must be between 7 and 90 days"
  }
}

variable "key_vault_enable_purge_protection" {
  description = "Enable purge protection for Key Vault (recommended for production)"
  type        = bool
  default     = true
}

variable "key_vault_enable_rbac_authorization" {
  description = "Enable RBAC authorization for Key Vault"
  type        = bool
  default     = true
}

variable "key_vault_network_default_action" {
  description = "Default network action for Key Vault (Allow or Deny)"
  type        = string
  default     = "Deny"
  
  validation {
    condition     = contains(["Allow", "Deny"], var.key_vault_network_default_action)
    error_message = "Network default action must be Allow or Deny"
  }
}

variable "key_vault_network_bypass" {
  description = "Network bypass for Key Vault (None or AzureServices)"
  type        = string
  default     = "AzureServices"
  
  validation {
    condition     = contains(["None", "AzureServices"], var.key_vault_network_bypass)
    error_message = "Network bypass must be None or AzureServices"
  }
}

variable "key_vault_allowed_ip_addresses" {
  description = "List of allowed IP addresses/CIDR ranges for Key Vault"
  type        = list(string)
  default     = []
}

variable "key_vault_subnet_ids" {
  description = "List of virtual network subnet IDs allowed to access Key Vault"
  type        = list(string)
  default     = []
}

# ============================================================================
# Deployment Metadata (Optional)
# ============================================================================

variable "automation_version" {
  description = "Version of the VM automation framework"
  type        = string
  default     = "1.0.0"
}

variable "deployed_by" {
  description = "Identity that deployed the infrastructure"
  type        = string
  default     = ""
}

variable "deployment_id" {
  description = "Unique deployment identifier"
  type        = string
  default     = ""
}

variable "enable_arm_deployment_tracking" {
  description = "Enable ARM deployment tracking for Azure Portal visibility"
  type        = bool
  default     = true
}

variable "random_id" {
  description = "Random ID for unique resource names (optional, generated if not provided)"
  type        = string
  default     = ""
}

# ============================================================================
# Tagging (Optional)
# ============================================================================

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_purge_protection" {
  description = "Enable purge protection for Key Vault"
  type        = bool
  default     = true
}

variable "enable_soft_delete" {
  description = "Enable soft delete for Key Vault"
  type        = bool
  default     = true
}

variable "create_resource_group" {
  description = "Create new resource group (true) or use existing (false)"
  type        = bool
  default     = true
}
