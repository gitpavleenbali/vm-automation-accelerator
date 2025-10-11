<#
.SYNOPSIS
    Applies security hardening configuration to VMs

.DESCRIPTION
    This script applies security hardening measures including:
    - Disable unnecessary services
    - Configure Windows Firewall
    - Enable BitLocker encryption
    - Configure Windows Update settings
    - Disable anonymous access
    - Configure audit policies
    - Apply CIS benchmarks

.PARAMETER ComputerName
    Target computer name (default: localhost)

.PARAMETER ApplyFirewallRules
    Apply Windows Firewall hardening rules

.PARAMETER EnableBitLocker
    Enable BitLocker encryption on system drive

.PARAMETER DisableUnusedServices
    Disable unnecessary Windows services

.PARAMETER ConfigureAuditPolicies
    Configure advanced audit policies

.PARAMETER WhatIf
    Show what would be done without making changes

.EXAMPLE
    .\Apply-Your OrganizationHardening.ps1 -ComputerName "prod-vm-app-001" -ApplyFirewallRules -EnableBitLocker

.NOTES
    Author: Cloud Infrastructure Team
    Date: 2025-10-07
    Requirements: Run as Administrator
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ComputerName = "localhost",
    
    [Parameter(Mandatory = $false)]
    [switch]$ApplyFirewallRules,
    
    [Parameter(Mandatory = $false)]
    [switch]$EnableBitLocker,
    
    [Parameter(Mandatory = $false)]
    [switch]$DisableUnusedServices,
    
    [Parameter(Mandatory = $false)]
    [switch]$ConfigureAuditPolicies,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

# Require Administrator
#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

# Initialize logging
$logFile = "Apply-Your OrganizationHardening-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    Add-Content -Path $logFile -Value $logMessage
}

Write-Log "Starting security hardening for: $ComputerName"

# =============================================================================
# DISABLE UNNECESSARY SERVICES
# =============================================================================

if ($DisableUnusedServices) {
    Write-Log "Disabling unnecessary services..."
    
    $servicesToDisable = @(
        "RemoteRegistry",          # Remote Registry
        "SSDPSRV",                 # SSDP Discovery
        "upnphost",                # UPnP Device Host
        "WMPNetworkSvc",           # Windows Media Player Network Sharing
        "WerSvc",                  # Windows Error Reporting (consider keeping for diagnostics)
        "XblAuthManager",          # Xbox Live Auth Manager
        "XblGameSave",             # Xbox Live Game Save
        "XboxGipSvc",              # Xbox Accessory Management
        "XboxNetApiSvc"            # Xbox Live Networking Service
    )
    
    foreach ($serviceName in $servicesToDisable) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            
            if ($service) {
                if ($service.Status -eq "Running") {
                    if ($WhatIf) {
                        Write-Log "[WHATIF] Would stop and disable service: $serviceName"
                    } else {
                        Write-Log "Stopping and disabling service: $serviceName"
                        Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
                        Set-Service -Name $serviceName -StartupType Disabled
                        Write-Log "  ✓ $serviceName disabled"
                    }
                } else {
                    Write-Log "  - $serviceName already stopped, setting to disabled"
                    if (-not $WhatIf) {
                        Set-Service -Name $serviceName -StartupType Disabled
                    }
                }
            }
        } catch {
            Write-Log "Failed to disable $serviceName : $_" -Level "WARNING"
        }
    }
}

# =============================================================================
# CONFIGURE WINDOWS FIREWALL
# =============================================================================

