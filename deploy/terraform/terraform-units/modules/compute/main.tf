/**
 * Reusable Compute Module
 * 
 * Purpose:
 *   - Provides reusable patterns for deploying Azure Virtual Machines
 *   - Supports both Linux and Windows VMs
 *   - Handles availability sets, proximity placement groups, and data disks
 *   - Flexible configuration with smart defaults
 * 
 * Usage:
 *   module "web_vms" {
 *     source = "../../terraform-units/modules/compute"
 *     
 *     resource_group_name = azurerm_resource_group.main.name
 *     location            = azurerm_resource_group.main.location
 *     
 *     vms = {
 *       web01 = {
 *         vm_name        = "vm-web01"
 *         os_type        = "linux"
 *         vm_size        = "Standard_D2s_v3"
 *         subnet_id      = azurerm_subnet.web.id
 *         admin_username = "azureuser"
 *         ssh_public_key = file("~/.ssh/id_rsa.pub")
 *       }
 *     }
 *   }
 */

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

#=============================================================================
# TRANSFORM LAYER - Input Normalization
#=============================================================================

locals {
  # Normalize VM configurations
  normalized_vms = {
    for vm_key, vm_config in var.vms : vm_key => merge(
      {
        # Required fields
        vm_name        = vm_config.vm_name
        os_type        = lower(try(vm_config.os_type, "linux"))
        vm_size        = try(vm_config.vm_size, "Standard_D2s_v3")
        subnet_id      = vm_config.subnet_id
        
        # Authentication
        admin_username = try(vm_config.admin_username, local.default_admin_username[lower(try(vm_config.os_type, "linux"))])
        admin_password = try(vm_config.admin_password, null)
        ssh_public_key = lower(try(vm_config.os_type, "linux")) == "linux" ? try(vm_config.ssh_public_key, null) : null
        
        # Network
        enable_public_ip          = try(vm_config.enable_public_ip, false)
        enable_accelerated_networking = try(vm_config.enable_accelerated_networking, true)
        private_ip_address        = try(vm_config.private_ip_address, null)
        
        # OS Disk
        os_disk_size_gb         = try(vm_config.os_disk_size_gb, 128)
        os_disk_type            = try(vm_config.os_disk_type, "Premium_LRS")
        os_disk_caching         = try(vm_config.os_disk_caching, "ReadWrite")
        
        # Data Disks
        data_disks = try(vm_config.data_disks, {})
        
        # High Availability
        availability_set_name = try(vm_config.availability_set_name, null)
        proximity_placement_group_name = try(vm_config.proximity_placement_group_name, null)
        zone = try(vm_config.zone, null)
        
        # Image
        source_image_reference = try(vm_config.source_image_reference, local.default_images[lower(try(vm_config.os_type, "linux"))])
        
        # Tags
        tags = merge(
          var.tags,
          try(vm_config.tags, {})
        )
      }
    )
  }
  
  # Default admin usernames
  default_admin_username = {
    linux   = "azureuser"
    windows = "azureadmin"
  }
  
  # Default OS images
  default_images = {
    linux = {
      publisher = "Canonical"
      offer     = "0001-com-ubuntu-server-jammy"
      sku       = "22_04-lts-gen2"
      version   = "latest"
    }
    windows = {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2022-datacenter-azure-edition"
      version   = "latest"
    }
  }
  
  # Flatten data disks for creation
  data_disks = flatten([
    for vm_key, vm_config in local.normalized_vms : [
      for disk_key, disk_config in vm_config.data_disks : {
        vm_key           = vm_key
        disk_key         = disk_key
        disk_name        = try(disk_config.name, "${vm_config.vm_name}-disk-${disk_key}")
        disk_size_gb     = try(disk_config.size_gb, 128)
        disk_type        = try(disk_config.type, "Premium_LRS")
        disk_caching     = try(disk_config.caching, "ReadWrite")
        lun              = try(disk_config.lun, index(keys(vm_config.data_disks), disk_key))
        create_option    = try(disk_config.create_option, "Empty")
      }
    ]
  ])
  
  # Unique availability sets
  availability_sets = distinct([
    for vm_key, vm_config in local.normalized_vms : vm_config.availability_set_name
    if vm_config.availability_set_name != null
  ])
  
  # Unique proximity placement groups
  proximity_placement_groups = distinct([
    for vm_key, vm_config in local.normalized_vms : vm_config.proximity_placement_group_name
    if vm_config.proximity_placement_group_name != null
  ])
  
  # VMs grouped by availability set
  vms_by_availability_set = {
    for avset in local.availability_sets : avset => [
      for vm_key, vm_config in local.normalized_vms : vm_key
      if vm_config.availability_set_name == avset
    ]
  }
}

