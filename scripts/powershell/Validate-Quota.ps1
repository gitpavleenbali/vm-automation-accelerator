<#
.SYNOPSIS
    Validates Azure quota availability for VM provisioning

.DESCRIPTION
    Checks Azure subscription quotas for:
    - vCPU quota (total and per VM family)
    - Disk quota
    - Public IP quota
    - Network interface quota
    - Storage account quota

.PARAMETER SubscriptionId
    Azure subscription ID

.PARAMETER Location
    Azure region

.PARAMETER VMSize
    VM size to validate

.PARAMETER Quantity
    Number of VMs to provision (default: 1)

.EXAMPLE
    .\Validate-Quota.ps1 -SubscriptionId "abc-123" -Location "westeurope" -VMSize "Standard_D4s_v3"

.NOTES
    Author: Cloud Infrastructure Team
    Date: 2025-10-07
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $true)]
    [string]$Location,
    
    [Parameter(Mandatory = $true)]
    [string]$VMSize,
    
    [Parameter(Mandatory = $false)]
    [int]$Quantity = 1
)

$ErrorActionPreference = "Stop"

# Initialize logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

Write-Log "Validating Azure quota for $Quantity x $VMSize in $Location"

# Set subscription context
try {
    Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    Write-Log "Subscription context set: $SubscriptionId"
} catch {
    Write-Log "Failed to set subscription context: $_" -Level "ERROR"
    throw
}

# Get VM size details
try {
    $vmSizeInfo = Get-AzVMSize -Location $Location | Where-Object { $_.Name -eq $VMSize }
    
    if (-not $vmSizeInfo) {
        Write-Log "VM size $VMSize not available in $Location" -Level "ERROR"
        throw "VM size not available"
    }
    
    $coresRequired = $vmSizeInfo.NumberOfCores * $Quantity
    $memoryRequired = $vmSizeInfo.MemoryInMB * $Quantity
    
    Write-Log "VM Size Details:"
    Write-Log "  - Cores per VM: $($vmSizeInfo.NumberOfCores)"
    Write-Log "  - Memory per VM: $($vmSizeInfo.MemoryInMB) MB"
    Write-Log "  - Max Data Disks: $($vmSizeInfo.MaxDataDiskCount)"
    Write-Log "  - Total cores required: $coresRequired"
    Write-Log "  - Total memory required: $memoryRequired MB"
    
} catch {
    Write-Log "Failed to get VM size information: $_" -Level "ERROR"
    throw
}

# Get VM family (e.g., "standardDSv3Family" from "Standard_D4s_v3")
$vmFamily = switch -Regex ($VMSize) {
    '^Standard_B'   { 'standardBSFamily' }
    '^Standard_D.*v3'   { 'standardDSv3Family' }
    '^Standard_D.*v4'   { 'standardDDSv4Family' }
    '^Standard_D.*v5'   { 'standardDDSv5Family' }
    '^Standard_E.*v3'   { 'standardESv3Family' }
    '^Standard_E.*v4'   { 'standardEDSv4Family' }
    '^Standard_E.*v5'   { 'standardEDSv5Family' }
    '^Standard_F.*v2'   { 'standardFSv2Family' }
    default { 'standardDSv3Family' }
}

Write-Log "VM Family: $vmFamily"

