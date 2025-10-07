<#
.SYNOPSIS
    Installs and configures required monitoring and management agents on VMs

.DESCRIPTION
    This script installs the following agents:
    - Azure Monitor Agent (AMA)
    - Microsoft Defender for Endpoint
    - Azure Backup Agent (MARS)
    - Log Analytics Agent (if specified)
    
.PARAMETER VMName
    Name of the virtual machine

.PARAMETER ResourceGroupName
    Resource group containing the VM

.PARAMETER WorkspaceId
    Log Analytics workspace ID

.PARAMETER WorkspaceKey
    Log Analytics workspace key

.PARAMETER InstallDefender
    Install Microsoft Defender for Endpoint

.PARAMETER InstallBackupAgent
    Install Azure Backup (MARS) agent

.PARAMETER BackupVaultResourceId
    Azure Backup vault resource ID

.EXAMPLE
    .\Install-Your OrganizationAgents.ps1 -VMName "prod-vm-app-weu-001" -ResourceGroupName "rg-prod-001" `
        -WorkspaceId "abc-123" -WorkspaceKey "xyz-789" -InstallDefender -InstallBackupAgent

.NOTES
    Author: Cloud Infrastructure Team
    Date: 2025-10-07
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$VMName,
    
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$WorkspaceId,
    
    [Parameter(Mandatory = $false)]
    [string]$WorkspaceKey,
    
    [Parameter(Mandatory = $false)]
    [switch]$InstallDefender,
    
    [Parameter(Mandatory = $false)]
    [switch]$InstallBackupAgent,
    
    [Parameter(Mandatory = $false)]
    [string]$BackupVaultResourceId,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Initialize logging
$logFile = "Install-Your OrganizationAgents-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    Add-Content -Path $logFile -Value $logMessage
}

Write-Log "Starting agent installation for VM: $VMName"

# Get VM details
try {
    Write-Log "Getting VM details..."
    $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction Stop
    Write-Log "VM found: $($vm.Name) in $($vm.Location)"
    Write-Log "OS Type: $($vm.StorageProfile.OsDisk.OsType)"
    $isWindows = $vm.StorageProfile.OsDisk.OsType -eq "Windows"
} catch {
    Write-Log "Failed to get VM details: $_" -Level "ERROR"
    throw
}

# =============================================================================
# INSTALL AZURE MONITOR AGENT (AMA)
# =============================================================================

Write-Log "Installing Azure Monitor Agent..."

try {
    $amaExtensionName = if ($isWindows) { "AzureMonitorWindowsAgent" } else { "AzureMonitorLinuxAgent" }
    $amaPublisher = "Microsoft.Azure.Monitor"
    $amaType = if ($isWindows) { "AzureMonitorWindowsAgent" } else { "AzureMonitorLinuxAgent" }
    
    # Check if AMA is already installed
    $existingAma = Get-AzVMExtension -ResourceGroupName $ResourceGroupName -VMName $VMName `
        -Name $amaExtensionName -ErrorAction SilentlyContinue
    
    if ($existingAma) {
        Write-Log "Azure Monitor Agent already installed, skipping..."
    } else {
        if ($WhatIf) {
            Write-Log "[WHATIF] Would install Azure Monitor Agent" -Level "INFO"
        } else {
            Write-Log "Installing Azure Monitor Agent extension..."
            
            $amaSettings = @{
                "workspaceId" = $WorkspaceId
            }
            
            $amaProtectedSettings = @{
                "workspaceKey" = $WorkspaceKey
            }
            
            Set-AzVMExtension -ResourceGroupName $ResourceGroupName -VMName $VMName `
                -Name $amaExtensionName -Publisher $amaPublisher -ExtensionType $amaType `
                -TypeHandlerVersion "1.0" -Settings $amaSettings -ProtectedSettings $amaProtectedSettings `
                -Location $vm.Location -ErrorAction Stop | Out-Null
            
            Write-Log "Azure Monitor Agent installed successfully" -Level "SUCCESS"
        }
    }
} catch {
    Write-Log "Failed to install Azure Monitor Agent: $_" -Level "ERROR"
}

# =============================================================================
# INSTALL MICROSOFT DEFENDER FOR ENDPOINT
# =============================================================================

if ($InstallDefender) {
    Write-Log "Installing Microsoft Defender for Endpoint..."
    
    try {
        $defenderExtensionName = "MDE.Windows"
        $defenderPublisher = "Microsoft.Azure.AzureDefenderForServers"
        $defenderType = "MDE.Windows"
        
        # Check if Defender is already installed
        $existingDefender = Get-AzVMExtension -ResourceGroupName $ResourceGroupName -VMName $VMName `
            -Name $defenderExtensionName -ErrorAction SilentlyContinue
        
        if ($existingDefender) {
            Write-Log "Microsoft Defender already installed, skipping..."
        } else {
            if ($WhatIf) {
                Write-Log "[WHATIF] Would install Microsoft Defender for Endpoint" -Level "INFO"
            } else {
                Write-Log "Installing Microsoft Defender extension..."
                
                Set-AzVMExtension -ResourceGroupName $ResourceGroupName -VMName $VMName `
                    -Name $defenderExtensionName -Publisher $defenderPublisher -ExtensionType $defenderType `
                    -TypeHandlerVersion "1.0" -Location $vm.Location -ErrorAction Stop | Out-Null
                
                Write-Log "Microsoft Defender for Endpoint installed successfully" -Level "SUCCESS"
            }
        }
    } catch {
        Write-Log "Failed to install Microsoft Defender: $_" -Level "ERROR"
    }
}

