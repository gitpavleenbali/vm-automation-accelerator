# VM Automation Accelerator - Complete A-to-Z Deployment Script
# This script orchestrates the entire deployment from Control Plane to VMs

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "uat", "prod")]
    [string]$Environment,
    
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory=$false)]
    [switch]$ValidateOnly,
    
    [Parameter(Mandatory=$false)]
    [switch]$DestroyAfterValidation,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipControlPlane,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipWorkloadZone
)

# Global Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"

# Colors for output
function Write-Header { param($Message) Write-Host "`n=== $Message ===" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }

# Deployment Configuration
$DeploymentConfig = @{
    RootPath = Get-Location
    ControlPlanePath = "deploy\terraform\run\control-plane"
    WorkloadZonePath = "deploy\terraform\run\workload-zone"  
    VMDeploymentPath = "deploy\terraform\run\vm-deployment"
    TerraformTimeout = 1800 # 30 minutes
}

# Find Terraform executable (handle winget installation)
function Find-TerraformExecutable {
    Write-Info "Locating Terraform executable..."
    
    # Try standard PATH first
    $terraformCmd = Get-Command terraform -ErrorAction SilentlyContinue
    if ($terraformCmd) {
        Write-Success "Found Terraform in PATH: $($terraformCmd.Source)"
        return "terraform"
    }
    
    # Check winget installation location
    $wingetPath = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Hashicorp.Terraform*\terraform.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($wingetPath) {
        Write-Success "Found Terraform via winget: $($wingetPath.FullName)"
        return $wingetPath.FullName
    }
    
    throw "Terraform executable not found. Please install Terraform or ensure it's in PATH."
}

# Validate prerequisites
function Test-Prerequisites {
    Write-Header "Validating Prerequisites"
    
    # Check Azure CLI authentication
    try {
        $account = az account show --query "{subscriptionId: id, tenantId: tenantId, name: name}" -o json | ConvertFrom-Json
        Write-Success "Azure CLI authenticated - Subscription: $($account.name)"
        
        if ($SubscriptionId -and $account.subscriptionId -ne $SubscriptionId) {
            Write-Info "Setting subscription to: $SubscriptionId"
            az account set --subscription $SubscriptionId
        }
    }
    catch {
        throw "Azure CLI not authenticated. Please run 'az login' first."
    }
    
    # Find and validate Terraform
    $script:TerraformCmd = Find-TerraformExecutable
    
    # Test Terraform
    $tfVersion = & $script:TerraformCmd version -json | ConvertFrom-Json
    Write-Success "Terraform validated - Version: $($tfVersion.terraform_version)"
    
    # Check required configuration files
    $requiredFiles = @(
        "$($DeploymentConfig.ControlPlanePath)\terraform.tfvars.$Environment",
        "$($DeploymentConfig.WorkloadZonePath)\terraform.tfvars.$Environment", 
        "$($DeploymentConfig.VMDeploymentPath)\terraform.tfvars.$Environment"
    )
    
    foreach ($file in $requiredFiles) {
        if (-not (Test-Path $file)) {
            throw "Required configuration file not found: $file"
        }
        Write-Success "Configuration file validated: $file"
    }
}

