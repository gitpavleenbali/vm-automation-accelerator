###############################################################################
# Run VM Deployment - Outputs
# Virtual machine deployment outputs
###############################################################################

# ============================================================================
# Resource Group Outputs
# ============================================================================

output "resource_group_name" {
  description = "Name of the resource group"
  value       = local.resource_group_name
}

output "resource_group_id" {
  description = "ID of the resource group"
  value       = local.computed.resource_group_id
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = local.resource_group_location
}

# ============================================================================
# Linux VM Outputs
# ============================================================================

output "linux_vm_ids" {
  description = "Map of Linux VM names to IDs"
  value = {
    for name, vm in azurerm_linux_virtual_machine.vms : name => vm.id
  }
}

output "linux_vm_names" {
  description = "Map of Linux VM keys to names"
  value = {
    for name, vm in azurerm_linux_virtual_machine.vms : name => vm.name
  }
}

output "linux_vm_private_ips" {
  description = "Map of Linux VM names to private IP addresses"
  value = {
    for name, nic in azurerm_network_interface.linux_vms : name => nic.private_ip_address
  }
}

output "linux_vm_public_ips" {
  description = "Map of Linux VM names to public IP addresses (if enabled)"
  value = local.public_ip.enabled ? {
    for name, pip in azurerm_public_ip.linux_vms : name => pip.ip_address
  } : {}
}

output "linux_vms" {
  description = "Complete Linux VM information"
  value = {
    for name, vm in azurerm_linux_virtual_machine.vms : name => {
      id              = vm.id
      name            = vm.name
      size            = vm.size
      zone            = vm.zone
      private_ip      = azurerm_network_interface.linux_vms[name].private_ip_address
      public_ip       = local.public_ip.enabled ? azurerm_public_ip.linux_vms[name].ip_address : null
      admin_username  = vm.admin_username
      os_disk_id      = vm.os_disk[0].name
    }
  }
}

# ============================================================================
# Windows VM Outputs
# ============================================================================

output "windows_vm_ids" {
  description = "Map of Windows VM names to IDs"
  value = {
    for name, vm in azurerm_windows_virtual_machine.vms : name => vm.id
  }
}

output "windows_vm_names" {
  description = "Map of Windows VM keys to names"
  value = {
    for name, vm in azurerm_windows_virtual_machine.vms : name => vm.name
  }
}

output "windows_vm_private_ips" {
  description = "Map of Windows VM names to private IP addresses"
  value = {
    for name, nic in azurerm_network_interface.windows_vms : name => nic.private_ip_address
  }
}

output "windows_vm_public_ips" {
  description = "Map of Windows VM names to public IP addresses (if enabled)"
  value = local.public_ip.enabled ? {
    for name, pip in azurerm_public_ip.windows_vms : name => pip.ip_address
  } : {}
}

output "windows_vms" {
  description = "Complete Windows VM information"
  value = {
    for name, vm in azurerm_windows_virtual_machine.vms : name => {
      id              = vm.id
      name            = vm.name
      size            = vm.size
      zone            = vm.zone
      private_ip      = azurerm_network_interface.windows_vms[name].private_ip_address
      public_ip       = local.public_ip.enabled ? azurerm_public_ip.windows_vms[name].ip_address : null
      admin_username  = vm.admin_username
      os_disk_id      = vm.os_disk[0].name
    }
  }
  sensitive = true # Contains admin_username
}

# ============================================================================
# Combined VM Outputs
# ============================================================================

output "all_vm_ids" {
  description = "Map of all VM names to IDs"
  value = merge(
    { for name, vm in azurerm_linux_virtual_machine.vms : name => vm.id },
    { for name, vm in azurerm_windows_virtual_machine.vms : name => vm.id }
  )
}

output "all_vm_names" {
  description = "Map of all VM keys to names"
  value = merge(
    { for name, vm in azurerm_linux_virtual_machine.vms : name => vm.name },
    { for name, vm in azurerm_windows_virtual_machine.vms : name => vm.name }
  )
}

output "all_vm_private_ips" {
  description = "Map of all VM names to private IP addresses"
  value = merge(
    { for name, nic in azurerm_network_interface.linux_vms : name => nic.private_ip_address },
    { for name, nic in azurerm_network_interface.windows_vms : name => nic.private_ip_address }
  )
}

# ============================================================================
# Network Interface Outputs
# ============================================================================

output "nic_ids" {
  description = "Map of NIC names to IDs"
  value = merge(
    { for name, nic in azurerm_network_interface.linux_vms : name => nic.id },
    { for name, nic in azurerm_network_interface.windows_vms : name => nic.id }
  )
}

# ============================================================================
# Availability Outputs
# ============================================================================