#=============================================================================
# PROXIMITY PLACEMENT GROUPS
#=============================================================================

resource "azurerm_proximity_placement_group" "ppg" {
  for_each = toset(local.proximity_placement_groups)
  
  name                = each.value
  location            = var.location
  resource_group_name = var.resource_group_name
  
  tags = var.tags
}

#=============================================================================
# AVAILABILITY SETS
#=============================================================================

resource "azurerm_availability_set" "avset" {
  for_each = toset(local.availability_sets)
  
  name                         = each.value
  location                     = var.location
  resource_group_name          = var.resource_group_name
  platform_fault_domain_count  = var.availability_set_fault_domains
  platform_update_domain_count = var.availability_set_update_domains
  managed                      = true
  
  # Link to proximity placement group if any VM in this avset uses one
  proximity_placement_group_id = try(
    azurerm_proximity_placement_group.ppg[
      [for vm_key in local.vms_by_availability_set[each.value] : 
        local.normalized_vms[vm_key].proximity_placement_group_name
        if local.normalized_vms[vm_key].proximity_placement_group_name != null
      ][0]
    ].id,
    null
  )
  
  tags = var.tags
}

#=============================================================================
# PUBLIC IP ADDRESSES
#=============================================================================

resource "azurerm_public_ip" "vm_pip" {
  for_each = {
    for vm_key, vm_config in local.normalized_vms : vm_key => vm_config
    if vm_config.enable_public_ip
  }
  
  name                = "${each.value.vm_name}-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  
  tags = each.value.tags
}

#=============================================================================
# NETWORK INTERFACES
#=============================================================================

resource "azurerm_network_interface" "vm_nic" {
  for_each = local.normalized_vms
  
  name                           = "${each.value.vm_name}-nic"
  location                       = var.location
  resource_group_name            = var.resource_group_name
  accelerated_networking_enabled = each.value.enable_accelerated_networking
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = each.value.subnet_id
    private_ip_address_allocation = each.value.private_ip_address != null ? "Static" : "Dynamic"
    private_ip_address            = each.value.private_ip_address
    public_ip_address_id          = each.value.enable_public_ip ? azurerm_public_ip.vm_pip[each.key].id : null
  }
  
  tags = each.value.tags
}

#=============================================================================
# AVM PATTERN - Managed Identity Calculation
#=============================================================================

locals {
  # Calculate managed identity type following AVM best practices
  managed_identities = {
    for vm_key, vm_config in local.normalized_vms : vm_key => {
      type = coalesce(
        try(vm_config.managed_identities.system_assigned, false) && length(try(vm_config.managed_identities.user_assigned_resource_ids, [])) > 0 ? "SystemAssigned, UserAssigned" : null,
        try(vm_config.managed_identities.system_assigned, false) ? "SystemAssigned" : null,
        length(try(vm_config.managed_identities.user_assigned_resource_ids, [])) > 0 ? "UserAssigned" : null
      )
      user_assigned_resource_ids = try(vm_config.managed_identities.user_assigned_resource_ids, [])
    }
  }
}

#=============================================================================
# LINUX VIRTUAL MACHINES (Enhanced with AVM Patterns)
#=============================================================================

