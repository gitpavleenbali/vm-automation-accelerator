# Compute Module Outputs

output "vm_id" {
  description = "VM resource ID"
  value       = var.os_type == "Windows" ? azurerm_windows_virtual_machine.vm[0].id : azurerm_linux_virtual_machine.vm[0].id
}

output "vm_name" {
  description = "VM name"
  value       = var.vm_name
}

output "vm_principal_id" {
  description = "System-assigned managed identity principal ID (null if not enabled)"
  value       = try(var.os_type == "Windows" ? azurerm_windows_virtual_machine.vm[0].identity[0].principal_id : azurerm_linux_virtual_machine.vm[0].identity[0].principal_id, null)
}

output "vm_identity" {
  description = "Complete identity block with type and IDs (AVM pattern)"
  value       = try(var.os_type == "Windows" ? azurerm_windows_virtual_machine.vm[0].identity[0] : azurerm_linux_virtual_machine.vm[0].identity[0], null)
}

output "data_disk_ids" {
  description = "Data disk resource IDs"
  value       = azurerm_managed_disk.data[*].id
}

output "encryption_at_host_enabled" {
  description = "Whether encryption at host is enabled"
  value       = var.encryption_at_host_enabled
}