# Execute Terraform operations with error handling
function Invoke-TerraformDeploy {
    param(
        [string]$WorkingDirectory,
        [string]$ConfigFile,
        [string]$ComponentName,
        [switch]$PlanOnly
    )
    
    Write-Header "Deploying $ComponentName"
    Write-Info "Working Directory: $WorkingDirectory"
    Write-Info "Configuration: $ConfigFile"
    
    Push-Location $WorkingDirectory
    
    try {
        # Initialize Terraform
        Write-Info "Initializing Terraform..."
        $initOutput = & $script:TerraformCmd init -upgrade 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform init failed: $initOutput"
        }
        Write-Success "Terraform initialized successfully"
        
        # Validate configuration
        Write-Info "Validating configuration..."
        $validateOutput = & $script:TerraformCmd validate 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform validation failed: $validateOutput"
        }
        Write-Success "Configuration validated successfully"
        
        # Create execution plan
        Write-Info "Creating execution plan..."
        $planFile = "$ComponentName-$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss').tfplan"
        $planOutput = & $script:TerraformCmd plan -var-file=$ConfigFile -out=$planFile -detailed-exitcode 2>&1
        
        switch ($LASTEXITCODE) {
            0 { 
                Write-Success "No changes required for $ComponentName"
                return @{ Status = "NoChanges"; PlanFile = $planFile }
            }
            1 { 
                throw "Terraform plan failed: $planOutput"
            }
            2 { 
                Write-Success "Changes detected for $ComponentName"
                
                if ($PlanOnly -or $ValidateOnly) {
                    Write-Info "Plan-only mode - skipping apply"
                    return @{ Status = "PlanReady"; PlanFile = $planFile }
                }
                
                # Apply changes
                Write-Info "Applying changes..."
                $applyOutput = & $script:TerraformCmd apply -auto-approve $planFile 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw "Terraform apply failed: $applyOutput"
                }
                Write-Success "$ComponentName deployed successfully"
                return @{ Status = "Applied"; PlanFile = $planFile }
            }
        }
    }
    catch {
        Write-Error "Failed to deploy $ComponentName`: $_"
        throw
    }
    finally {
        Pop-Location
    }
}

# Validate deployment by checking resources
function Test-DeploymentValidation {
    param([string]$ComponentName)
    
    Write-Info "Validating $ComponentName deployment..."
    
    switch ($ComponentName) {
        "Control-Plane" {
            # Check if control plane resources exist
            $rgName = "rg-vmaut-controlplane-$($Location.Substring(0,3))-shared"
            $rg = az group show --name $rgName --query "id" -o tsv 2>$null
            if ($rg) {
                Write-Success "Control plane resource group validated: $rgName"
            } else {
                throw "Control plane validation failed - resource group not found: $rgName"
            }
        }
        
        "Workload-Zone" {
            # Check if workload zone networking exists
            $vnetName = "vnet-vmaut-$Environment-$($Location.Substring(0,3))"
            $rgName = "rg-vmaut-workloadzone-$($Location.Substring(0,3))-shared"
            $vnet = az network vnet show --name $vnetName --resource-group $rgName --query "id" -o tsv 2>$null
            if ($vnet) {
                Write-Success "Workload zone VNet validated: $vnetName"
            } else {
                throw "Workload zone validation failed - VNet not found: $vnetName"
            }
        }
        
        "VM-Deployment" {
            # Check if VMs are running
            $rgName = "rg-vmaut-$Environment-$($Location.Substring(0,3))-compute"
            $vms = az vm list --resource-group $rgName --query "[].{Name:name, Status:powerState}" -o json 2>$null | ConvertFrom-Json
            if ($vms -and $vms.Count -gt 0) {
                Write-Success "VM deployment validated - $($vms.Count) VMs found in $rgName"
                foreach ($vm in $vms) {
                    Write-Info "VM: $($vm.Name) - Status: $($vm.Status)"
                }
            } else {
                throw "VM deployment validation failed - no VMs found in $rgName"
            }
        }
    }
}

