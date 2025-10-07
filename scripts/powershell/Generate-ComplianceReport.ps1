<#
.SYNOPSIS
    Generates comprehensive compliance report for Your Organization Azure VMs.

.DESCRIPTION
    Queries Azure Policy compliance state and generates HTML report with:
    - Overall compliance summary
    - Policy-by-policy compliance breakdown
    - Non-compliant resources list
    - Compliance trends over time
    - Actionable remediation recommendations

.PARAMETER SubscriptionId
    Azure subscription ID to analyze.

.PARAMETER OutputPath
    Path where HTML report will be saved. Defaults to compliance-report-{timestamp}.html

.PARAMETER IncludeTrends
    Include 30-day compliance trend analysis.

.EXAMPLE
    .\Generate-ComplianceReport.ps1 -SubscriptionId "xxx-xxx" -OutputPath "report.html"

.NOTES
    Author: Cloud Governance Team
    Version: 1.0
    Requires: Az.PolicyInsights, Az.ResourceGraph modules
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "compliance-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').html",

    [Parameter(Mandatory = $false)]
    [switch]$IncludeTrends
)

# Import required modules
$requiredModules = @('Az.PolicyInsights', 'Az.ResourceGraph', 'Az.Resources')
foreach ($module in $requiredModules) {
    if (-not (Get-Module -Name $module -ListAvailable)) {
        Write-Error "Required module $module not found. Install with: Install-Module -Name $module"
        exit 1
    }
    Import-Module $module
}

# Set subscription context
Write-Host "Setting subscription context to $SubscriptionId..." -ForegroundColor Cyan
Set-AzContext -SubscriptionId $SubscriptionId | Out-Null

# Query policy compliance state
Write-Host "Querying policy compliance state..." -ForegroundColor Cyan

$query = @"
PolicyResources
| where type == 'microsoft.policyinsights/policystates'
| where properties.resourceType == 'Microsoft.Compute/virtualMachines'
| summarize 
    Total = count(),
    Compliant = countif(properties.complianceState == 'Compliant'),
    NonCompliant = countif(properties.complianceState == 'NonCompliant')
  by PolicyName = tostring(properties.policyDefinitionName)
| extend CompliancePercentage = round((Compliant * 100.0) / Total, 2)
| project PolicyName, Total, Compliant, NonCompliant, CompliancePercentage
| order by CompliancePercentage asc
"@

$complianceData = Search-AzGraph -Query $query -Subscription $SubscriptionId

# Get non-compliant resources
Write-Host "Identifying non-compliant resources..." -ForegroundColor Cyan

$nonCompliantQuery = @"
PolicyResources
| where type == 'microsoft.policyinsights/policystates'
| where properties.complianceState == 'NonCompliant'
| where properties.resourceType == 'Microsoft.Compute/virtualMachines'
| project 
    ResourceId = tostring(properties.resourceId),
    PolicyName = tostring(properties.policyDefinitionName),
    Reason = tostring(properties.complianceReasonCode),
    Timestamp = todatetime(properties.timestamp)
| order by Timestamp desc
| take 100
"@

$nonCompliantResources = Search-AzGraph -Query $nonCompliantQuery -Subscription $SubscriptionId

# Calculate overall compliance
$totalVMs = ($complianceData | Measure-Object -Property Total -Sum).Sum
$compliantVMs = ($complianceData | Measure-Object -Property Compliant -Sum).Sum
$nonCompliantVMs = ($complianceData | Measure-Object -Property NonCompliant -Sum).Sum
$overallCompliance = if ($totalVMs -gt 0) { [math]::Round(($compliantVMs / $totalVMs) * 100, 2) } else { 0 }

# Get compliance trends if requested
$trendData = $null
if ($IncludeTrends) {
    Write-Host "Analyzing compliance trends..." -ForegroundColor Cyan
    
    $trendQuery = @"
PolicyResources
| where type == 'microsoft.policyinsights/policystates'
| where properties.resourceType == 'Microsoft.Compute/virtualMachines'
| where todatetime(properties.timestamp) > ago(30d)
| summarize 
    Compliant = countif(properties.complianceState == 'Compliant'),
    NonCompliant = countif(properties.complianceState == 'NonCompliant')
  by bin(todatetime(properties.timestamp), 1d)
| extend CompliancePercentage = round((Compliant * 100.0) / (Compliant + NonCompliant), 2)
| project Date = format_datetime(properties_timestamp, 'yyyy-MM-dd'), CompliancePercentage
| order by Date asc
"@

    $trendData = Search-AzGraph -Query $trendQuery -Subscription $SubscriptionId
}

# Generate HTML report
Write-Host "Generating HTML report..." -ForegroundColor Cyan

