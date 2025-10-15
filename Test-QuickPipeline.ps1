# Quick Pipeline Test Script
# Runs pipeline in validation mode for fast testing

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "uat", "prod")]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory=$false)]
    [switch]$FullDeployment
)

function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }

Write-Info "Quick Pipeline Test - Environment: $Environment"

if ($FullDeployment) {
    Write-Warning "Running FULL deployment - this will take 15+ minutes"
    $validateOnly = "false"
} else {
    Write-Success "Running VALIDATION ONLY mode - should complete in 2-3 minutes"
    $validateOnly = "true"
}

$command = "az pipelines run --name `"vm-automation-accelerator`" --project `"A-Z of Azure`" --organization `"https://dev.azure.com/azdopavleenbali/`" --parameters environment=$Environment deploymentScope=full workspacePrefix=vm-automation-$Environment autoApprove=true validateOnly=$validateOnly"

Write-Info "Executing command:"
Write-Host $command -ForegroundColor Gray

# Run the pipeline
try {
    $result = Invoke-Expression $command
    $runId = ($result | ConvertFrom-Json).id
    
    Write-Success "Pipeline started with ID: $runId"
    Write-Info "Monitor progress at: https://dev.azure.com/azdopavleenbali/A-Z%20of%20Azure/_build/results?buildId=$runId"
    
    # Monitor for first few minutes
    Write-Info "Monitoring initial progress..."
    for ($i = 1; $i -le 6; $i++) {
        Start-Sleep 30
        $status = az pipelines runs show --id $runId --project "A-Z of Azure" --organization "https://dev.azure.com/azdopavleenbali/" --query "{status:status, result:result}" -o json | ConvertFrom-Json
        Write-Info "Status: $($status.status) | Result: $($status.result)"
        
        if ($status.status -eq "completed") {
            if ($status.result -eq "succeeded") {
                Write-Success "Pipeline completed successfully!"
            } else {
                Write-Warning "Pipeline completed with result: $($status.result)"
            }
            break
        }
    }
    
    if ($i -gt 6) {
        Write-Info "Pipeline still running after 3 minutes. Check the Azure DevOps portal for detailed progress."
    }
}
catch {
    Write-Error "Failed to start pipeline: $_"
}

Write-Info "`nTo test different modes:"
Write-Host "  .\Test-QuickPipeline.ps1                    # Validation only (fast)"
Write-Host "  .\Test-QuickPipeline.ps1 -FullDeployment    # Full deployment (slow)"