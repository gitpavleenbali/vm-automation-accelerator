#=============================================================================
# VM OUTPUTS
#=============================================================================

output "linux_vm_ids" {
  description = "Map of Linux VM names to their IDs"
  value = {
    for vm_key, vm in azurerm_linux_virtual_machine.linux_vm : vm_key => vm.id
  }
}

output "windows_vm_ids" {
  description = "Map of Windows VM names to their IDs"
  value = {
    for vm_key, vm in azurerm_windows_virtual_machine.windows_vm : vm_key => vm.id
  }
}

output "all_vm_ids" {
  description = "Map of all VM names to their IDs"
  value = merge(
    {
      for vm_key, vm in azurerm_linux_virtual_machine.linux_vm : vm_key => vm.id
    },
    {
      for vm_key, vm in azurerm_windows_virtual_machine.windows_vm : vm_key => vm.id
    }
  )
}

output "linux_vm_names" {
  description = "Map of Linux VM keys to their names"
  value = {
    for vm_key, vm in azurerm_linux_virtual_machine.linux_vm : vm_key => vm.name
  }
}

output "windows_vm_names" {
  description = "Map of Windows VM keys to their names"
  value = {
    for vm_key, vm in azurerm_windows_virtual_machine.windows_vm : vm_key => vm.name
  }
}

output "all_vm_names" {
  description = "Map of all VM keys to their names"
  value = merge(
    {
      for vm_key, vm in azurerm_linux_virtual_machine.linux_vm : vm_key => vm.name
    },
    {
      for vm_key, vm in azurerm_windows_virtual_machine.windows_vm : vm_key => vm.name
    }
  )
}

#=============================================================================
# NETWORK OUTPUTS
#=============================================================================

output "nic_ids" {
  description = "Map of VM keys to their NIC IDs"
  value = {
    for vm_key, nic in azurerm_network_interface.vm_nic : vm_key => nic.id
  }
}

output "private_ip_addresses" {
  description = "Map of VM keys to their private IP addresses"
  value = {
    for vm_key, nic in azurerm_network_interface.vm_nic : vm_key => nic.private_ip_address
  }
}

output "public_ip_addresses" {
  description = "Map of VM keys to their public IP addresses (if enabled)"
  value = {
    for vm_key, pip in azurerm_public_ip.vm_pip : vm_key => pip.ip_address
  }
}

#=============================================================================
# HIGH AVAILABILITY OUTPUTS
#=============================================================================

output "availability_set_ids" {
  description = "Map of availability set names to their IDs"
  value = {
    for avset_name, avset in azurerm_availability_set.avset : avset_name => avset.id
  }
}

output "proximity_placement_group_ids" {
  description = "Map of proximity placement group names to their IDs"
  value = {
    for ppg_name, ppg in azurerm_proximity_placement_group.ppg : ppg_name => ppg.id
  }
}

#=============================================================================
# DISK OUTPUTS
#=============================================================================

output "data_disk_ids" {
  description = "Map of data disk identifiers to their IDs"
  value = {
    for disk_key, disk in azurerm_managed_disk.data_disk : disk_key => disk.id
  }
}

output "data_disk_names" {
  description = "Map of data disk identifiers to their names"
  value = {
    for disk_key, disk in azurerm_managed_disk.data_disk : disk_key => disk.name
  }
}

#=============================================================================
# CONNECTION INFO
#=============================================================================

output "connection_info" {
  description = "Connection information for all VMs"
  value = {
    linux_vms = {
      for vm_key, vm in azurerm_linux_virtual_machine.linux_vm : vm_key => {
        vm_name    = vm.name
        private_ip = azurerm_network_interface.vm_nic[vm_key].private_ip_address
        public_ip  = try(azurerm_public_ip.vm_pip[vm_key].ip_address, null)
        ssh_command = try(
          "ssh ${vm.admin_username}@${azurerm_public_ip.vm_pip[vm_key].ip_address}",
          "ssh ${vm.admin_username}@${azurerm_network_interface.vm_nic[vm_key].private_ip_address}"
        )
      }
    }
    windows_vms = {
      for vm_key, vm in azurerm_windows_virtual_machine.windows_vm : vm_key => {
        vm_name    = vm.name
        private_ip = azurerm_network_interface.vm_nic[vm_key].private_ip_address
        public_ip  = try(azurerm_public_ip.vm_pip[vm_key].ip_address, null)
        rdp_command = try(
          "mstsc /v:${azurerm_public_ip.vm_pip[vm_key].ip_address}",
          "mstsc /v:${azurerm_network_interface.vm_nic[vm_key].private_ip_address}"
        )
      }
    }
  }
}

#=============================================================================
# SUMMARY OUTPUTS
#=============================================================================

output "vm_count" {
  description = "Number of VMs created"
  value = {
    linux   = length(azurerm_linux_virtual_machine.linux_vm)
    windows = length(azurerm_windows_virtual_machine.windows_vm)
    total   = length(azurerm_linux_virtual_machine.linux_vm) + length(azurerm_windows_virtual_machine.windows_vm)
  }
}

output "summary" {
  description = "Summary of all resources created"
  value = {
    vms = {
      linux   = length(azurerm_linux_virtual_machine.linux_vm)
      windows = length(azurerm_windows_virtual_machine.windows_vm)
      total   = length(azurerm_linux_virtual_machine.linux_vm) + length(azurerm_windows_virtual_machine.windows_vm)
    }
    availability_sets           = length(azurerm_availability_set.avset)
    proximity_placement_groups  = length(azurerm_proximity_placement_group.ppg)
    data_disks                  = length(azurerm_managed_disk.data_disk)
    public_ips                  = length(azurerm_public_ip.vm_pip)
  }
}