resource "azurerm_linux_virtual_machine" "linux_vm" {
  for_each = {
    for vm_key, vm_config in local.normalized_vms : vm_key => vm_config
    if vm_config.os_type == "linux"
  }
  
  name                = each.value.vm_name
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = each.value.vm_size
  
  admin_username = each.value.admin_username
  
  # SSH authentication
  disable_password_authentication = each.value.ssh_public_key != null
  
  dynamic "admin_ssh_key" {
    for_each = each.value.ssh_public_key != null ? [1] : []
    content {
      username   = each.value.admin_username
      public_key = each.value.ssh_public_key
    }
  }
  
  # Password authentication (if no SSH key)
  admin_password = each.value.ssh_public_key == null ? each.value.admin_password : null
  
  network_interface_ids = [
    azurerm_network_interface.vm_nic[each.key].id
  ]
  
  # High availability
  availability_set_id = each.value.availability_set_name != null ? azurerm_availability_set.avset[each.value.availability_set_name].id : null
  proximity_placement_group_id = each.value.proximity_placement_group_name != null ? azurerm_proximity_placement_group.ppg[each.value.proximity_placement_group_name].id : null
  zone = each.value.zone
  
  # AVM Pattern: Managed Identity Support
  dynamic "identity" {
    for_each = local.managed_identities[each.key].type != null ? [1] : []
    content {
      type         = local.managed_identities[each.key].type
      identity_ids = local.managed_identities[each.key].type == "UserAssigned" || local.managed_identities[each.key].type == "SystemAssigned, UserAssigned" ? local.managed_identities[each.key].user_assigned_resource_ids : null
    }
  }
  
  # AVM Pattern: Encryption at Host
  encryption_at_host_enabled = try(each.value.encryption_at_host_enabled, true)
  
  # AVM Pattern: Secure Boot and vTPM (Trusted Launch)
  secure_boot_enabled = try(each.value.enable_secure_boot, false)
  vtpm_enabled        = try(each.value.enable_vtpm, false)
  
  # OS Disk (Enhanced with encryption support)
  os_disk {
    name                   = "${each.value.vm_name}-osdisk"
    caching                = each.value.os_disk_caching
    storage_account_type   = each.value.os_disk_type
    disk_size_gb           = each.value.os_disk_size_gb
    disk_encryption_set_id = try(each.value.disk_encryption_set_id, null)
  }
  
  # Source Image
  source_image_reference {
    publisher = each.value.source_image_reference.publisher
    offer     = each.value.source_image_reference.offer
    sku       = each.value.source_image_reference.sku
    version   = each.value.source_image_reference.version
  }
  
  # AVM Pattern: Boot Diagnostics with optional storage URI
  dynamic "boot_diagnostics" {
    for_each = try(each.value.enable_boot_diagnostics, true) ? [1] : []
    content {
      storage_account_uri = try(each.value.boot_diagnostics_storage_uri, null)
    }
  }
  
  tags = each.value.tags
  
  lifecycle {
    ignore_changes = [
      tags["created_date"],
      tags["created_by"],
      tags["deployment_id"]
    ]
  }
}

#=============================================================================
# WINDOWS VIRTUAL MACHINES (Enhanced with AVM Patterns)
#=============================================================================

