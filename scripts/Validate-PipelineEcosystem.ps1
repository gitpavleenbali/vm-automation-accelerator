# Pipeline Ecosystem Validation Script
# Validates all Azure DevOps pipeline files, templates, and dependencies

param(
    [Parameter(Mandatory=$false)]
    [switch]$FixIssues,
    
    [Parameter(Mandatory=$false)]
    [switch]$DetailedOutput
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Header { param($Message) Write-Host "`n=== $Message ===" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }

$ValidationResults = @{
    TotalFiles = 0
    ValidFiles = 0
    Issues = @()
    FixedIssues = @()
}

function Test-FileExists {
    param($FilePath, $Description)
    
    if (Test-Path $FilePath) {
        Write-Success "$Description exists: $FilePath"
        return $true
    } else {
        $issue = "Missing file: $FilePath ($Description)"
        Write-Error $issue
        $ValidationResults.Issues += $issue
        return $false
    }
}

function Test-YamlSyntax {
    param($FilePath)
    
    try {
        # Basic YAML syntax validation
        $content = Get-Content $FilePath -Raw
        
        # Check for common YAML issues
        $issues = @()
        
        # Check for tab characters (YAML should use spaces)
        if ($content -match "`t") {
            $issues += "Contains tab characters (use spaces instead)"
        }
        
        # Check for inconsistent indentation patterns
        $lines = $content -split "`n"
        $indentationPattern = $null
        foreach ($line in $lines) {
            if ($line -match "^(\s+)\w") {
                $indent = $matches[1]
                if ($indentationPattern -eq $null) {
                    $indentationPattern = $indent.Length
                } elseif ($indent.Length % $indentationPattern -ne 0) {
                    $issues += "Inconsistent indentation on line: $line"
                    break
                }
            }
        }
        
        # Check for template parameter syntax
        if ($content -match '\$\{\{\s*parameters\.[^}]+\}\}') {
            Write-Info "Template parameters found - validating syntax"
        }
        
        if ($issues.Count -eq 0) {
            Write-Success "YAML syntax valid: $FilePath"
            return $true
        } else {
            foreach ($issue in $issues) {
                $fullIssue = "${FilePath}: $issue"
                Write-Error $fullIssue
                $ValidationResults.Issues += $fullIssue
            }
            return $false
        }
    }
    catch {
        $issue = "${FilePath}: YAML syntax error - $($_.Exception.Message)"
        Write-Error $issue
        $ValidationResults.Issues += $issue
        return $false
    }
}

function Test-TemplateReferences {
    param($FilePath)
    
    $content = Get-Content $FilePath -Raw
    $templateRefs = [regex]::Matches($content, "template:\s*(.+\.yml)")
    
    foreach ($match in $templateRefs) {
        $templatePath = $match.Groups[1].Value.Trim()
        $fullPath = Join-Path (Split-Path $FilePath) $templatePath
        
        if (-not (Test-Path $fullPath)) {
            $issue = "${FilePath}: Referenced template not found: $templatePath"
            Write-Error $issue
            $ValidationResults.Issues += $issue
        } else {
            Write-Success "Template reference valid: $templatePath"
        }
    }
}

function Test-ScriptReferences {
    param($FilePath)
    
    $content = Get-Content $FilePath -Raw
    $scriptRefs = [regex]::Matches($content, "scriptPath:\s*['\`"]?([^'\`">\s]+)['\`"]?")
    
    foreach ($match in $scriptRefs) {
        $scriptPath = $match.Groups[1].Value.Trim()
        
        # Skip variable references
        if ($scriptPath -match '\$\(') {
            Write-Info "Variable script path found: $scriptPath"
            continue
        }
        
        $fullPath = Join-Path $PSScriptRoot $scriptPath
        
        if (-not (Test-Path $fullPath)) {
            $issue = "${FilePath}: Referenced script not found: $scriptPath"
            Write-Error $issue
            $ValidationResults.Issues += $issue
        } else {
            Write-Success "Script reference valid: $scriptPath"
        }
    }
}

function Test-PowerShellScript {
    param($FilePath)
    
    try {
        # Parse PowerShell syntax
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $FilePath -Raw), [ref]$null)
        Write-Success "PowerShell syntax valid: $FilePath"
        return $true
    }
    catch {
        $issue = "${FilePath}: PowerShell syntax error - $($_.Exception.Message)"
        Write-Error $issue
        $ValidationResults.Issues += $issue
        return $false
    }
}

function Fix-CommonIssues {
    param($FilePath, $Issues)
    
    if (-not $FixIssues) { return }
    
    Write-Warning "Attempting to fix issues in: $FilePath"
    
    $content = Get-Content $FilePath -Raw
    $modified = $false
    
    # Fix tab characters
    if ($content -match "`t") {
        $content = $content -replace "`t", "  "
        $modified = $true
        Write-Info "Fixed: Replaced tabs with spaces"
    }
    
    # Fix common template syntax issues
    if ($content -match '\$\{\{\s*parameters\.cleanupOnFailure\s*\}\}') {
        $content = $content -replace '\$\{\{\s*parameters\.cleanupOnFailure\s*\}\}', "'`${{ parameters.cleanupOnFailure }}' -eq 'True'"
        $modified = $true
        Write-Info "Fixed: PowerShell boolean template syntax"
    }
    
    if ($modified) {
        Set-Content $FilePath $content -NoNewline
        $ValidationResults.FixedIssues += $FilePath
        Write-Success "Fixed issues in: $FilePath"
    }
}

# Main validation process
Write-Header "Azure DevOps Pipeline Ecosystem Validation"

# 1. Validate main pipeline file
Write-Header "Validating Main Pipeline"
$mainPipeline = "deploy\pipelines\azure-devops\full-deployment-pipeline.yml"
if (Test-FileExists $mainPipeline "Main Pipeline") {
    $ValidationResults.TotalFiles++
    if (Test-YamlSyntax $mainPipeline) {
        Test-TemplateReferences $mainPipeline
        Test-ScriptReferences $mainPipeline
        $ValidationResults.ValidFiles++
    }
}

# 2. Validate templates
Write-Header "Validating Pipeline Templates"
$templates = @(
    "deploy\pipelines\azure-devops\templates\script-execution-template-windows.yml",
    "deploy\pipelines\azure-devops\templates\script-execution-template.yml",
    "deploy\pipelines\azure-devops\templates\terraform-validate-template.yml"
)

foreach ($template in $templates) {
    if (Test-FileExists $template "Template") {
        $ValidationResults.TotalFiles++
        if (Test-YamlSyntax $template) {
            $ValidationResults.ValidFiles++
        }
    }
}

# 3. Validate scripts
Write-Header "Validating Referenced Scripts"
$scripts = @(
    "Deploy-VMAutomationAccelerator.ps1"
)

foreach ($script in $scripts) {
    if (Test-FileExists $script "PowerShell Script") {
        $ValidationResults.TotalFiles++
        if (Test-PowerShellScript $script) {
            $ValidationResults.ValidFiles++
        }
    }
}

# 4. Validate other pipeline files (identify Windows compatibility issues)
Write-Header "Validating Other Pipeline Files"
$otherPipelines = @(
    "deploy\pipelines\azure-devops\control-plane-pipeline.yml",
    "deploy\pipelines\azure-devops\workload-zone-pipeline.yml",
    "deploy\pipelines\azure-devops\vm-deployment-pipeline.yml",
    "deploy\pipelines\azure-devops\vm-operations-pipeline.yml"
)

foreach ($pipeline in $otherPipelines) {
    if (Test-Path $pipeline) {
        $ValidationResults.TotalFiles++
        Write-Warning "Found additional pipeline: $pipeline"
        
        $content = Get-Content $pipeline -Raw
        if ($content -match "script-execution-template\.yml") {
            $issue = "${pipeline}: Uses bash template instead of Windows template"
            Write-Error $issue
            $ValidationResults.Issues += $issue
        }
        
        if ($content -match "deploy/scripts/.*\.sh") {
            $issue = "${pipeline}: References bash scripts (.sh) instead of PowerShell"
            Write-Error $issue
            $ValidationResults.Issues += $issue
        }
    }
}

# 5. Check for missing dependencies
Write-Header "Checking Dependencies"

# Check Terraform configurations
$terraformDirs = @(
    "deploy\terraform\run\control-plane",
    "deploy\terraform\run\workload-zone",
    "deploy\terraform\run\vm-deployment"
)

foreach ($dir in $terraformDirs) {
    if (-not (Test-Path $dir)) {
        $issue = "Missing Terraform directory: $dir"
        Write-Error $issue
        $ValidationResults.Issues += $issue
    } else {
        Write-Success "Terraform directory exists: $dir"
    }
}

# 6. Generate validation report
Write-Header "Validation Summary"
Write-Info "Total files validated: $($ValidationResults.TotalFiles)"
Write-Info "Valid files: $($ValidationResults.ValidFiles)"
Write-Info "Issues found: $($ValidationResults.Issues.Count)"

if ($ValidationResults.Issues.Count -eq 0) {
    Write-Success "🎉 All pipeline files are valid!"
} else {
    Write-Error "❌ Issues found:"
    foreach ($issue in $ValidationResults.Issues) {
        Write-Host "  - $issue" -ForegroundColor Red
    }
}

if ($ValidationResults.FixedIssues.Count -gt 0) {
    Write-Success "Fixed issues in:"
    foreach ($file in $ValidationResults.FixedIssues) {
        Write-Host "  - $file" -ForegroundColor Green
    }
}

# 7. Recommendations
Write-Header "Recommendations"
Write-Info "1. Use only the Windows-compatible template: script-execution-template-windows.yml"
Write-Info "2. All script references should point to PowerShell (.ps1) files"
Write-Info "3. Ensure self-hosted Windows agent is configured for pool: 'Default'"
Write-Info "4. Test pipeline locally using Azure CLI: az pipelines validate"

# Return exit code based on validation results
if ($ValidationResults.Issues.Count -eq 0) {
    exit 0
} else {
    Write-Warning "Run with -FixIssues to automatically fix common problems"
    exit 1
}