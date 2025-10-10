# Monitoring Module

## Overview

This module deploys comprehensive monitoring capabilities for Azure Virtual Machines using Azure Monitor Agent (AMA), Data Collection Rules (DCR), and optional VM Insights with Dependency Agent.

## Features

- **Azure Monitor Agent (AMA)**: Latest generation agent for both Windows and Linux VMs
- **Data Collection Rules**: Centralized configuration for performance counters and event logs
- **VM Insights**: Service map and connection monitoring via Dependency Agent
- **Performance Monitoring**: CPU, memory, disk, and network metrics
- **Event Log Collection**: Windows Event Logs and Linux Syslog
- **Automatic Updates**: Agents configured for automatic minor version upgrades

## Usage

### Basic Example

```hcl
module "vm_monitoring" {
  source = "../../terraform-units/modules/monitoring"
  
  vm_id                       = azurerm_linux_virtual_machine.vm.id
  vm_name                     = azurerm_linux_virtual_machine.vm.name
  resource_group_name         = azurerm_resource_group.main.name
  location                    = azurerm_resource_group.main.location
  os_type                     = "Linux"
  log_analytics_workspace_id  = azurerm_log_analytics_workspace.law.id
  log_analytics_workspace_key = azurerm_log_analytics_workspace.law.primary_shared_key
  
  tags = var.tags
}
```

### Windows VM with Full Monitoring

```hcl
module "windows_vm_monitoring" {
  source = "../../terraform-units/modules/monitoring"
  
  vm_id                       = azurerm_windows_virtual_machine.vm.id
  vm_name                     = "vm-web01-prod"
  resource_group_name         = "rg-monitoring-prod"
  location                    = "eastus"
  os_type                     = "Windows"
  log_analytics_workspace_id  = azurerm_log_analytics_workspace.law.id
  log_analytics_workspace_key = azurerm_log_analytics_workspace.law.primary_shared_key
  
  enable_performance_counters = true
  enable_event_logs           = true
  enable_vm_insights          = true
  
  tags = {
    Environment = "production"
    Monitoring  = "enabled"
  }
}
```

### Linux VM with Minimal Monitoring

```hcl
module "linux_vm_monitoring" {
  source = "../../terraform-units/modules/monitoring"
  
  vm_id                       = azurerm_linux_virtual_machine.vm.id
  vm_name                     = "vm-app01-dev"
  resource_group_name         = "rg-monitoring-dev"
  location                    = "westus2"
  os_type                     = "Linux"
  log_analytics_workspace_id  = azurerm_log_analytics_workspace.law.id
  log_analytics_workspace_key = azurerm_log_analytics_workspace.law.primary_shared_key
  
  enable_performance_counters = true
  enable_event_logs           = false  # Disable event logs
  enable_vm_insights          = false  # Disable VM Insights
  
  tags = var.tags
}
```

## Required Inputs

| Name | Description | Type |
|------|-------------|------|
| `vm_id` | Azure resource ID of the VM to monitor | `string` |
| `vm_name` | Name of the VM (used for DCR naming) | `string` |
| `resource_group_name` | Resource group for monitoring resources | `string` |
| `location` | Azure region for monitoring resources | `string` |
| `os_type` | Operating system: 'Windows' or 'Linux' | `string` |
| `log_analytics_workspace_id` | Log Analytics workspace resource ID | `string` |
| `log_analytics_workspace_key` | Log Analytics workspace shared key | `string` (sensitive) |

## Optional Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `enable_performance_counters` | Enable performance counter collection | `bool` | `true` |
| `enable_event_logs` | Enable event log collection | `bool` | `true` |
| `enable_vm_insights` | Enable VM Insights (Dependency Agent) | `bool` | `true` |
| `tags` | Tags for monitoring resources | `map(string)` | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| `data_collection_rule_id` | Resource ID of the Data Collection Rule |
| `data_collection_rule_name` | Name of the Data Collection Rule |
| `azure_monitor_agent_installed` | Confirmation of AMA installation |
| `dependency_agent_installed` | Confirmation of Dependency Agent installation |
| `monitoring_configuration` | Summary of monitoring configuration |

## Data Collection

### Windows Performance Counters (60-second intervals)

- `\Processor(_Total)\% Processor Time`
- `\Memory\Available Bytes`
- `\Memory\% Committed Bytes In Use`
- `\LogicalDisk(_Total)\% Free Space`
- `\LogicalDisk(_Total)\Disk Bytes/sec`
- `\Network Interface(*)\Bytes Total/sec`

### Windows Event Logs

- **Application**: Error, Warning, Critical events
- **System**: Error, Warning, Critical events
- **Security**: Logon success/failure events (4624, 4625, 4634)

