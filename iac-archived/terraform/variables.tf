# Terraform Variables for VM Deployment
# All variables include validation rules for production safety

# ===========================
# Environment Configuration
# ===========================

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be dev, test, or prod."
  }
}

variable "location_short" {
  description = "Short location code (e.g., weu for West Europe)"
  type        = string
  default     = "weu"
}

variable "instance_id" {
  description = "Instance number for resource naming (001-999)"
  type        = number
  default     = 1
  
  validation {
    condition     = var.instance_id >= 1 && var.instance_id <= 999
    error_message = "Instance ID must be between 1 and 999."
  }
}

# ===========================
# Resource Group Configuration
# ===========================

variable "resource_group_name" {
  description = "Name of the existing resource group for VM deployment"
  type        = string
}

# ===========================
# Virtual Machine Configuration
# ===========================

variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9-]{3,64}$", var.vm_name))
    error_message = "VM name must be 3-64 characters, lowercase alphanumeric and hyphens only."
  }
}

variable "vm_size" {
  description = "Azure VM size (e.g., Standard_D4s_v3)"
  type        = string
  
  validation {
    condition     = can(regex("^Standard_[A-Z][0-9]+[a-z]*s?_v[0-9]+$", var.vm_size))
    error_message = "VM size must match Azure SKU naming convention."
  }
}

variable "os_type" {
  description = "Operating system type (Windows or Linux)"
  type        = string
  
  validation {
    condition     = contains(["Windows", "Linux"], var.os_type)
    error_message = "OS type must be Windows or Linux."
  }
}

variable "use_custom_image" {
  description = "Use custom image instead of marketplace image"
  type        = bool
  default     = false
}

variable "source_image_id" {
  description = "Resource ID of custom image (if use_custom_image is true)"
  type        = string
  default     = null
}

variable "publisher" {
  description = "Image publisher (for marketplace images)"
  type        = string
  default     = "MicrosoftWindowsServer"
}

variable "offer" {
  description = "Image offer (for marketplace images)"
  type        = string
  default     = "WindowsServer"
}

variable "sku" {
  description = "Image SKU (for marketplace images)"
  type        = string
  default     = "2022-datacenter-azure-edition"
}

variable "image_version" {
  description = "Image version (for marketplace images)"
  type        = string
  default     = "latest"
}

# ===========================
# Disk Configuration
# ===========================

variable "os_disk_size_gb" {
  description = "OS disk size in GB (default: 127 GB)"
  type        = number
  default     = 127
  
  validation {
    condition     = var.os_disk_size_gb >= 30 && var.os_disk_size_gb <= 4096
    error_message = "OS disk size must be between 30 GB and 4096 GB."
  }
}

variable "os_disk_storage_type" {
  description = "OS disk storage type (Standard_LRS, StandardSSD_LRS, Premium_LRS, Premium_ZRS)"
  type        = string
  default     = "Premium_LRS"
  
  validation {
    condition     = contains(["Standard_LRS", "StandardSSD_LRS", "Premium_LRS", "Premium_ZRS"], var.os_disk_storage_type)
    error_message = "Invalid storage type."
  }
}

variable "os_disk_caching" {
  description = "OS disk caching mode (None, ReadOnly, ReadWrite)"
  type        = string
  default     = "ReadWrite"
  
  validation {
    condition     = contains(["None", "ReadOnly", "ReadWrite"], var.os_disk_caching)
    error_message = "Invalid caching mode."
  }
}

variable "data_disks" {
  description = "List of data disks to attach"
  type = list(object({
    name         = string
    size_gb      = number
    storage_type = string
    caching      = string
    lun          = number
  }))
  default = []
}

# ===========================
# Network Configuration
# ===========================

variable "vnet_name" {
  description = "Name of the existing virtual network"
  type        = string
}

variable "subnet_name" {
  description = "Name of the existing subnet"
  type        = string
}

variable "network_resource_group_name" {
  description = "Resource group containing the virtual network"
  type        = string
}

