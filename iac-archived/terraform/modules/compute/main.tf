# Compute Module - Virtual Machine
# Supports both Windows and Linux VMs with comprehensive configuration
# Follows Azure Verified Module (AVM) best practices

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85.0"
    }
  }
}

# Local variables for identity type calculation (AVM pattern)
locals {
  managed_identity_type = var.managed_identities.system_assigned && length(var.managed_identities.user_assigned_resource_ids) > 0 ? "SystemAssigned, UserAssigned" : (
    var.managed_identities.system_assigned ? "SystemAssigned" : (
      length(var.managed_identities.user_assigned_resource_ids) > 0 ? "UserAssigned" : null
    )
  )
}

# Windows Virtual Machine
resource "azurerm_windows_virtual_machine" "vm" {
  count = var.os_type == "Windows" ? 1 : 0
  
  name                = var.vm_name
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  
  network_interface_ids = var.network_interface_ids
  
  # Security - Encryption at Host (AVM best practice)
  encryption_at_host_enabled = var.encryption_at_host_enabled
  
  # OS Disk Configuration
  os_disk {
    name                   = "osdisk-${var.vm_name}"
    caching                = var.os_disk_caching
    storage_account_type   = var.os_disk_storage_type
    disk_size_gb           = var.os_disk_size_gb
    disk_encryption_set_id = var.disk_encryption_set_id
  }
  
  # Source Image
  dynamic "source_image_reference" {
    for_each = var.use_custom_image ? [] : [1]
    content {
      publisher = var.publisher
      offer     = var.offer
      sku       = var.sku
      version   = var.image_version
    }
  }
  
  source_image_id = var.use_custom_image ? var.source_image_id : null
  
  # Identity
  identity {
    type = var.identity_type
  }
  
  # Boot Diagnostics
  dynamic "boot_diagnostics" {
    for_each = var.enable_boot_diagnostics ? [1] : []
    content {
      storage_account_uri = var.boot_diagnostics_storage_uri
    }
  }
  
  # Trusted Launch Security
  secure_boot_enabled = var.enable_secure_boot
  vtpm_enabled        = var.enable_vtpm
  
  # Availability
  zone = var.availability_zone
  
  # Additional Settings
  patch_mode                = "AutomaticByPlatform"
  provision_vm_agent        = true
  enable_automatic_updates  = false  # Managed via patch management
  
  tags = var.tags
  
  lifecycle {
    ignore_changes = [
      tags["DeploymentDate"]
    ]
  }
}

# Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "vm" {
  count = var.os_type == "Linux" ? 1 : 0
  
  name                = var.vm_name
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username
  
  # Disable password authentication for Linux
  disable_password_authentication = true
  
  network_interface_ids = var.network_interface_ids
  
  # Security - Encryption at Host (AVM best practice)
  encryption_at_host_enabled = var.encryption_at_host_enabled
  
  # SSH Key
  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }
  
  # OS Disk Configuration
  os_disk {
    name                   = "osdisk-${var.vm_name}"
    caching                = var.os_disk_caching
    storage_account_type   = var.os_disk_storage_type
    disk_size_gb           = var.os_disk_size_gb
    disk_encryption_set_id = var.disk_encryption_set_id
  }
  
  # Source Image
  dynamic "source_image_reference" {
    for_each = var.use_custom_image ? [] : [1]
    content {
      publisher = var.publisher
      offer     = var.offer
      sku       = var.sku
      version   = var.image_version
    }
  }
  
  source_image_id = var.use_custom_image ? var.source_image_id : null
  
  # Managed Identity (AVM pattern: supports system + user-assigned)
  dynamic "identity" {
    for_each = var.managed_identities.system_assigned || length(var.managed_identities.user_assigned_resource_ids) > 0 ? [1] : []
    content {
      type         = local.managed_identity_type
      identity_ids = var.managed_identities.user_assigned_resource_ids
    }
  }
  
  # Boot Diagnostics
  dynamic "boot_diagnostics" {
    for_each = var.enable_boot_diagnostics ? [1] : []
    content {
      storage_account_uri = var.boot_diagnostics_storage_uri
    }
  }
  
  # Trusted Launch Security
  secure_boot_enabled = var.enable_secure_boot
  vtpm_enabled        = var.enable_vtpm
  
  # Availability
  zone = var.availability_zone
  
  # Additional Settings
  patch_mode         = "AutomaticByPlatform"
  provision_vm_agent = true
  
  tags = var.tags
  
  lifecycle {
    ignore_changes = [
      tags["DeploymentDate"]
    ]
  }
}