### Linux Syslog

- **Facilities**: auth, authpriv, cron, daemon, kern, syslog
- **Levels**: Error, Critical, Alert, Emergency

## VM Insights

When `enable_vm_insights = true`, the module installs the Dependency Agent which provides:

- **Service Map**: Visual representation of VM connections
- **Connection Monitoring**: Track network connections and performance
- **Process Monitoring**: Detailed process and service dependency tracking

## Architecture

```
┌─────────────────────────────────────────────────┐
│           Azure Virtual Machine                  │
│                                                   │
│  ┌──────────────────┐   ┌──────────────────┐   │
│  │ Azure Monitor    │   │ Dependency       │   │
│  │ Agent (AMA)      │   │ Agent (Optional) │   │
│  └────────┬─────────┘   └────────┬─────────┘   │
│           │                      │               │
└───────────┼──────────────────────┼───────────────┘
            │                      │
            └──────────┬───────────┘
                       │
            ┌──────────▼──────────┐
            │ Data Collection     │
            │ Rule (DCR)          │
            └──────────┬──────────┘
                       │
            ┌──────────▼──────────┐
            │ Log Analytics       │
            │ Workspace           │
            └─────────────────────┘
```

## Dependencies

This module requires:

- **azurerm provider** version >= 3.80
- **Terraform** version >= 1.5.0
- Existing Log Analytics Workspace
- VM must be in running state for agent deployment

## Notes

1. **Agent Installation Time**: Agents may take 5-10 minutes to install and start collecting data
2. **Data Latency**: Initial data may take 10-15 minutes to appear in Log Analytics
3. **Cost Considerations**: Monitor Log Analytics ingestion costs based on data volume
4. **Automatic Updates**: Agents are configured with `automatic_upgrade_enabled = true`
5. **VM Restart**: Agent installation does not require VM restart

## Best Practices

1. **Enable VM Insights for production workloads** to get comprehensive dependency mapping
2. **Use consistent tagging** across monitoring resources for better organization
3. **Review DCR configurations** periodically to optimize data collection costs
4. **Set up alerts** in Azure Monitor based on collected metrics and logs
5. **Test monitoring** in non-production environments first

## Troubleshooting

### Agent Not Reporting

1. Check VM is running: `az vm get-instance-view`
2. Verify agent extension status: `az vm extension list`
3. Check VM connectivity to Azure Monitor endpoints
4. Review extension logs on the VM

### No Data in Log Analytics

1. Verify DCR association: Check if DCR is linked to VM
2. Wait 10-15 minutes for initial data ingestion
3. Check Log Analytics workspace permissions
4. Query `Heartbeat` table to confirm agent connectivity

### VM Insights Not Working

1. Ensure Dependency Agent is installed
2. Verify VM Insights solution is enabled in workspace
3. Check VM meets minimum requirements (1 GB RAM, 1 vCPU)
4. Review agent logs at:
   - Windows: `C:\WindowsAzure\Logs\Plugins\Microsoft.Azure.Monitoring.DependencyAgent.DependencyAgentWindows`
   - Linux: `/var/log/azure/Microsoft.Azure.Monitoring.DependencyAgent.DependencyAgentLinux`

## Examples of Log Analytics Queries

### CPU Usage Over Time

```kusto
Perf
| where ObjectName == "Processor" and CounterName == "% Processor Time"
| where Computer == "vm-name"
| summarize AvgCPU = avg(CounterValue) by bin(TimeGenerated, 5m)
| render timechart
```

### Memory Available

```kusto
Perf
| where ObjectName == "Memory" and CounterName == "Available MBytes"
| where Computer == "vm-name"
| summarize AvgMemory = avg(CounterValue) by bin(TimeGenerated, 5m)
| render timechart
```

### Recent Error Events (Windows)

```kusto
Event
| where Computer == "vm-name"
| where EventLevelName == "Error"
| project TimeGenerated, Source, EventID, RenderedDescription
| order by TimeGenerated desc
| take 50
```

### Recent Syslog Errors (Linux)

```kusto
Syslog
| where Computer == "vm-name"
| where SeverityLevel == "err" or SeverityLevel == "crit"
| project TimeGenerated, Facility, SeverityLevel, SyslogMessage
| order by TimeGenerated desc
| take 50
```

## Related Modules

- [Compute Module](../compute/README.md) - VM deployment module that can use this monitoring module
- [Network Module](../network/README.md) - Network infrastructure for VMs

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2024 | Initial release with AMA and VM Insights support |

## License

This module is part of the Uniper VM Automation Accelerator.
