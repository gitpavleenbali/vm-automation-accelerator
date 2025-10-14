# Quick Pipeline Fix Script
# Updates all pipeline files to use Windows-compatible templates and scripts

param(
    [Parameter(Mandatory=$false)]
    [switch]$Apply
)

function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }

$fixes = @()

# Pipeline files that need Windows compatibility updates
$pipelineFiles = @(
    "deploy\pipelines\azure-devops\control-plane-pipeline.yml",
    "deploy\pipelines\azure-devops\workload-zone-pipeline.yml", 
    "deploy\pipelines\azure-devops\vm-deployment-pipeline.yml"
)

foreach ($file in $pipelineFiles) {
    if (Test-Path $file) {
        Write-Info "Analyzing: $file"
        $content = Get-Content $file -Raw
        $modified = $false
        
        # Fix 1: Replace bash template with Windows template
        if ($content -match "templates/script-execution-template\.yml") {
            $content = $content -replace "templates/script-execution-template\.yml", "templates/script-execution-template-windows.yml"
            $fixes += "${file}: Updated to use Windows template"
            $modified = $true
        }
        
        # Fix 2: Replace bash script references with PowerShell
        if ($content -match "deploy/scripts/deploy_control_plane\.sh") {
            $content = $content -replace "deploy/scripts/deploy_control_plane\.sh", "Deploy-VMAutomationAccelerator.ps1"
            $fixes += "${file}: Updated control plane script reference"
            $modified = $true
        }
        
        if ($content -match "deploy/scripts/deploy_workload_zone\.sh") {
            $content = $content -replace "deploy/scripts/deploy_workload_zone\.sh", "Deploy-VMAutomationAccelerator.ps1" 
            $fixes += "${file}: Updated workload zone script reference"
            $modified = $true
        }
        
        if ($content -match "deploy/scripts/deploy_vm\.sh") {
            $content = $content -replace "deploy/scripts/deploy_vm\.sh", "Deploy-VMAutomationAccelerator.ps1"
            $fixes += "${file}: Updated VM deployment script reference"
            $modified = $true
        }
        
        # Fix 3: Update pool configuration to use Windows agent
        if ($content -match "vmImage:\s*'ubuntu-latest'") {
            $content = $content -replace "vmImage:\s*'ubuntu-latest'", "name: 'Default'"
            $fixes += "${file}: Updated pool to use self-hosted Windows agent"
            $modified = $true
        }
        
        if ($modified -and $Apply) {
            Set-Content $file $content -NoNewline
            Write-Success "Fixed: $file"
        } elseif ($modified) {
            Write-Warning "Would fix: $file (use -Apply to make changes)"
        }
    }
}

Write-Info "`nSummary of fixes:"
foreach ($fix in $fixes) {
    Write-Host "  - $fix" -ForegroundColor Yellow
}

if (-not $Apply) {
    Write-Warning "`nRun with -Apply to make these changes"
} else {
    Write-Success "`nAll fixes applied!"
}