variable "private_ip_address_allocation" {
  description = "IP address allocation method (Dynamic or Static)"
  type        = string
  default     = "Dynamic"
  
  validation {
    condition     = contains(["Dynamic", "Static"], var.private_ip_address_allocation)
    error_message = "Allocation must be Dynamic or Static."
  }
}

variable "private_ip_address" {
  description = "Static private IP address (if allocation is Static)"
  type        = string
  default     = null
}

variable "enable_public_ip" {
  description = "Enable public IP address"
  type        = bool
  default     = false
}

variable "enable_accelerated_networking" {
  description = "Enable accelerated networking"
  type        = bool
  default     = true
}

variable "enable_ip_forwarding" {
  description = "Enable IP forwarding"
  type        = bool
  default     = false
}

variable "enable_ad_dns_rules" {
  description = "Enable NSG rules for Active Directory and DNS (ports 88, 389, 636, 3268, 3269, 53)"
  type        = bool
  default     = true
}

variable "custom_nsg_rules" {
  description = "Custom NSG rules"
  type = list(object({
    name                       = string
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = string
    destination_address_prefix = string
  }))
  default = []
}

# ===========================
# Authentication Configuration (AVM Pattern)
# ===========================

variable "account_credentials" {
  description = <<DESCRIPTION
AVM-compliant account credentials configuration supporting auto-generation and Key Vault storage.
This is the recommended pattern replacing legacy admin_username/admin_password variables.

- admin_credentials (Optional): Credential specification
  - username (Required): Admin username for the VM
  - password (Optional): Admin password. If null and generate enabled, will be auto-generated
  - ssh_keys (Optional): List of SSH public keys for Linux VMs
  - generate_admin_password_or_ssh_key (Optional): Auto-generate credentials. Default: true
  - disable_password_authentication (Optional): Linux only - disable password auth. Default: false

- key_vault_configuration (Optional): Key Vault for credential storage
  - resource_id (Required): Resource ID of Key Vault for credential storage
  - secret_expiration_date (Optional): ISO 8601 expiration date for secrets

Example:
account_credentials = {
  admin_credentials = {
    username = "azureadmin"
    generate_admin_password_or_ssh_key = true
  }
  key_vault_configuration = {
    resource_id = "/subscriptions/.../providers/Microsoft.KeyVault/vaults/kv-prod"
  }
}
DESCRIPTION
  type = object({
    admin_credentials = optional(object({
      username                           = string
      password                           = optional(string, null)
      ssh_keys                           = optional(list(string), [])
      generate_admin_password_or_ssh_key = optional(bool, true)
      disable_password_authentication    = optional(bool, false)
    }), null)
    key_vault_configuration = optional(object({
      resource_id            = string
      secret_expiration_date = optional(string, null)
    }), null)
  })
  default = null
  
  validation {
    condition     = var.account_credentials == null || can(regex("^[a-z][a-z0-9-]{2,19}$", var.account_credentials.admin_credentials.username))
    error_message = "Username must start with a letter, contain only lowercase letters, numbers, or hyphens, and be 3-20 characters long."
  }
}

# DEPRECATED: Backward compatibility - use account_credentials instead
variable "admin_username" {
  description = "DEPRECATED: Use account_credentials.admin_credentials.username instead. VM administrator username"
  type        = string
  default     = "azureadmin"
  
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.admin_username))
    error_message = "Username must be 3-20 characters, start with letter, lowercase alphanumeric and hyphens."
  }
}

# DEPRECATED: Backward compatibility - use account_credentials instead
variable "admin_password" {
  description = "DEPRECATED: Use account_credentials.admin_credentials.password instead. VM administrator password (if null, random password generated)"
  type        = string
  default     = null
  sensitive   = true
}

# DEPRECATED: Backward compatibility - use account_credentials instead
variable "ssh_public_key" {
  description = "DEPRECATED: Use account_credentials.admin_credentials.ssh_keys instead. SSH public key for Linux VMs"
  type        = string
  default     = null
}