$html = @"
<!DOCTYPE html>
<html>
<head>
    <title>VM Compliance Report</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 20px;
            background-color: #f5f5f5;
        }
        .header {
            background-color: #0078d4;
            color: white;
            padding: 20px;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        .summary {
            background-color: white;
            padding: 20px;
            border-radius: 5px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .metric {
            display: inline-block;
            margin: 10px 20px 10px 0;
        }
        .metric-value {
            font-size: 32px;
            font-weight: bold;
            color: #0078d4;
        }
        .metric-label {
            font-size: 14px;
            color: #666;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            background-color: white;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        th {
            background-color: #0078d4;
            color: white;
            padding: 12px;
            text-align: left;
        }
        td {
            padding: 10px;
            border-bottom: 1px solid #ddd;
        }
        tr:hover {
            background-color: #f5f5f5;
        }
        .compliant {
            color: green;
            font-weight: bold;
        }
        .non-compliant {
            color: red;
            font-weight: bold;
        }
        .status-ok {
            background-color: #d4edda;
            color: #155724;
            padding: 5px 10px;
            border-radius: 3px;
        }
        .status-warning {
            background-color: #fff3cd;
            color: #856404;
            padding: 5px 10px;
            border-radius: 3px;
        }
        .status-error {
            background-color: #f8d7da;
            color: #721c24;
            padding: 5px 10px;
            border-radius: 3px;
        }
        .recommendation {
            background-color: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 15px;
            margin: 10px 0;
            border-radius: 3px;
        }
        .footer {
            text-align: center;
            color: #666;
            margin-top: 40px;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>VM Compliance Report</h1>
        <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        <p>Subscription: $SubscriptionId</p>
    </div>

    <div class="summary">
        <h2>Overall Compliance Summary</h2>
        <div class="metric">
            <div class="metric-value">$overallCompliance%</div>
            <div class="metric-label">Overall Compliance</div>
        </div>
        <div class="metric">
            <div class="metric-value">$totalVMs</div>
            <div class="metric-label">Total VMs</div>
        </div>
        <div class="metric">
            <div class="metric-value compliant">$compliantVMs</div>
            <div class="metric-label">Compliant</div>
        </div>
        <div class="metric">
            <div class="metric-value non-compliant">$nonCompliantVMs</div>
            <div class="metric-label">Non-Compliant</div>
        </div>
    </div>

    <div class="summary">
        <h2>Policy Compliance Breakdown</h2>
        <table>
            <tr>
                <th>Policy Name</th>
                <th>Total VMs</th>
                <th>Compliant</th>
                <th>Non-Compliant</th>
                <th>Compliance %</th>
                <th>Status</th>
            </tr>
"@

foreach ($policy in $complianceData) {
    $status = if ($policy.CompliancePercentage -ge 90) { "status-ok" } elseif ($policy.CompliancePercentage -ge 70) { "status-warning" } else { "status-error" }
    $statusText = if ($policy.CompliancePercentage -ge 90) { "Good" } elseif ($policy.CompliancePercentage -ge 70) { "Warning" } else { "Critical" }
    
    $html += @"
            <tr>
                <td>$($policy.PolicyName)</td>
                <td>$($policy.Total)</td>
                <td class="compliant">$($policy.Compliant)</td>
                <td class="non-compliant">$($policy.NonCompliant)</td>
                <td>$($policy.CompliancePercentage)%</td>
                <td><span class="$status">$statusText</span></td>
            </tr>
"@
}

$html += @"
        </table>
    </div>

    <div class="summary">
        <h2>Non-Compliant Resources (Top 100)</h2>
        <table>
            <tr>
                <th>Resource ID</th>
                <th>Policy Name</th>
                <th>Reason</th>
                <th>Timestamp</th>
            </tr>
"@

foreach ($resource in $nonCompliantResources) {
    $vmName = ($resource.ResourceId -split '/')[-1]
    $timestamp = Get-Date $resource.Timestamp -Format 'yyyy-MM-dd HH:mm'
    
    $html += @"
            <tr>
                <td>$vmName</td>
                <td>$($resource.PolicyName)</td>
                <td>$($resource.Reason)</td>
                <td>$timestamp</td>
            </tr>
"@
}

$html += @"
        </table>
    </div>
"@

# Add trend data if available
if ($trendData) {
    $html += @"
    <div class="summary">
        <h2>30-Day Compliance Trend</h2>
        <table>
            <tr>
                <th>Date</th>
                <th>Compliance %</th>
            </tr>
"@

    foreach ($trend in $trendData) {
        $html += @"
            <tr>
                <td>$($trend.Date)</td>
                <td>$($trend.CompliancePercentage)%</td>
            </tr>
"@
    }

    $html += @"
        </table>
    </div>
"@
}

# Add recommendations
$html += @"
    <div class="summary">
        <h2>Remediation Recommendations</h2>
"@

if ($overallCompliance -lt 90) {
    $html += @"
        <div class="recommendation">
            <strong>Priority:</strong> Overall compliance is below 90%. Review non-compliant resources and create remediation plan.
        </div>
"@
}

foreach ($policy in ($complianceData | Where-Object { $_.CompliancePercentage -lt 70 })) {
    $html += @"
        <div class="recommendation">
            <strong>Policy:</strong> $($policy.PolicyName)<br>
            <strong>Issue:</strong> Compliance is at $($policy.CompliancePercentage)% (below 70% threshold)<br>
            <strong>Action:</strong> Review $($policy.NonCompliant) non-compliant VMs and implement remediation.
        </div>
"@
}

$html += @"
    </div>

    <div class="footer">
        <p>Cloud Governance Team | cloud-governance@Your Organization.com</p>
        <p>For questions or assistance, create a ServiceNow ticket under "Cloud Governance" category</p>
    </div>
</body>
</html>
"@

# Save report
$html | Out-File -FilePath $OutputPath -Encoding UTF8

Write-Host "`nCompliance report generated successfully!" -ForegroundColor Green
Write-Host "Report saved to: $OutputPath" -ForegroundColor Cyan
Write-Host "`nSummary:" -ForegroundColor Yellow
Write-Host "  Overall Compliance: $overallCompliance%" -ForegroundColor $(if ($overallCompliance -ge 90) { "Green" } else { "Red" })
Write-Host "  Total VMs: $totalVMs"
Write-Host "  Compliant: $compliantVMs" -ForegroundColor Green
Write-Host "  Non-Compliant: $nonCompliantVMs" -ForegroundColor Red

# Open report in default browser
if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
    Start-Process $OutputPath
}
