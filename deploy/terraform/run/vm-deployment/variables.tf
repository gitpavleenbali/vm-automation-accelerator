###############################################################################
# Run VM Deployment - Variables
# Virtual machine deployment configuration
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
  description = "Environment name (dev, uat, prod, shared)"
  type        = string
  
  validation {
    condition     = can(regex("^(dev|development|uat|test|prod|production|shared)$", lower(var.environment)))
    error_message = "Environment must be one of: dev, uat, prod, shared"
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

variable "workload_name" {
  description = "Workload name (e.g., 'web', 'app', 'db')"
  type        = string
}

variable "instance_number" {
  description = "Instance number for naming (e.g., '01', '02')"
  type        = string
  default     = "01"
  
  validation {
    condition     = can(regex("^[0-9]{2}$", var.instance_number))
    error_message = "Instance number must be 2 digits (e.g., '01', '02')"
  }
}

# ============================================================================
# Control Plane Backend Configuration
# ============================================================================

variable "control_plane_subscription_id" {
  description = "Subscription ID where control plane is deployed"
  type        = string
}

variable "control_plane_resource_group" {
  description = "Resource group containing control plane"
  type        = string
}

variable "control_plane_storage_account" {
  description = "Storage account for Terraform state"
  type        = string
}

variable "control_plane_container_name" {
  description = "Container name for Terraform state"
  type        = string
  default     = "tfstate"
}

# ============================================================================
# Workload Zone Configuration
# ============================================================================

variable "workload_zone_subscription_id" {
  description = "Subscription ID where workload zone is deployed"
  type        = string
}

variable "workload_zone_resource_group" {
  description = "Resource group containing workload zone"
  type        = string
}

variable "workload_zone_key" {
  description = "State file key for workload zone"
  type        = string
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
# Linux Virtual Machine Configuration
# ============================================================================

variable "linux_vms" {
  description = "Configuration for Linux virtual machines"
  type = map(object({
    size                 = string
    zone                 = optional(string, null)
    admin_username       = optional(string, "azureuser")
    admin_password       = optional(string, null)
    disable_password_auth = optional(bool, true)
    ssh_public_key       = optional(string, null)
    source_image_reference = optional(object({
      publisher = string
      offer     = string
      sku       = string
      version   = string
    }), null)
    os_disk = optional(object({
      caching              = optional(string, "ReadWrite")
      storage_account_type = optional(string, "Premium_LRS")
      disk_size_gb         = optional(number, 128)
    }), {})
    data_disks = optional(list(object({
      name                 = string
      disk_size_gb         = number
      lun                  = number
      caching              = optional(string, "ReadWrite")
      storage_account_type = optional(string, "Premium_LRS")
    })), [])
    enable_accelerated_networking = optional(bool, true)
    enable_boot_diagnostics      = optional(bool, true)
    subnet_key                   = string
  }))
  default = {}
}

# ============================================================================
# Windows Virtual Machine Configuration
# ============================================================================

variable "windows_vms" {
  description = "Configuration for Windows virtual machines"
  type = map(object({
    size           = string
    zone           = optional(string, null)
    admin_username = optional(string, "azureadmin")
    admin_password = string
    source_image_reference = optional(object({
      publisher = string
      offer     = string
      sku       = string
      version   = string
    }), null)
    os_disk = optional(object({
      caching              = optional(string, "ReadWrite")
      storage_account_type = optional(string, "Premium_LRS")
      disk_size_gb         = optional(number, 128)
    }), {})
    data_disks = optional(list(object({
      name                 = string
      disk_size_gb         = number
      lun                  = number
      caching              = optional(string, "ReadWrite")
      storage_account_type = optional(string, "Premium_LRS")
    })), [])
    enable_accelerated_networking = optional(bool, true)
    enable_boot_diagnostics      = optional(bool, true)
    subnet_key                   = string
    license_type                 = optional(string, null)
  }))
  default = {}
}

# ============================================================================
# Availability Configuration
# ============================================================================

variable "enable_availability_set" {
  description = "Create availability set for VMs"
  type        = bool
  default     = false
}

variable "availability_set_config" {
  description = "Availability set configuration"
  type = object({
    platform_fault_domain_count  = optional(number, 2)
    platform_update_domain_count = optional(number, 5)
    managed                      = optional(bool, true)
  })
  default = {
    platform_fault_domain_count  = 2
    platform_update_domain_count = 5
    managed                      = true
  }
}

variable "enable_proximity_placement_group" {
  description = "Create proximity placement group for VMs"
  type        = bool
  default     = false
}

# ============================================================================
# Load Balancer Configuration
# ============================================================================

variable "enable_load_balancer" {
  description = "Create load balancer for VMs"
  type        = bool
  default     = false
}

variable "load_balancer_config" {
  description = "Load balancer configuration"
  type = object({
    type                = optional(string, "internal") # internal or public
    sku                 = optional(string, "Standard")
    frontend_subnet_key = optional(string, null)
    backend_vms         = optional(list(string), [])
    probes = optional(list(object({
      name     = string
      protocol = string
      port     = number
      path     = optional(string, "/")
    })), [])
    rules = optional(list(object({
      name                = string
      protocol            = string
      frontend_port       = number
      backend_port        = number
      probe_name          = string
      enable_floating_ip  = optional(bool, false)
      idle_timeout        = optional(number, 4)
    })), [])
  })
  default = null
}

# ============================================================================
# Public IP Configuration
# ============================================================================

variable "enable_public_ips" {
  description = "Create public IPs for VMs"
  type        = bool
  default     = false
}

variable "public_ip_sku" {
  description = "SKU for public IPs (Basic or Standard)"
  type        = string
  default     = "Standard"
  
  validation {
    condition     = contains(["Basic", "Standard"], var.public_ip_sku)
    error_message = "Public IP SKU must be Basic or Standard"
  }
}

# ============================================================================
# Backup Configuration
# ============================================================================

variable "enable_backup" {
  description = "Enable Azure Backup for VMs"
  type        = bool
  default     = false
}

variable "backup_policy_config" {
  description = "Backup policy configuration"
  type = object({
    frequency = optional(string, "Daily")
    time      = optional(string, "23:00")
    retention_daily_count   = optional(number, 30)
    retention_weekly_count  = optional(number, 12)
    retention_monthly_count = optional(number, 12)
    retention_yearly_count  = optional(number, 5)
  })
  default = {
    frequency = "Daily"
    time      = "23:00"
    retention_daily_count = 30
  }
}

# ============================================================================
# Disk Encryption Configuration
# ============================================================================

variable "enable_disk_encryption" {
  description = "Enable Azure Disk Encryption for VMs"
  type        = bool
  default     = false
}

variable "disk_encryption_key_vault_id" {
  description = "Key Vault ID for disk encryption keys"
  type        = string
  default     = null
}

# ============================================================================
# Monitoring Configuration
# ============================================================================

variable "enable_monitoring" {
  description = "Enable Azure Monitor for VMs"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for monitoring"
  type        = string
  default     = null
}

variable "enable_azure_defender" {
  description = "Enable Azure Defender for VMs"
  type        = bool
  default     = false
}

# ============================================================================
# Network Configuration
# ============================================================================

variable "enable_private_ip_allocation" {
  description = "Use static private IP allocation"
  type        = bool
  default     = false
}

variable "private_ip_addresses" {
  description = "Map of VM names to static private IP addresses"
  type        = map(string)
  default     = {}
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

# ============================================================================
# Authentication Variables (for Azure DevOps Pipeline Support)
# ============================================================================

variable "arm_client_id" {
  description = "Azure Client ID for Service Principal authentication (pipeline mode)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "arm_client_secret" {
  description = "Azure Client Secret for Service Principal authentication (pipeline mode)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "arm_tenant_id" {
  description = "Azure Tenant ID for Service Principal authentication (pipeline mode)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "arm_subscription_id" {
  description = "Azure Subscription ID for authentication (pipeline mode)"
  type        = string
  default     = ""
  sensitive   = true
}