variable "key_vault_name" {
  description = "Name of Key Vault to store secrets"
  type        = string
}

variable "key_vault_resource_group_name" {
  description = "Resource group containing Key Vault"
  type        = string
}

# ===========================
# Security Configuration
# ===========================

variable "enable_boot_diagnostics" {
  description = "Enable boot diagnostics"
  type        = bool
  default     = true
}

variable "boot_diagnostics_storage_uri" {
  description = "Storage account URI for boot diagnostics"
  type        = string
  default     = null
}

variable "enable_secure_boot" {
  description = "Enable Secure Boot (Trusted Launch)"
  type        = bool
  default     = true
}

variable "enable_vtpm" {
  description = "Enable vTPM (Trusted Launch)"
  type        = bool
  default     = true
}

variable "availability_zone" {
  description = "Availability zone (1, 2, or 3)"
  type        = string
  default     = null
}

# ===========================
# Security and Encryption (AVM Best Practices)
# ===========================

variable "encryption_at_host_enabled" {
  description = "Enable encryption at host for all disks (OS, temp, data). AVM best practice default: true"
  type        = bool
  default     = true
}

variable "disk_encryption_set_id" {
  description = "Azure Resource ID of Disk Encryption Set for customer-managed key encryption (optional)"
  type        = string
  default     = null
}

# ===========================
# Managed Identity and RBAC (AVM Pattern)
# ===========================

variable "enable_system_assigned_identity" {
  description = "Enable system-assigned managed identity"
  type        = bool
  default     = true
}

variable "user_assigned_identity_ids" {
  description = "Set of user-assigned managed identity resource IDs"
  type        = set(string)
  default     = []
}

variable "role_assignments" {
  description = <<ROLE_ASSIGNMENTS
Role assignments TO the VM resource scope. Assigns permissions to users, groups, or service principals ON this VM.

Example:
role_assignments = {
  contributor_assignment = {
    principal_id               = "00000000-0000-0000-0000-000000000000"
    role_definition_id_or_name = "Virtual Machine Contributor"
    description                = "Grant VM Contributor access"
    principal_type             = "ServicePrincipal"  # Required for Service Principals with ABAC policies
  }
}
ROLE_ASSIGNMENTS
  type = map(object({
    role_definition_id_or_name             = string
    principal_id                           = string
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
    description                            = optional(string, null)
    principal_type                         = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
  }))
  default = {}
}