# =============================================================================
# INSTALL AZURE BACKUP AGENT (MARS)
# =============================================================================

if ($InstallBackupAgent -and $isWindows) {
    Write-Log "Installing Azure Backup (MARS) Agent..."
    
    try {
        $backupExtensionName = "AzureBackupWindowsWorkload"
        $backupPublisher = "Microsoft.Azure.RecoveryServices"
        $backupType = "AzureBackupWindowsWorkload"
        
        # Check if Backup agent is already installed
        $existingBackup = Get-AzVMExtension -ResourceGroupName $ResourceGroupName -VMName $VMName `
            -Name $backupExtensionName -ErrorAction SilentlyContinue
        
        if ($existingBackup) {
            Write-Log "Azure Backup agent already installed, skipping..."
        } else {
            if ($WhatIf) {
                Write-Log "[WHATIF] Would install Azure Backup (MARS) Agent" -Level "INFO"
            } else {
                Write-Log "Installing Azure Backup extension..."
                
                $backupSettings = @{
                    "vaultResourceId" = $BackupVaultResourceId
                }
                
                Set-AzVMExtension -ResourceGroupName $ResourceGroupName -VMName $VMName `
                    -Name $backupExtensionName -Publisher $backupPublisher -ExtensionType $backupType `
                    -TypeHandlerVersion "1.0" -Settings $backupSettings -Location $vm.Location `
                    -ErrorAction Stop | Out-Null
                
                Write-Log "Azure Backup (MARS) Agent installed successfully" -Level "SUCCESS"
            }
        }
    } catch {
        Write-Log "Failed to install Azure Backup agent: $_" -Level "ERROR"
    }
} elseif ($InstallBackupAgent -and -not $isWindows) {
    Write-Log "Azure Backup (MARS) agent is only supported on Windows VMs" -Level "WARNING"
}

# =============================================================================
# INSTALL DEPENDENCY AGENT (for VM Insights)
# =============================================================================

Write-Log "Installing Dependency Agent for VM Insights..."

try {
    $depAgentName = if ($isWindows) { "DependencyAgentWindows" } else { "DependencyAgentLinux" }
    $depAgentPublisher = "Microsoft.Azure.Monitoring.DependencyAgent"
    $depAgentType = if ($isWindows) { "DependencyAgentWindows" } else { "DependencyAgentLinux" }
    
    # Check if Dependency Agent is already installed
    $existingDepAgent = Get-AzVMExtension -ResourceGroupName $ResourceGroupName -VMName $VMName `
        -Name $depAgentName -ErrorAction SilentlyContinue
    
    if ($existingDepAgent) {
        Write-Log "Dependency Agent already installed, skipping..."
    } else {
        if ($WhatIf) {
            Write-Log "[WHATIF] Would install Dependency Agent" -Level "INFO"
        } else {
            Write-Log "Installing Dependency Agent extension..."
            
            Set-AzVMExtension -ResourceGroupName $ResourceGroupName -VMName $VMName `
                -Name $depAgentName -Publisher $depAgentPublisher -ExtensionType $depAgentType `
                -TypeHandlerVersion "9.10" -Location $vm.Location -ErrorAction Stop | Out-Null
            
            Write-Log "Dependency Agent installed successfully" -Level "SUCCESS"
        }
    }
} catch {
    Write-Log "Failed to install Dependency Agent: $_" -Level "ERROR"
}

# =============================================================================
# VERIFY INSTALLATIONS
# =============================================================================

Write-Log "Verifying agent installations..."

$extensions = Get-AzVMExtension -ResourceGroupName $ResourceGroupName -VMName $VMName

Write-Log "Installed extensions:"
foreach ($ext in $extensions) {
    $status = if ($ext.ProvisioningState -eq "Succeeded") { "✓" } else { "✗" }
    Write-Log "  $status $($ext.Name) - $($ext.ProvisioningState)"
}

Write-Log "Agent installation completed" -Level "SUCCESS"
Write-Log "Log file: $logFile"

# Return summary
return @{
    VMName = $VMName
    ResourceGroup = $ResourceGroupName
    InstalledExtensions = $extensions.Count
    Extensions = $extensions | Select-Object Name, ProvisioningState, TypeHandlerVersion
    LogFile = $logFile
}
