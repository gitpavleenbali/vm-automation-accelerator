# Compute Module Variables

variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "vm_size" {
  description = "VM size"
  type        = string
}

variable "os_type" {
  description = "OS type (Windows or Linux)"
  type        = string
}

variable "admin_username" {
  description = "Admin username"
  type        = string
}

variable "admin_password" {
  description = "Admin password (Windows only)"
  type        = string
  default     = null
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key (Linux only)"
  type        = string
  default     = null
}

variable "network_interface_ids" {
  description = "List of network interface IDs"
  type        = list(string)
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB"
  type        = number
}

variable "os_disk_storage_type" {
  description = "OS disk storage type"
  type        = string
}

variable "os_disk_caching" {
  description = "OS disk caching"
  type        = string
}

variable "data_disks" {
  description = "List of data disks"
  type = list(object({
    name         = string
    size_gb      = number
    storage_type = string
    caching      = string
    lun          = number
  }))
}

variable "use_custom_image" {
  description = "Use custom image"
  type        = bool
}

variable "source_image_id" {
  description = "Custom image resource ID"
  type        = string
  default     = null
}

variable "publisher" {
  description = "Image publisher"
  type        = string
  default     = null
}

variable "offer" {
  description = "Image offer"
  type        = string
  default     = null
}

variable "sku" {
  description = "Image SKU"
  type        = string
  default     = null
}

variable "image_version" {
  description = "Image version"
  type        = string
  default     = "latest"
}

# Security and Encryption (AVM Best Practices)
variable "encryption_at_host_enabled" {
  description = "Enable encryption at host for all disks (OS, temp, data). Recommended security best practice."
  type        = bool
  default     = true
}

variable "disk_encryption_set_id" {
  description = "Azure Resource ID of Disk Encryption Set for customer-managed key encryption (optional)"
  type        = string
  default     = null
}

# Managed Identity (AVM Pattern)
variable "managed_identities" {
  description = "Managed identity configuration following Azure Verified Module pattern"
  type = object({
    system_assigned            = optional(bool, false)
    user_assigned_resource_ids = optional(set(string), [])
  })
  default = {
    system_assigned            = true
    user_assigned_resource_ids = []
  }
}

variable "enable_boot_diagnostics" {
  description = "Enable boot diagnostics"
  type        = bool
}

variable "boot_diagnostics_storage_uri" {
  description = "Boot diagnostics storage URI"
  type        = string
  default     = null
}

variable "enable_secure_boot" {
  description = "Enable Secure Boot"
  type        = bool
}

variable "enable_vtpm" {
  description = "Enable vTPM"
  type        = bool
}

variable "availability_zone" {
  description = "Availability zone"
  type        = string
  default     = null
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
}

# ===================================================
# RBAC Role Assignments (AVM Pattern)
# ===================================================

variable "role_assignments" {
  description = "Role assignments TO the VM resource scope. Principal can be user, group, or service principal."
  type = map(object({
    role_definition_id_or_name             = string
    principal_id                           = string
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
    description                            = optional(string, null)
    principal_type                         = optional(string, null) # User, Group, ServicePrincipal - Required for ABAC
    skip_service_principal_aad_check       = optional(bool, false)
  }))
  default = {}
}

# Diagnostic Settings (AVM Pattern)
variable "diagnostic_settings" {
  description = "AVM diagnostic settings for VM supporting multiple destinations"
  type = map(object({
    name                                     = string
    log_analytics_workspace_resource_id      = optional(string, null)
    storage_account_resource_id              = optional(string, null)
    event_hub_authorization_rule_id          = optional(string, null)
    event_hub_name                           = optional(string, null)
    log_categories                           = optional(list(string), [])
    log_groups                               = optional(list(string), ["allLogs"])
    metric_categories                        = optional(list(string), ["AllMetrics"])
  }))
  default = {}
}

variable "role_assignments_system_managed_identity" {
  description = "Role assignments FROM the VM's system managed identity TO external resource scopes (e.g., Key Vault, Storage)"
  type = map(object({
    scope_resource_id                      = string
    role_definition_id_or_name             = string
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
    description                            = optional(string, null)
    principal_type                         = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
  }))
  default = {}
}
