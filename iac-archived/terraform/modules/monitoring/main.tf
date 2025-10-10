# Monitoring Module
# Installs Azure Monitor Agent and Dependency Agent

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85.0"
    }
  }
}

# Azure Monitor Agent Extension (Windows)
resource "azurerm_virtual_machine_extension" "ama_windows" {
  count = var.os_type == "Windows" ? 1 : 0
  
  name                       = "AzureMonitorWindowsAgent"
  virtual_machine_id         = var.vm_id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true
  
  settings = jsonencode({
    workspaceId = var.log_analytics_workspace_id
  })
  
  tags = var.tags
}

# Azure Monitor Agent Extension (Linux)
resource "azurerm_virtual_machine_extension" "ama_linux" {
  count = var.os_type == "Linux" ? 1 : 0
  
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = var.vm_id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.25"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true
  
  settings = jsonencode({
    workspaceId = var.log_analytics_workspace_id
  })
  
  tags = var.tags
}

# Dependency Agent Extension (Windows) - For VM Insights
resource "azurerm_virtual_machine_extension" "dependency_windows" {
  count = var.os_type == "Windows" && var.enable_vm_insights ? 1 : 0
  
  name                       = "DependencyAgentWindows"
  virtual_machine_id         = var.vm_id
  publisher                  = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                       = "DependencyAgentWindows"
  type_handler_version       = "9.10"
  auto_upgrade_minor_version = true
  
  settings = jsonencode({
    enableAMA = "true"
  })
  
  tags = var.tags
  
  depends_on = [azurerm_virtual_machine_extension.ama_windows]
}

# Dependency Agent Extension (Linux) - For VM Insights
resource "azurerm_virtual_machine_extension" "dependency_linux" {
  count = var.os_type == "Linux" && var.enable_vm_insights ? 1 : 0
  
  name                       = "DependencyAgentLinux"
  virtual_machine_id         = var.vm_id
  publisher                  = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                       = "DependencyAgentLinux"
  type_handler_version       = "9.10"
  auto_upgrade_minor_version = true
  
  settings = jsonencode({
    enableAMA = "true"
  })
  
  tags = var.tags
  
  depends_on = [azurerm_virtual_machine_extension.ama_linux]
}

# Data Collection Rule for Performance Counters and Event Logs
resource "azurerm_monitor_data_collection_rule" "vm_dcr" {
  name                = "dcr-${var.vm_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  
  destinations {
    log_analytics {
      workspace_resource_id = var.log_analytics_workspace_id
      name                  = "logAnalytics"
    }
  }
  
  # Windows Performance Counters
  dynamic "data_flow" {
    for_each = var.os_type == "Windows" && var.enable_performance_counters ? [1] : []
    content {
      streams      = ["Microsoft-Perf"]
      destinations = ["logAnalytics"]
    }
  }
  
  # Windows Event Logs
  dynamic "data_flow" {
    for_each = var.os_type == "Windows" && var.enable_event_logs ? [1] : []
    content {
      streams      = ["Microsoft-Event"]
      destinations = ["logAnalytics"]
    }
  }
  
  # Linux Syslog
  dynamic "data_flow" {
    for_each = var.os_type == "Linux" && var.enable_event_logs ? [1] : []
    content {
      streams      = ["Microsoft-Syslog"]
      destinations = ["logAnalytics"]
    }
  }
  
  # Windows Performance Counter Sources
  dynamic "data_sources" {
    for_each = var.os_type == "Windows" && var.enable_performance_counters ? [1] : []
    content {
      performance_counter {
        streams                       = ["Microsoft-Perf"]
        sampling_frequency_in_seconds = 60
        counter_specifiers = [
          "\\Processor(_Total)\\% Processor Time",
          "\\Memory\\Available Bytes",
          "\\Memory\\% Committed Bytes In Use",
          "\\LogicalDisk(_Total)\\% Free Space",
          "\\LogicalDisk(_Total)\\Disk Bytes/sec",
          "\\Network Interface(*)\\Bytes Total/sec",
        ]
        name = "perfCounters"
      }
    }
  }
  
  # Windows Event Log Sources
  dynamic "data_sources" {
    for_each = var.os_type == "Windows" && var.enable_event_logs ? [1] : []
    content {
      windows_event_log {
        streams = ["Microsoft-Event"]
        x_path_queries = [
          "Application!*[System[(Level=1 or Level=2 or Level=3)]]",
          "System!*[System[(Level=1 or Level=2 or Level=3)]]",
          "Security!*[System[(EventID=4624 or EventID=4625 or EventID=4634)]]"
        ]
        name = "eventLogs"
      }
    }
  }
  
  # Linux Syslog Sources
  dynamic "data_sources" {
    for_each = var.os_type == "Linux" && var.enable_event_logs ? [1] : []
    content {
      syslog {
        streams        = ["Microsoft-Syslog"]
        facility_names = ["auth", "authpriv", "cron", "daemon", "kern", "syslog"]
        log_levels     = ["Error", "Critical", "Alert", "Emergency"]
        name           = "syslog"
      }
    }
  }
  
  tags = var.tags
}

# Associate Data Collection Rule with VM
resource "azurerm_monitor_data_collection_rule_association" "vm_dcr_association" {
  name                    = "dcra-${var.vm_name}"
  target_resource_id      = var.vm_id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vm_dcr.id
  
  depends_on = [
    azurerm_virtual_machine_extension.ama_windows,
    azurerm_virtual_machine_extension.ama_linux
  ]
}
