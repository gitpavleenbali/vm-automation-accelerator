# Network Interface Module Outputs

output "nic_id" {
  description = "NIC resource ID"
  value       = azurerm_network_interface.nic.id
}

output "nic_name" {
  description = "NIC name"
  value       = azurerm_network_interface.nic.name
}

output "private_ip_address" {
  description = "Private IP address"
  value       = azurerm_network_interface.nic.private_ip_address
}

output "public_ip_address" {
  description = "Public IP address (if enabled)"
  value       = var.enable_public_ip ? azurerm_public_ip.pip[0].ip_address : null
}
