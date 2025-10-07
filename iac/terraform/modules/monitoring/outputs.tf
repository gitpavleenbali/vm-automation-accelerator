# Monitoring Module Outputs

output "data_collection_rule_id" {
  description = "Data Collection Rule resource ID"
  value       = azurerm_monitor_data_collection_rule.vm_dcr.id
}

output "azure_monitor_agent_installed" {
  description = "Whether Azure Monitor Agent is installed"
  value       = true
}

output "dependency_agent_installed" {
  description = "Whether Dependency Agent is installed"
  value       = var.enable_vm_insights
}
