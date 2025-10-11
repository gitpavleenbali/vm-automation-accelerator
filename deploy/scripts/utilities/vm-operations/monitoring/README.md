# VM Monitoring Agent Installation Scripts

This directory contains automated scripts for installing monitoring and diagnostic agents on Azure VMs.

## Overview

These scripts handle the installation and configuration of Azure monitoring agents including:
- Azure Monitor Agent (AMA)
- Log Analytics Agent
- Diagnostic extensions
- Custom monitoring solutions

## Scripts

### install-agents-linux.sh

**Purpose**: Installs monitoring agents on Linux-based Azure VMs.

**Supported Distributions**:
- Ubuntu 18.04, 20.04, 22.04
- RHEL 7, 8, 9
- CentOS 7, 8
- Debian 9, 10, 11

**Prerequisites**:
- Azure CLI installed and authenticated
- Root or sudo privileges
- Network connectivity to Azure endpoints

**Usage**:
```bash
sudo bash deploy/scripts/utilities/vm-operations/monitoring/install-agents-linux.sh \
  --workspace-id "<LOG_ANALYTICS_WORKSPACE_ID>" \
  --workspace-key "<LOG_ANALYTICS_WORKSPACE_KEY>" \
  --resource-id "<VM_RESOURCE_ID>"
```

**Parameters**:
- `--workspace-id`: Log Analytics Workspace ID (required)
- `--workspace-key`: Log Analytics Workspace primary key (required)
- `--resource-id`: Azure VM resource ID (optional, auto-detected if running on Azure VM)

**Example**:
```bash
sudo bash deploy/scripts/utilities/vm-operations/monitoring/install-agents-linux.sh \
  --workspace-id "a1b2c3d4-e5f6-g7h8-i9j0-k1l2m3n4o5p6" \
  --workspace-key "AbCdEfGhIjKlMnOpQrStUvWxYz1234567890==" \
  --resource-id "/subscriptions/sub-id/resourceGroups/rg-name/providers/Microsoft.Compute/virtualMachines/vm-name"
```

### Install-Agents-Windows.ps1

**Purpose**: Installs monitoring agents on Windows-based Azure VMs.

**Supported OS Versions**:
- Windows Server 2016, 2019, 2022
- Windows 10, 11 (Enterprise/Pro)

**Prerequisites**:
- PowerShell 5.1 or later
- Administrator privileges
- Azure PowerShell module (optional, for auto-detection)

**Usage**:
```powershell
.\deploy\scripts\utilities\vm-operations\monitoring\Install-Agents-Windows.ps1 `
  -WorkspaceId "<LOG_ANALYTICS_WORKSPACE_ID>" `
  -WorkspaceKey "<LOG_ANALYTICS_WORKSPACE_KEY>" `
  -ResourceId "<VM_RESOURCE_ID>"
```

**Parameters**:
- `-WorkspaceId`: Log Analytics Workspace ID (required)
- `-WorkspaceKey`: Log Analytics Workspace primary key (required)
- `-ResourceId`: Azure VM resource ID (optional, auto-detected if running on Azure VM)
- `-InstallAMA`: Switch to install Azure Monitor Agent (default: true)
- `-InstallDiagnostics`: Switch to install diagnostic extension (default: true)

**Example**:
```powershell
.\deploy\scripts\utilities\vm-operations\monitoring\Install-Agents-Windows.ps1 `
  -WorkspaceId "a1b2c3d4-e5f6-g7h8-i9j0-k1l2m3n4o5p6" `
  -WorkspaceKey "AbCdEfGhIjKlMnOpQrStUvWxYz1234567890==" `
  -ResourceId "/subscriptions/sub-id/resourceGroups/rg-name/providers/Microsoft.Compute/virtualMachines/vm-name" `
  -InstallAMA `
  -InstallDiagnostics
```

## Integration with Deployment Pipeline

These scripts are automatically invoked during VM provisioning when monitoring is enabled:

1. **Terraform Deployment**: Called via `local-exec` provisioner after VM creation
2. **Pipeline Execution**: Integrated into post-deployment validation stage
3. **ServiceNow Integration**: Installation status reported to ServiceNow tickets

## Troubleshooting

### Linux Script Issues

**Problem**: Agent installation fails with permission denied
```bash
# Solution: Ensure sudo privileges
sudo -v
```

**Problem**: Workspace key authentication fails
```bash
# Solution: Verify workspace credentials
az monitor log-analytics workspace show --workspace-name <workspace-name> -g <resource-group>
```

### Windows Script Issues

**Problem**: PowerShell execution policy blocks script
```powershell
# Solution: Set execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Problem**: Azure Monitor Agent installation fails
```powershell
# Solution: Check Windows Update service
Get-Service wuauserv | Start-Service
```

## Logs and Monitoring

- **Linux Logs**: `/var/log/azure-monitoring-agent.log`
- **Windows Logs**: `C:\WindowsAzure\Logs\MonitoringAgent.log`
- **Agent Status**: Check via Azure Portal > VM > Extensions blade

## Related Documentation

- [Azure Monitor Overview](../../../../../../docs/monitoring/azure-monitor.md)
- [Log Analytics Configuration](../../../../../../terraform-docs/MONITORING-GUIDE.md)
- [VM Deployment Guide](../../../../../../terraform-docs/TERRAFORM-GUIDE.md)
