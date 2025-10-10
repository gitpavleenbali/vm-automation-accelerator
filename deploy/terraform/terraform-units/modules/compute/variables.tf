#=============================================================================
# REQUIRED VARIABLES
#=============================================================================

variable "resource_group_name" {
  description = "Name of the resource group where VMs will be deployed"
  type        = string
}

variable "location" {
  description = "Azure region where VMs will be deployed"
  type        = string
}

variable "vms" {
  description = <<-EOT
    Map of virtual machines to create. Each VM can have the following properties:
    
    Required:
      - vm_name: Name of the virtual machine
      - subnet_id: ID of the subnet where the VM will be connected
      
    Optional:
      - os_type: "linux" or "windows" (default: "linux")
      - vm_size: Azure VM size (default: "Standard_D2s_v3")
      - admin_username: Admin username (default: "azureuser" for Linux, "azureadmin" for Windows)
      - admin_password: Admin password (required for Windows, optional for Linux if SSH key provided)
      - ssh_public_key: SSH public key for Linux VMs (default: null)
      - enable_public_ip: Enable public IP address (default: false)
      - enable_accelerated_networking: Enable accelerated networking (default: true)
      - private_ip_address: Static private IP address (default: null for dynamic)
      - os_disk_size_gb: OS disk size in GB (default: 128)
      - os_disk_type: OS disk type - Standard_LRS, Premium_LRS, StandardSSD_LRS (default: "Premium_LRS")
      - os_disk_caching: OS disk caching - None, ReadOnly, ReadWrite (default: "ReadWrite")
      - data_disks: Map of data disks (see below)
      - availability_set_name: Name of availability set to join (default: null)
      - proximity_placement_group_name: Name of proximity placement group (default: null)
      - zone: Availability zone (default: null)
      - source_image_reference: Custom image reference (default: Ubuntu 22.04 for Linux, Windows Server 2022 for Windows)
      - tags: Additional tags for this specific VM (merged with var.tags)
      
      AVM Security Features:
      - managed_identities: Managed identity configuration (see AVM pattern below)
      - encryption_at_host_enabled: Enable encryption at host for all disks (default: true)
      - disk_encryption_set_id: Customer-managed key encryption set ID (default: null)
      - enable_secure_boot: Enable Secure Boot for Trusted Launch (default: false)
      - enable_vtpm: Enable vTPM for Trusted Launch (default: false)
      - enable_boot_diagnostics: Enable boot diagnostics (default: true)
      - boot_diagnostics_storage_uri: Boot diagnostics storage URI (default: null for managed storage)
    
    Data disk properties:
      - name: Name of the managed disk (default: "{vm_name}-disk-{key}")
      - size_gb: Disk size in GB (default: 128)
      - type: Disk type - Standard_LRS, Premium_LRS, StandardSSD_LRS (default: "Premium_LRS")
      - caching: Disk caching - None, ReadOnly, ReadWrite (default: "ReadWrite")
      - lun: Logical Unit Number (default: disk index)
      - create_option: Create option - Empty, FromImage (default: "Empty")
    
    Managed Identity (AVM Pattern):
      - system_assigned: Enable system-assigned managed identity (default: false)
      - user_assigned_resource_ids: Set of user-assigned managed identity resource IDs (default: [])
    
    Example:
      vms = {
        web01 = {
          vm_name        = "vm-web01"
          os_type        = "linux"
          vm_size        = "Standard_D2s_v3"
          subnet_id      = azurerm_subnet.web.id
          admin_username = "azureuser"
          ssh_public_key = file("~/.ssh/id_rsa.pub")
          availability_set_name = "avset-web"
          
          # AVM Security Features
          managed_identities = {
            system_assigned            = true
            user_assigned_resource_ids = []
          }
          encryption_at_host_enabled = true
          enable_secure_boot         = true
          enable_vtpm                = true
          
          data_disks = {
            data01 = { size_gb = 256, type = "Premium_LRS" }
            data02 = { size_gb = 512, type = "Premium_LRS" }
          }
        }
      }
  EOT
  type = map(object({
    vm_name                        = string
    subnet_id                      = string
    os_type                        = optional(string, "linux")
    vm_size                        = optional(string, "Standard_D2s_v3")
    admin_username                 = optional(string)
    admin_password                 = optional(string)
    ssh_public_key                 = optional(string)
    enable_public_ip               = optional(bool, false)
    enable_accelerated_networking  = optional(bool, true)
    private_ip_address             = optional(string)
    os_disk_size_gb                = optional(number, 128)
    os_disk_type                   = optional(string, "Premium_LRS")
    os_disk_caching                = optional(string, "ReadWrite")
    data_disks                     = optional(map(object({
      name          = optional(string)
      size_gb       = optional(number, 128)
      type          = optional(string, "Premium_LRS")
      caching       = optional(string, "ReadWrite")
      lun           = optional(number)
      create_option = optional(string, "Empty")
    })), {})
    availability_set_name          = optional(string)
    proximity_placement_group_name = optional(string)
    zone                           = optional(string)
    source_image_reference         = optional(object({
      publisher = string
      offer     = string
      sku       = string
      version   = string
    }))
    tags                           = optional(map(string), {})
    
    # AVM Security Features
    managed_identities = optional(object({
      system_assigned            = optional(bool, false)
      user_assigned_resource_ids = optional(set(string), [])
    }), {
      system_assigned            = false
      user_assigned_resource_ids = []
    })
    encryption_at_host_enabled = optional(bool, true)
    disk_encryption_set_id     = optional(string)
    enable_secure_boot         = optional(bool, false)
    enable_vtpm                = optional(bool, false)
    enable_boot_diagnostics    = optional(bool, true)
    boot_diagnostics_storage_uri = optional(string)
  }))
}

#=============================================================================
# OPTIONAL VARIABLES
#=============================================================================

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "availability_set_fault_domains" {
  description = "Number of fault domains for availability sets"
  type        = number
  default     = 2
  
  validation {
    condition     = var.availability_set_fault_domains >= 1 && var.availability_set_fault_domains <= 3
    error_message = "Fault domains must be between 1 and 3."
  }
}

variable "availability_set_update_domains" {
  description = "Number of update domains for availability sets"
  type        = number
  default     = 5
  
  validation {
    condition     = var.availability_set_update_domains >= 1 && var.availability_set_update_domains <= 20
    error_message = "Update domains must be between 1 and 20."
  }
}
