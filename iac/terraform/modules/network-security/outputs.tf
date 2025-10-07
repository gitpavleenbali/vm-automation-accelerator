# Network Security Module Outputs

output "nsg_id" {
  description = "NSG resource ID"
  value       = azurerm_network_security_group.nsg.id
}

output "nsg_name" {
  description = "NSG name"
  value       = azurerm_network_security_group.nsg.name
}