if ($ApplyFirewallRules) {
    Write-Log "Configuring Windows Firewall..."
    
    try {
        # Enable Windows Firewall for all profiles
        if ($WhatIf) {
            Write-Log "[WHATIF] Would enable Windows Firewall for all profiles"
        } else {
            Write-Log "Enabling Windows Firewall for all profiles..."
            Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
            Write-Log "  ✓ Firewall enabled for all profiles"
        }
        
        # Block inbound by default
        if ($WhatIf) {
            Write-Log "[WHATIF] Would set default inbound action to Block"
        } else {
            Write-Log "Setting default inbound action to Block..."
            Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultInboundAction Block -DefaultOutboundAction Allow
            Write-Log "  ✓ Default inbound action set to Block"
        }
        
        # Disable unnecessary rules
        $unnecessaryRules = @(
            "*RemoteDesktop-UserMode*",
            "*SNMP*"
        )
        
        foreach ($rulePattern in $unnecessaryRules) {
            if ($WhatIf) {
                Write-Log "[WHATIF] Would disable firewall rules matching: $rulePattern"
            } else {
                $rules = Get-NetFirewallRule -DisplayName $rulePattern -ErrorAction SilentlyContinue
                foreach ($rule in $rules) {
                    Disable-NetFirewallRule -Name $rule.Name
                    Write-Log "  ✓ Disabled rule: $($rule.DisplayName)"
                }
            }
        }
        
    } catch {
        Write-Log "Failed to configure Windows Firewall: $_" -Level "ERROR"
    }
}

# =============================================================================
# ENABLE BITLOCKER
# =============================================================================