resource "azurerm_windows_virtual_machine" "windows_vm" {
  for_each = {
    for vm_key, vm_config in local.normalized_vms : vm_key => vm_config
    if vm_config.os_type == "windows"
  }
  
  name                = each.value.vm_name
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = each.value.vm_size
  
  admin_username = each.value.admin_username
  admin_password = each.value.admin_password
  
  network_interface_ids = [
    azurerm_network_interface.vm_nic[each.key].id
  ]
  
  # High availability
  availability_set_id = each.value.availability_set_name != null ? azurerm_availability_set.avset[each.value.availability_set_name].id : null
  proximity_placement_group_id = each.value.proximity_placement_group_name != null ? azurerm_proximity_placement_group.ppg[each.value.proximity_placement_group_name].id : null
  zone = each.value.zone
  
  # AVM Pattern: Managed Identity Support
  dynamic "identity" {
    for_each = local.managed_identities[each.key].type != null ? [1] : []
    content {
      type         = local.managed_identities[each.key].type
      identity_ids = local.managed_identities[each.key].type == "UserAssigned" || local.managed_identities[each.key].type == "SystemAssigned, UserAssigned" ? local.managed_identities[each.key].user_assigned_resource_ids : null
    }
  }
  
  # AVM Pattern: Encryption at Host
  encryption_at_host_enabled = try(each.value.encryption_at_host_enabled, true)
  
  # AVM Pattern: Secure Boot and vTPM (Trusted Launch)
  secure_boot_enabled = try(each.value.enable_secure_boot, false)
  vtpm_enabled        = try(each.value.enable_vtpm, false)
  
  # OS Disk (Enhanced with encryption support)
  os_disk {
    name                   = "${each.value.vm_name}-osdisk"
    caching                = each.value.os_disk_caching
    storage_account_type   = each.value.os_disk_type
    disk_size_gb           = each.value.os_disk_size_gb
    disk_encryption_set_id = try(each.value.disk_encryption_set_id, null)
  }
  
  # Source Image
  source_image_reference {
    publisher = each.value.source_image_reference.publisher
    offer     = each.value.source_image_reference.offer
    sku       = each.value.source_image_reference.sku
    version   = each.value.source_image_reference.version
  }
  
  # AVM Pattern: Boot Diagnostics with optional storage URI
  dynamic "boot_diagnostics" {
    for_each = try(each.value.enable_boot_diagnostics, true) ? [1] : []
    content {
      storage_account_uri = try(each.value.boot_diagnostics_storage_uri, null)
    }
  }
  
  tags = each.value.tags
  
  lifecycle {
    ignore_changes = [
      tags["created_date"],
      tags["created_by"],
      tags["deployment_id"]
    ]
  }
}

#=============================================================================
# MANAGED DATA DISKS (Enhanced with encryption support)
#=============================================================================

resource "azurerm_managed_disk" "data_disk" {
  for_each = {
    for disk in local.data_disks : "${disk.vm_key}-${disk.disk_key}" => disk
  }
  
  name                   = each.value.disk_name
  location               = var.location
  resource_group_name    = var.resource_group_name
  storage_account_type   = each.value.disk_type
  create_option          = each.value.create_option
  disk_size_gb           = each.value.disk_size_gb
  
  # AVM Pattern: Customer-managed key encryption support
  disk_encryption_set_id = try(local.normalized_vms[each.value.vm_key].disk_encryption_set_id, null)
  
  tags = merge(
    var.tags,
    local.normalized_vms[each.value.vm_key].tags
  )
}

#=============================================================================
# DATA DISK ATTACHMENTS - LINUX
#=============================================================================

resource "azurerm_virtual_machine_data_disk_attachment" "linux_disk" {
  for_each = {
    for disk in local.data_disks : "${disk.vm_key}-${disk.disk_key}" => disk
    if local.normalized_vms[disk.vm_key].os_type == "linux"
  }
  
  managed_disk_id    = azurerm_managed_disk.data_disk[each.key].id
  virtual_machine_id = azurerm_linux_virtual_machine.linux_vm[each.value.vm_key].id
  lun                = each.value.lun
  caching            = each.value.disk_caching
}

#=============================================================================
# DATA DISK ATTACHMENTS - WINDOWS
#=============================================================================

resource "azurerm_virtual_machine_data_disk_attachment" "windows_disk" {
  for_each = {
    for disk in local.data_disks : "${disk.vm_key}-${disk.disk_key}" => disk
    if local.normalized_vms[disk.vm_key].os_type == "windows"
  }
  
  managed_disk_id    = azurerm_managed_disk.data_disk[each.key].id
  virtual_machine_id = azurerm_windows_virtual_machine.windows_vm[each.value.vm_key].id
  lun                = each.value.lun
  caching            = each.value.disk_caching
}