variable "role_assignments_system_managed_identity" {
  description = <<ROLE_ASSIGNMENTS_SMI
Role assignments FROM the VM's system managed identity TO external resource scopes.
Grants the VM's managed identity permissions on other Azure resources (e.g., Key Vault, Storage).

Example:
role_assignments_system_managed_identity = {
  keyvault_secrets_user = {
    scope_resource_id          = "/subscriptions/.../resourceGroups/.../providers/Microsoft.KeyVault/vaults/myvault"
    role_definition_id_or_name = "Key Vault Secrets User"
    description                = "Allow VM to read Key Vault secrets"
    principal_type             = "ServicePrincipal"
  }
}
ROLE_ASSIGNMENTS_SMI
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

# ===========================
# Domain Join Configuration
# ===========================

variable "enable_domain_join" {
  description = "Enable domain join for Windows VMs"
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "Active Directory domain name"
  type        = string
  default     = ""
}

variable "domain_ou_path" {
  description = "OU path for domain join"
  type        = string
  default     = ""
}

variable "domain_join_account" {
  description = "Domain join service account"
  type        = string
  default     = ""
  sensitive   = true
}

variable "domain_join_password" {
  description = "Domain join service account password"
  type        = string
  default     = ""
  sensitive   = true
}

# ===========================
# Monitoring Configuration
# ===========================

# Diagnostic Settings (AVM Pattern) - Multi-destination support
variable "diagnostic_settings" {
  description = "AVM diagnostic settings supporting Log Analytics, Storage, and Event Hub simultaneously"
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

variable "enable_nic_diagnostics" {
  description = "Enable diagnostic settings on network interface"
  type        = bool
  default     = false
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see https://aka.ms/avm/telemetryinfo.
If it is set to false, then no telemetry will be collected.

Telemetry helps Microsoft understand module usage patterns and improve Azure Verified Modules.
No sensitive or customer data is collected - only module source, version, and deployment metadata.

Customers can opt-out by setting this to false.
DESCRIPTION
  nullable    = false
}

variable "log_analytics_workspace_name" {
  description = "Name of Log Analytics workspace"
  type        = string
}

variable "log_analytics_resource_group_name" {
  description = "Resource group containing Log Analytics workspace"
  type        = string
}

variable "enable_performance_monitoring" {
  description = "Enable performance counter collection"
  type        = bool
  default     = true
}

variable "enable_event_log_collection" {
  description = "Enable Windows event log collection"
  type        = bool
  default     = true
}

variable "enable_vm_insights" {
  description = "Enable VM Insights"
  type        = bool
  default     = true
}

# ===========================
# Backup Configuration
# ===========================

variable "enable_backup" {
  description = "Enable Azure Backup"
  type        = bool
  default     = true
}

variable "recovery_vault_name" {
  description = "Name of Recovery Services Vault"
  type        = string
  default     = ""
}

variable "recovery_vault_resource_group_name" {
  description = "Resource group containing Recovery Services Vault"
  type        = string
  default     = ""
}

variable "backup_policy_id" {
  description = "Resource ID of backup policy"
  type        = string
  default     = ""
}

variable "backup_exclude_disk_luns" {
  description = "List of disk LUNs to exclude from backup. Only one of exclude or include can be set. AVM best practice for selective backup."
  type        = list(number)
  default     = []
  
  validation {
    condition     = length(var.backup_exclude_disk_luns) == 0 || length(var.backup_include_disk_luns) == 0
    error_message = "Only one of backup_exclude_disk_luns or backup_include_disk_luns can be specified, not both."
  }
}

variable "backup_include_disk_luns" {
  description = "List of disk LUNs to include in backup. Only one of exclude or include can be set. AVM best practice for selective backup."
  type        = list(number)
  default     = []
  
  validation {
    condition     = length(var.backup_exclude_disk_luns) == 0 || length(var.backup_include_disk_luns) == 0
    error_message = "Only one of backup_exclude_disk_luns or backup_include_disk_luns can be specified, not both."
  }
}

# ===========================
# Site Recovery Configuration
# ===========================

variable "enable_asr" {
  description = "Enable Azure Site Recovery"
  type        = bool
  default     = false
}

variable "asr_target_resource_group_name" {
  description = "Target resource group for ASR"
  type        = string
  default     = ""
}

variable "asr_target_location" {
  description = "Target location for ASR"
  type        = string
  default     = ""
}

variable "asr_recovery_vault_name" {
  description = "Recovery Services Vault for ASR"
  type        = string
  default     = ""
}

variable "asr_recovery_vault_resource_group" {
  description = "Resource group for ASR Recovery Vault"
  type        = string
  default     = ""
}

variable "asr_replication_policy_name" {
  description = "ASR replication policy name"
  type        = string
  default     = ""
}

# ===========================
# Hardening Configuration
# ===========================

variable "hardening_script_url" {
  description = "URL to hardening script"
  type        = string
  default     = ""
}

variable "hardening_script_name" {
  description = "Hardening script filename"
  type        = string
  default     = "Apply-Your OrganizationHardening.ps1"
}

variable "hardening_script_args" {
  description = "Arguments for hardening script"
  type        = string
  default     = ""
}

variable "scripts_storage_account_name" {
  description = "Storage account containing scripts"
  type        = string
  default     = ""
}

variable "scripts_storage_account_key" {
  description = "Storage account key for script access"
  type        = string
  default     = ""
  sensitive   = true
}

# ===========================
# Tags
# ===========================

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