output "availability_set_id" {
  description = "ID of the availability set (if created)"
  value       = local.computed.create_availability_set ? azurerm_availability_set.vm_deployment[0].id : null
}

output "proximity_placement_group_id" {
  description = "ID of the proximity placement group (if created)"
  value       = local.computed.create_proximity_group ? azurerm_proximity_placement_group.vm_deployment[0].id : null
}

# ============================================================================
# Disk Outputs
# ============================================================================

output "linux_data_disk_ids" {
  description = "Map of Linux data disk names to IDs"
  value = {
    for name, disk in azurerm_managed_disk.linux_data_disks : name => disk.id
  }
}

output "windows_data_disk_ids" {
  description = "Map of Windows data disk names to IDs"
  value = {
    for name, disk in azurerm_managed_disk.windows_data_disks : name => disk.id
  }
}

# ============================================================================
# Control Plane Integration Outputs
# ============================================================================

output "control_plane_subscription_id" {
  description = "Subscription ID of the control plane"
  value       = local.control_plane_subscription_id
}

output "control_plane_resource_group" {
  description = "Resource group of the control plane"
  value       = local.control_plane_resource_group
}

output "control_plane_key_vault_name" {
  description = "Key Vault name from control plane"
  value       = local.control_plane_key_vault_name
}

output "control_plane_key_vault_id" {
  description = "Key Vault ID from control plane"
  value       = local.control_plane_key_vault_id
}

# ============================================================================
# Workload Zone Integration Outputs
# ============================================================================

output "workload_zone_vnet_name" {
  description = "VNet name from workload zone"
  value       = local.workload_zone_vnet_name
}

output "workload_zone_vnet_id" {
  description = "VNet ID from workload zone"
  value       = local.workload_zone_vnet_id
}

output "workload_zone_subnet_ids" {
  description = "Subnet IDs from workload zone"
  value       = local.workload_zone_subnet_ids
}

# ============================================================================
# Deployment Metadata Outputs
# ============================================================================

output "deployment_id" {
  description = "Unique deployment identifier"
  value       = local.deployment.id
}

output "deployment_timestamp" {
  description = "Timestamp of deployment"
  value       = local.deployment.timestamp
}

output "automation_version" {
  description = "Version of the VM automation framework"
  value       = local.deployment.framework_version
}

# ============================================================================
# VM Counts
# ============================================================================

output "vm_counts" {
  description = "Count of VMs by type"
  value = {
    linux   = local.computed.linux_vm_count
    windows = local.computed.windows_vm_count
    total   = local.computed.total_vm_count
  }
}

# ============================================================================
# Connection Information
# ============================================================================

output "connection_info" {
  description = "Connection information for VMs"
  value = merge(
    {
      for name, vm in azurerm_linux_virtual_machine.vms : name => {
        hostname    = vm.name
        private_ip  = azurerm_network_interface.linux_vms[name].private_ip_address
        public_ip   = local.public_ip.enabled ? azurerm_public_ip.linux_vms[name].ip_address : null
        username    = vm.admin_username
        os_type     = "Linux"
        connect_cmd = local.public_ip.enabled ? "ssh ${vm.admin_username}@${azurerm_public_ip.linux_vms[name].ip_address}" : "ssh ${vm.admin_username}@${azurerm_network_interface.linux_vms[name].private_ip_address}"
      }
    },
    {
      for name, vm in azurerm_windows_virtual_machine.vms : name => {
        hostname    = vm.name
        private_ip  = azurerm_network_interface.windows_vms[name].private_ip_address
        public_ip   = local.public_ip.enabled ? azurerm_public_ip.windows_vms[name].ip_address : null
        username    = vm.admin_username
        os_type     = "Windows"
        connect_cmd = local.public_ip.enabled ? "mstsc /v:${azurerm_public_ip.windows_vms[name].ip_address}" : "mstsc /v:${azurerm_network_interface.windows_vms[name].private_ip_address}"
      }
    }
  )
}

# ============================================================================
# Deployment Summary
# ============================================================================

output "deployment_summary" {
  description = "Summary of VM deployment"
  value = {
    resource_group     = local.resource_group_name
    location           = local.resource_group_location
    environment        = local.environment.name
    workload           = local.workload.name
    linux_vm_count     = local.computed.linux_vm_count
    windows_vm_count   = local.computed.windows_vm_count
    total_vm_count     = local.computed.total_vm_count
    availability_set   = local.computed.create_availability_set
    proximity_group    = local.computed.create_proximity_group
    public_ips_enabled = local.public_ip.enabled
    backup_enabled     = local.backup.enabled
    monitoring_enabled = local.monitoring.enabled
    deployment_id      = local.deployment.id
    deployment_time    = local.deployment.timestamp
  }
}