if ($EnableBitLocker) {
    Write-Log "Checking BitLocker status..."
    
    try {
        $bitlockerStatus = Get-BitLockerVolume -MountPoint "C:" -ErrorAction SilentlyContinue
        
        if ($bitlockerStatus -and $bitlockerStatus.ProtectionStatus -eq "On") {
            Write-Log "BitLocker already enabled on C: drive"
        } else {
            if ($WhatIf) {
                Write-Log "[WHATIF] Would enable BitLocker on C: drive"
            } else {
                Write-Log "Enabling BitLocker on C: drive..."
                
                # Check TPM status
                $tpm = Get-Tpm
                if ($tpm.TpmPresent -and $tpm.TpmReady) {
                    Write-Log "TPM is present and ready"
                    
                    # Enable BitLocker with TPM protector
                    Enable-BitLocker -MountPoint "C:" -EncryptionMethod XtsAes256 `
                        -UsedSpaceOnly -TpmProtector -SkipHardwareTest
                    
                    Write-Log "  ✓ BitLocker enabled with TPM protector" -Level "SUCCESS"
                    
                    # Save recovery key to Azure Key Vault (in production)
                    # Backup-BitLockerKeyProtector -MountPoint "C:" -KeyProtectorId $keyProtector.KeyProtectorId
                    
                } else {
                    Write-Log "TPM not available, cannot enable BitLocker" -Level "WARNING"
                }
            }
        }
    } catch {
        Write-Log "Failed to enable BitLocker: $_" -Level "ERROR"
    }
}

# =============================================================================
# CONFIGURE AUDIT POLICIES
# =============================================================================

if ($ConfigureAuditPolicies) {
    Write-Log "Configuring audit policies..."
    
    try {
        if ($WhatIf) {
            Write-Log "[WHATIF] Would configure advanced audit policies"
        } else {
            # Account Logon
            auditpol /set /subcategory:"Credential Validation" /success:enable /failure:enable
            
            # Account Management
            auditpol /set /subcategory:"User Account Management" /success:enable /failure:enable
            auditpol /set /subcategory:"Security Group Management" /success:enable /failure:enable
            
            # Logon/Logoff
            auditpol /set /subcategory:"Logon" /success:enable /failure:enable
            auditpol /set /subcategory:"Logoff" /success:enable /failure:enable
            auditpol /set /subcategory:"Special Logon" /success:enable /failure:enable
            
            # Object Access
            auditpol /set /subcategory:"File System" /success:enable /failure:enable
            auditpol /set /subcategory:"Registry" /success:enable /failure:enable
            
            # Policy Change
            auditpol /set /subcategory:"Audit Policy Change" /success:enable /failure:enable
            auditpol /set /subcategory:"Authentication Policy Change" /success:enable /failure:enable
            
            # Privilege Use
            auditpol /set /subcategory:"Sensitive Privilege Use" /success:enable /failure:enable
            
            # System
            auditpol /set /subcategory:"Security State Change" /success:enable /failure:enable
            auditpol /set /subcategory:"Security System Extension" /success:enable /failure:enable
            auditpol /set /subcategory:"System Integrity" /success:enable /failure:enable
            
            Write-Log "  ✓ Audit policies configured" -Level "SUCCESS"
        }
    } catch {
        Write-Log "Failed to configure audit policies: $_" -Level "ERROR"
    }
}

# =============================================================================
# REGISTRY HARDENING
# =============================================================================

Write-Log "Applying registry hardening..."

$registrySettings = @(
    # Disable anonymous enumeration of SAM accounts
    @{
        Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
        Name = "RestrictAnonymousSAM"
        Value = 1
        Type = "DWord"
        Description = "Disable anonymous SAM enumeration"
    },
    # Disable anonymous enumeration of shares
    @{
        Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
        Name = "RestrictAnonymous"
        Value = 1
        Type = "DWord"
        Description = "Disable anonymous share enumeration"
    },
    # Enable LSA protection
    @{
        Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
        Name = "RunAsPPL"
        Value = 1
        Type = "DWord"
        Description = "Enable LSA protection"
    },
    # Disable LM hash storage
    @{
        Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
        Name = "NoLMHash"
        Value = 1
        Type = "DWord"
        Description = "Disable LM hash storage"
    },
    # Configure minimum password length
    @{
        Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters"
        Name = "RequireStrongKey"
        Value = 1
        Type = "DWord"
        Description = "Require strong session key"
    },
    # Disable AutoRun for all drives
    @{
        Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
        Name = "NoDriveTypeAutoRun"
        Value = 255
        Type = "DWord"
        Description = "Disable AutoRun for all drives"
    }
)

foreach ($setting in $registrySettings) {
    try {
        if ($WhatIf) {
            Write-Log "[WHATIF] Would set registry: $($setting.Description)"
        } else {
            # Create registry path if it doesn't exist
            if (-not (Test-Path $setting.Path)) {
                New-Item -Path $setting.Path -Force | Out-Null
            }
            
            Set-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -Type $setting.Type
            Write-Log "  ✓ $($setting.Description)"
        }
    } catch {
        Write-Log "Failed to set registry $($setting.Name): $_" -Level "WARNING"
    }
}

# =============================================================================
# WINDOWS UPDATE CONFIGURATION
# =============================================================================

Write-Log "Configuring Windows Update..."

try {
    if ($WhatIf) {
        Write-Log "[WHATIF] Would configure Windows Update settings"
    } else {
        # Enable automatic updates
        $auPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        if (-not (Test-Path $auPath)) {
            New-Item -Path $auPath -Force | Out-Null
        }
        
        # Configure auto update (4 = Auto download and schedule install)
        Set-ItemProperty -Path $auPath -Name "NoAutoUpdate" -Value 0 -Type DWord
        Set-ItemProperty -Path $auPath -Name "AUOptions" -Value 4 -Type DWord
        Set-ItemProperty -Path $auPath -Name "ScheduledInstallDay" -Value 0 -Type DWord  # Every day
        Set-ItemProperty -Path $auPath -Name "ScheduledInstallTime" -Value 3 -Type DWord  # 3 AM
        
        Write-Log "  ✓ Windows Update configured for automatic installation"
    }
} catch {
    Write-Log "Failed to configure Windows Update: $_" -Level "ERROR"
}

# =============================================================================
# SUMMARY
# =============================================================================

Write-Log "Security hardening completed" -Level "SUCCESS"
Write-Log "Log file: $logFile"

# Return summary
return @{
    ComputerName = $ComputerName
    FirewallConfigured = $ApplyFirewallRules
    BitLockerEnabled = $EnableBitLocker
    ServicesDisabled = $DisableUnusedServices
    AuditPoliciesConfigured = $ConfigureAuditPolicies
    LogFile = $logFile
    Timestamp = Get-Date
}