# Data Disks
resource "azurerm_managed_disk" "data" {
  count = length(var.data_disks)
  
  name                   = var.data_disks[count.index].name
  location               = var.location
  resource_group_name    = var.resource_group_name
  storage_account_type   = var.data_disks[count.index].storage_type
  create_option          = "Empty"
  disk_size_gb           = var.data_disks[count.index].size_gb
  disk_encryption_set_id = var.disk_encryption_set_id
  zone                   = var.availability_zone
  
  tags = var.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "data" {
  count = length(var.data_disks)
  
  managed_disk_id    = azurerm_managed_disk.data[count.index].id
  virtual_machine_id = var.os_type == "Windows" ? azurerm_windows_virtual_machine.vm[0].id : azurerm_linux_virtual_machine.vm[0].id
  lun                = var.data_disks[count.index].lun
  caching            = var.data_disks[count.index].caching
}

# ===================================================
# RBAC Role Assignments (AVM Pattern)
# ===================================================

# Role assignments TO the VM resource
resource "azurerm_role_assignment" "vm_scope" {
  for_each = var.role_assignments

  scope                                  = var.os_type == "Windows" ? azurerm_windows_virtual_machine.vm[0].id : azurerm_linux_virtual_machine.vm[0].id
  role_definition_id                     = length(split("/", each.value.role_definition_id_or_name)) > 3 ? each.value.role_definition_id_or_name : null
  role_definition_name                   = length(split("/", each.value.role_definition_id_or_name)) > 3 ? null : each.value.role_definition_id_or_name
  principal_id                           = each.value.principal_id
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  description                            = each.value.description
  principal_type                         = each.value.principal_type
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}

# Diagnostic Settings (AVM Pattern) - Multi-destination support
resource "azurerm_monitor_diagnostic_setting" "vm" {
  for_each = var.diagnostic_settings

  name                           = each.value.name
  target_resource_id             = var.os_type == "Windows" ? azurerm_windows_virtual_machine.vm[0].id : azurerm_linux_virtual_machine.vm[0].id
  log_analytics_workspace_id     = each.value.log_analytics_workspace_resource_id
  storage_account_id             = each.value.storage_account_resource_id
  eventhub_authorization_rule_id = each.value.event_hub_authorization_rule_id
  eventhub_name                  = each.value.event_hub_name

  # Metrics
  dynamic "metric" {
    for_each = length(each.value.metric_categories) > 0 ? each.value.metric_categories : []
    content {
      category = metric.value
      enabled  = true
    }
  }
}

# Role assignments FROM system managed identity to external resources
resource "azurerm_role_assignment" "system_identity_scope" {
  for_each = var.managed_identities.system_assigned ? var.role_assignments_system_managed_identity : {}

  scope                                  = each.value.scope_resource_id
  role_definition_id                     = length(split("/", each.value.role_definition_id_or_name)) > 3 ? each.value.role_definition_id_or_name : null
  role_definition_name                   = length(split("/", each.value.role_definition_id_or_name)) > 3 ? null : each.value.role_definition_id_or_name
  principal_id                           = var.os_type == "Windows" ? azurerm_windows_virtual_machine.vm[0].identity[0].principal_id : azurerm_linux_virtual_machine.vm[0].identity[0].principal_id
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  description                            = each.value.description
  principal_type                         = each.value.principal_type
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}
