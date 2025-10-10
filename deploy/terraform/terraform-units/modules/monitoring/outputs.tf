#=============================================================================
# MONITORING MODULE OUTPUTS
#=============================================================================

output "data_collection_rule_id" {
  description = "Azure resource ID of the Data Collection Rule"
  value       = azurerm_monitor_data_collection_rule.vm_dcr.id
}

output "data_collection_rule_name" {
  description = "Name of the Data Collection Rule"
  value       = azurerm_monitor_data_collection_rule.vm_dcr.name
}

output "azure_monitor_agent_installed" {
  description = "Whether Azure Monitor Agent has been installed"
  value       = true
}

output "dependency_agent_installed" {
  description = "Whether Dependency Agent has been installed (only when VM Insights is enabled)"
  value       = var.enable_vm_insights
}

output "monitoring_configuration" {
  description = "Summary of monitoring configuration applied to the VM"
  value = {
    vm_name                 = var.vm_name
    os_type                 = var.os_type
    performance_counters    = var.enable_performance_counters
    event_logs              = var.enable_event_logs
    vm_insights_enabled     = var.enable_vm_insights
    dcr_id                  = azurerm_monitor_data_collection_rule.vm_dcr.id
    log_analytics_workspace = var.log_analytics_workspace_id
  }
}