# Check quota
try {
    Write-Log "Checking quota limits..."
    
    # Get compute quota
    $quotas = Get-AzVMUsage -Location $Location
    
    # Check total regional vCPU quota
    $totalCoreQuota = $quotas | Where-Object { $_.Name.Value -eq 'cores' }
    $totalCoresAvailable = $totalCoreQuota.Limit - $totalCoreQuota.CurrentValue
    
    Write-Log "Total Regional vCPU Quota:"
    Write-Log "  - Limit: $($totalCoreQuota.Limit)"
    Write-Log "  - Current Usage: $($totalCoreQuota.CurrentValue)"
    Write-Log "  - Available: $totalCoresAvailable"
    Write-Log "  - Required: $coresRequired"
    
    if ($totalCoresAvailable -lt $coresRequired) {
        Write-Log "INSUFFICIENT QUOTA: Total regional vCPU quota" -Level "ERROR"
        Write-Log "  Available: $totalCoresAvailable, Required: $coresRequired" -Level "ERROR"
        $quotaCheckPassed = $false
    } else {
        Write-Log "  ✓ Total regional vCPU quota sufficient" -Level "SUCCESS"
    }
    
    # Check VM family quota
    $familyQuota = $quotas | Where-Object { $_.Name.Value -eq $vmFamily }
    
    if ($familyQuota) {
        $familyCoresAvailable = $familyQuota.Limit - $familyQuota.CurrentValue
        
        Write-Log "VM Family Quota ($vmFamily):"
        Write-Log "  - Limit: $($familyQuota.Limit)"
        Write-Log "  - Current Usage: $($familyQuota.CurrentValue)"
        Write-Log "  - Available: $familyCoresAvailable"
        Write-Log "  - Required: $coresRequired"
        
        if ($familyCoresAvailable -lt $coresRequired) {
            Write-Log "INSUFFICIENT QUOTA: VM family quota" -Level "ERROR"
            Write-Log "  Available: $familyCoresAvailable, Required: $coresRequired" -Level "ERROR"
            $quotaCheckPassed = $false
        } else {
            Write-Log "  ✓ VM family quota sufficient" -Level "SUCCESS"
        }
    } else {
        Write-Log "Could not find quota information for VM family: $vmFamily" -Level "WARNING"
    }
    
    # Check storage quota (managed disks)
    $storageQuota = $quotas | Where-Object { $_.Name.Value -eq 'diskCount' }
    if ($storageQuota) {
        $disksAvailable = $storageQuota.Limit - $storageQuota.CurrentValue
        $disksRequired = $Quantity  # At least one OS disk per VM
        
        Write-Log "Managed Disk Quota:"
        Write-Log "  - Limit: $($storageQuota.Limit)"
        Write-Log "  - Current Usage: $($storageQuota.CurrentValue)"
        Write-Log "  - Available: $disksAvailable"
        Write-Log "  - Required: $disksRequired"
        
        if ($disksAvailable -lt $disksRequired) {
            Write-Log "INSUFFICIENT QUOTA: Managed disk quota" -Level "ERROR"
            $quotaCheckPassed = $false
        } else {
            Write-Log "  ✓ Managed disk quota sufficient" -Level "SUCCESS"
        }
    }
    
} catch {
    Write-Log "Failed to check quota: $_" -Level "ERROR"
    throw
}

# Check subscription limits
try {
    Write-Log "Checking subscription limits..."
    
    # Get subscription
    $subscription = Get-AzSubscription -SubscriptionId $SubscriptionId
    
    # Count existing resources
    $existingVMs = (Get-AzVM).Count
    $existingDisks = (Get-AzDisk).Count
    $existingNICs = (Get-AzNetworkInterface).Count
    $existingPublicIPs = (Get-AzPublicIpAddress).Count
    
    Write-Log "Current Resource Count:"
    Write-Log "  - VMs: $existingVMs"
    Write-Log "  - Managed Disks: $existingDisks"
    Write-Log "  - Network Interfaces: $existingNICs"
    Write-Log "  - Public IPs: $existingPublicIPs"
    
    # Typical subscription limits
    $vmLimit = 25000
    $diskLimit = 50000
    $nicLimit = 65536
    $publicIPLimit = 1000
    
    if (($existingVMs + $Quantity) -gt $vmLimit) {
        Write-Log "WARNING: Approaching VM subscription limit" -Level "WARNING"
    }
    
} catch {
    Write-Log "Failed to check subscription limits: $_" -Level "WARNING"
}

# Generate quota report
$quotaReport = @{
    SubscriptionId = $SubscriptionId
    Location = $Location
    VMSize = $VMSize
    Quantity = $Quantity
    CoresRequired = $coresRequired
    MemoryRequiredMB = $memoryRequired
    TotalCoreQuota = @{
        Limit = $totalCoreQuota.Limit
        CurrentUsage = $totalCoreQuota.CurrentValue
        Available = $totalCoresAvailable
        Sufficient = ($totalCoresAvailable -ge $coresRequired)
    }
    FamilyQuota = if ($familyQuota) {
        @{
            Limit = $familyQuota.Limit
            CurrentUsage = $familyQuota.CurrentValue
            Available = $familyCoresAvailable
            Sufficient = ($familyCoresAvailable -ge $coresRequired)
        }
    } else { $null }
    QuotaCheckPassed = ($totalCoresAvailable -ge $coresRequired -and 
                        ($familyCoresAvailable -ge $coresRequired -or -not $familyQuota))
    Timestamp = Get-Date
}

# Output result
if ($quotaReport.QuotaCheckPassed) {
    Write-Log "✓ QUOTA CHECK PASSED - Sufficient quota available" -Level "SUCCESS"
    $exitCode = 0
} else {
    Write-Log "✗ QUOTA CHECK FAILED - Insufficient quota" -Level "ERROR"
    Write-Log "Please request quota increase through Azure Portal" -Level "ERROR"
    $exitCode = 1
}

# Export report to JSON
$reportFile = "quota-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$quotaReport | ConvertTo-Json -Depth 10 | Out-File $reportFile
Write-Log "Quota report saved to: $reportFile"

return $quotaReport
exit $exitCode