# Cleanup deployment (for testing)
function Remove-Deployment {
    param([string]$ComponentName, [string]$WorkingDirectory, [string]$ConfigFile)
    
    Write-Header "Destroying $ComponentName"
    Push-Location $WorkingDirectory
    
    try {
        Write-Info "Destroying $ComponentName infrastructure..."
        $destroyOutput = & $script:TerraformCmd destroy -var-file=$ConfigFile -auto-approve 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Destroy failed for $ComponentName`: $destroyOutput"
        } else {
            Write-Success "$ComponentName destroyed successfully"
        }
    }
    catch {
        Write-Warning "Error during $ComponentName destruction: $_"
    }
    finally {
        Pop-Location
    }
}

# Main deployment orchestration
function Start-FullDeployment {
    Write-Header "VM Automation Accelerator - Complete A-to-Z Deployment"
    Write-Info "Environment: $Environment"
    Write-Info "Subscription: $(az account show --query name -o tsv)"
    Write-Info "Location: $Location"
    Write-Info "Mode: $(if ($ValidateOnly) { 'Validation Only' } else { 'Full Deployment' })"
    
    $deploymentResults = @{}
    $startTime = Get-Date
    
    try {
        # Phase 1: Control Plane
        if (-not $SkipControlPlane) {
            $deploymentResults["ControlPlane"] = Invoke-TerraformDeploy `
                -WorkingDirectory $DeploymentConfig.ControlPlanePath `
                -ConfigFile "terraform.tfvars.$Environment" `
                -ComponentName "Control-Plane" `
                -PlanOnly:$ValidateOnly
            
            if (-not $ValidateOnly) {
                Test-DeploymentValidation -ComponentName "Control-Plane"
            }
        }
        
        # Phase 2: Workload Zone
        if (-not $SkipWorkloadZone) {
            $deploymentResults["WorkloadZone"] = Invoke-TerraformDeploy `
                -WorkingDirectory $DeploymentConfig.WorkloadZonePath `
                -ConfigFile "terraform.tfvars.$Environment" `
                -ComponentName "Workload-Zone" `
                -PlanOnly:$ValidateOnly
            
            if (-not $ValidateOnly) {
                Test-DeploymentValidation -ComponentName "Workload-Zone"
            }
        }
        
        # Phase 3: VM Deployment
        $deploymentResults["VMDeployment"] = Invoke-TerraformDeploy `
            -WorkingDirectory $DeploymentConfig.VMDeploymentPath `
            -ConfigFile "terraform.tfvars.$Environment" `
            -ComponentName "VM-Deployment" `
            -PlanOnly:$ValidateOnly
        
        if (-not $ValidateOnly) {
            Test-DeploymentValidation -ComponentName "VM-Deployment"
        }
        
        # Cleanup if requested
        if ($DestroyAfterValidation -and -not $ValidateOnly) {
            Write-Header "Cleaning Up Resources (DestroyAfterValidation enabled)"
            
            Remove-Deployment "VM-Deployment" $DeploymentConfig.VMDeploymentPath "terraform.tfvars.$Environment"
            Remove-Deployment "Workload-Zone" $DeploymentConfig.WorkloadZonePath "terraform.tfvars.$Environment"  
            Remove-Deployment "Control-Plane" $DeploymentConfig.ControlPlanePath "terraform.tfvars.$Environment"
        }
        
        # Success summary
        $duration = (Get-Date) - $startTime
        Write-Header "Deployment Complete! 🎉"
        Write-Success "Total Duration: $($duration.ToString('hh\:mm\:ss'))"
        Write-Success "Environment: $Environment"
        
        foreach ($component in $deploymentResults.Keys) {
            Write-Success "$component`: $($deploymentResults[$component].Status)"
        }
        
        if (-not $ValidateOnly) {
            Write-Info "You can now access your 3-tier VM infrastructure in Azure portal"
            Write-Info "Resource groups created for $Environment environment in $Location region"
        }
        
        return $deploymentResults
    }
    catch {
        Write-Error "Deployment failed: $_"
        Write-Info "Check the error details above and run with -ValidateOnly to test configuration"
        throw
    }
}

# Script entry point
try {
    Test-Prerequisites
    $results = Start-FullDeployment
    
    # Export results for pipeline integration
    $resultsPath = "deployment-results-$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $results | ConvertTo-Json -Depth 10 | Out-File $resultsPath
    Write-Success "Deployment results saved to: $resultsPath"
    
    exit 0
}
catch {
    Write-Error "Script execution failed: $_"
    exit 1
}