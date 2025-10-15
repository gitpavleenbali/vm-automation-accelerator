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

# Infrastructure Configuration
$InfrastructureConfigPath = "config\infrastructure-config.yaml"
$InfrastructureManagerScript = "scripts\Manage-InfrastructureConfig.ps1"

# Colors for output
function Write-Header { param($Message) Write-Host "`n=== $Message ===" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }

# Infrastructure Analysis Function
function Get-InfrastructurePlan {
    param([string]$Environment)
    
    Write-Info "Analyzing infrastructure requirements using configuration manager..."
    
    if (-not (Test-Path $InfrastructureManagerScript)) {
        Write-Warning "Infrastructure manager script not found. Using default deployment approach."
        return $null
    }
    
    try {
        $plan = & $InfrastructureManagerScript -Environment $Environment -ValidateOnly
        return $plan
    }
    catch {
        Write-Warning "Failed to analyze infrastructure: $($_.Exception.Message)"
        Write-Warning "Falling back to default deployment approach."
        return $null
    }
}

# Load Infrastructure Configuration
function Get-InfrastructureConfig {
    param([string]$Environment)
    
    Write-Info "Loading infrastructure configuration for environment: $Environment"
    
    if (-not (Test-Path $InfrastructureConfigPath)) {
        throw "Infrastructure configuration file not found: $InfrastructureConfigPath"
    }
    
    try {
        # Import powershell-yaml if not available
        if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
            Write-Info "Installing powershell-yaml module..."
            Install-Module -Name powershell-yaml -Force -AllowClobber -Scope CurrentUser
        }
        Import-Module powershell-yaml -Force
        
        $configContent = Get-Content -Path $InfrastructureConfigPath -Raw
        $config = ConvertFrom-Yaml $configContent
        
        if (-not $config.environments.$Environment) {
            throw "Environment '$Environment' not found in infrastructure configuration"
        }
        
        Write-Success "Infrastructure configuration loaded successfully"
        return $config
    }
    catch {
        throw "Failed to load infrastructure configuration: $($_.Exception.Message)"
    }
}

# Deployment Configuration
$DeploymentConfig = @{
    RootPath = Get-Location
    ControlPlanePath = "deploy\terraform\run\control-plane"
    WorkloadZonePath = "deploy\terraform\run\workload-zone"  
    VMDeploymentPath = "deploy\terraform\run\vm-deployment"
    TerraformTimeout = 1800 # 30 minutes
    ProjectCode = "vmaut" # Project code for naming
}

# Find Terraform executable (handle multiple installation methods)
function Find-TerraformExecutable {
    Write-Info "Locating Terraform executable..."
    
    # Check if terraform is already in PATH
    $terraformCmd = Get-Command terraform -ErrorAction SilentlyContinue
    if ($terraformCmd) {
        Write-Success "Terraform found in PATH: $($terraformCmd.Source)"
        return $terraformCmd.Source
    }
    
    # Check user's terraform directory (our manual installation)
    $userTerraform = "$env:USERPROFILE\terraform\terraform.exe"
    if (Test-Path $userTerraform) {
        Write-Info "Adding user Terraform to PATH: $userTerraform"
        $env:PATH += ";$env:USERPROFILE\terraform"
        return $userTerraform
    }
    
    # Check common installation locations
    $commonPaths = @(
        "C:\Program Files\Terraform\terraform.exe",
        "C:\HashiCorp\Terraform\terraform.exe",
        "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\HashiCorp.Terraform*\terraform.exe"
    )
    
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            Write-Info "Found Terraform at: $path"
            $terraformDir = Split-Path $path -Parent
            $env:PATH += ";$terraformDir"
            return $path
        }
    }
    
    # If not found, install it
    Write-Warning "Terraform not found. Installing..."
    Install-Terraform
    return Find-TerraformExecutable
}

function Install-Terraform {
    Write-Info "Installing Terraform..."
    try {
        $terraformUrl = "https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_windows_amd64.zip"
        $tempPath = "$env:TEMP\terraform.zip"
        $extractPath = "$env:USERPROFILE\terraform"
        
        Write-Info "Downloading Terraform..."
        Invoke-WebRequest -Uri $terraformUrl -OutFile $tempPath
        
        Write-Info "Extracting Terraform..."
        New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
        Expand-Archive -Path $tempPath -DestinationPath $extractPath -Force
        
        Write-Info "Adding Terraform to PATH..."
        $env:PATH += ";$extractPath"
        
        Remove-Item $tempPath -Force
        Write-Success "Terraform installed successfully to: $extractPath"
    }
    catch {
        Write-Error "Failed to install Terraform: $($_.Exception.Message)"
        throw
    }
    
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
        # DIAGNOSTIC: Print all ARM-related environment variables for troubleshooting
        Write-Header "Authentication Environment Diagnostic"
        Write-Info "ARM_CLIENT_ID: $(if ($env:ARM_CLIENT_ID) { 'SET (***masked***)' } else { 'NOT SET' })"
        Write-Info "ARM_CLIENT_SECRET: $(if ($env:ARM_CLIENT_SECRET) { 'SET (***masked***)' } else { 'NOT SET' })"
        Write-Info "ARM_TENANT_ID: $(if ($env:ARM_TENANT_ID) { 'SET (***masked***)' } else { 'NOT SET' })"
        Write-Info "ARM_SUBSCRIPTION_ID: $(if ($env:ARM_SUBSCRIPTION_ID) { 'SET (***masked***)' } else { 'NOT SET' })"
        Write-Info "ARM_USE_CLI (before): $(if ($env:ARM_USE_CLI) { $env:ARM_USE_CLI } else { 'NOT SET' })"
        Write-Info "servicePrincipalId: $(if ($env:servicePrincipalId) { 'SET (***masked***)' } else { 'NOT SET' })"
        
        # In Azure DevOps pipeline, ensure ARM environment variables are preserved for Terraform
        # The AzureCLI task sets these, but PowerShell child processes need them explicitly
        if ($env:ARM_CLIENT_ID) {
            Write-Success "✓ ARM_CLIENT_ID detected - Running in Service Principal mode"
            $env:ARM_USE_CLI = "false"  # Force Service Principal mode when ARM_* vars are present
            Write-Success "✓ Set ARM_USE_CLI=false to force Service Principal authentication"
        }
        else {
            Write-Info "ℹ ARM_CLIENT_ID not detected - Running in local mode with Azure CLI authentication"
        }
        
        Write-Info "ARM_USE_CLI (after): $env:ARM_USE_CLI"
        Write-Header "End Authentication Diagnostic"
        
        # Initialize Terraform with proper backend configuration
        Write-Info "Initializing Terraform..."
        
        # Setup backend configuration for remote state
        $backendConfig = @()
        
        # Get current subscription for backend
        $currentSubscription = (az account show --query id -o tsv)
        
        # Load infrastructure configuration to get backend details
        $infraConfig = $script:InfrastructureConfig
        $envConfig = $infraConfig.environments.$Environment
        
        # Use configured backend details instead of hardcoded values
        $backendRgName = $envConfig.control_plane.resource_group.name
        $backendStorageName = $envConfig.control_plane.storage_account.name
        $containerName = $infraConfig.terraform_backend.container_name
        
        Write-Info "Using configured backend: $backendStorageName in $backendRgName"
        
        # Verify the existing backend infrastructure
        Write-Info "Verifying existing backend infrastructure..."
        $rgExists = az group exists --name $backendRgName
        if ($rgExists -eq "false") {
            throw "Backend resource group '$backendRgName' does not exist. Please ensure the infrastructure was created manually first."
        }
        
        $storageExists = az storage account show --name $backendStorageName --resource-group $backendRgName --query "name" -o tsv 2>$null
        if (-not $storageExists) {
            throw "Backend storage account '$backendStorageName' does not exist in '$backendRgName'. Please ensure the infrastructure was created manually first."
        }
        
        Write-Success "Backend infrastructure verified: $backendStorageName in $backendRgName"
        
        # Check if this is first-time deployment or existing state
        $stateKey = "$ComponentName.tfstate"
        Write-Info "Checking for existing state file: $stateKey"
        
        $existingState = $false
        try {
            # Try to check if state file exists (may fail due to network restrictions)
            az storage blob show --container-name $containerName --name $stateKey --account-name $backendStorageName --auth-mode login --query "name" -o tsv 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $existingState = $true
                Write-Info "Existing state file found - this is a subsequent deployment"
            }
        }
        catch {
            Write-Info "No existing state file found - this appears to be a first-time deployment"
        }
        
        # Configure backend parameters with Azure AD auth
        $backendConfig = @(
            "-backend-config=subscription_id=$currentSubscription",
            "-backend-config=resource_group_name=$backendRgName",
            "-backend-config=storage_account_name=$backendStorageName",
            "-backend-config=container_name=$containerName",
            "-backend-config=key=$stateKey",
            "-backend-config=use_azuread_auth=true"
        )
        
        # First attempt: Standard init with backend config
        $initArgs = @("init", "-upgrade") + $backendConfig
        Write-Info "Running: terraform $($initArgs -join ' ')"
        $initOutput = & $script:TerraformCmd $initArgs 2>&1
        
        # If backend configuration changed, reconfigure automatically
        if ($LASTEXITCODE -ne 0 -and $initOutput -match "Backend configuration changed") {
            Write-Warning "Backend configuration changed, reconfiguring..."
            $initArgs = @("init", "-reconfigure", "-upgrade") + $backendConfig
            $initOutput = & $script:TerraformCmd $initArgs 2>&1
        }
        
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform init failed: $initOutput"
        }
        Write-Success "Terraform initialized with remote backend: $backendStorageName"
        
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
        $planArgs = @("plan", "-var-file=$ConfigFile", "-out=$planFile", "-detailed-exitcode")
        
        # Detect authentication mode for logging only
        if ($env:servicePrincipalId -or $env:ARM_CLIENT_ID) {
            Write-Info "Running in Azure DevOps pipeline with Service Principal authentication"
        } else {
            Write-Info "Running locally with Azure CLI authentication"
        }
        
        Write-Info "Running: terraform $($planArgs -join ' ')"
        $planOutput = & $script:TerraformCmd $planArgs 2>&1
        
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
    
    # Load infrastructure configuration to get expected resource names
    $infraConfig = $script:InfrastructureConfig
    $envConfig = $infraConfig.environments.$Environment
    
    switch ($ComponentName) {
        "Control-Plane" {
            # Check if control plane resources exist using configured names
            $rgName = $envConfig.control_plane.resource_group.name
            $rg = az group show --name $rgName --query "id" -o tsv 2>$null
            if ($rg) {
                Write-Success "Control plane resource group validated: $rgName"
                
                # Validate storage account if configured to be created
                if ($envConfig.control_plane.storage_account.create) {
                    $storageName = $envConfig.control_plane.storage_account.name
                    $storage = az storage account show --name $storageName --resource-group $rgName --query "id" -o tsv 2>$null
                    if ($storage) {
                        Write-Success "Control plane storage account validated: $storageName"
                    } else {
                        throw "Control plane validation failed - storage account not found: $storageName"
                    }
                }
            } else {
                throw "Control plane validation failed - resource group not found: $rgName"
            }
        }
        
        "Workload-Zone" {
            # Check if workload zone networking exists using configured names
            $vnetName = $envConfig.workload_zone.network.virtual_network.name
            $rgName = $envConfig.workload_zone.resource_group.name
            $vnet = az network vnet show --name $vnetName --resource-group $rgName --query "id" -o tsv 2>$null
            if ($vnet) {
                Write-Success "Workload zone VNet validated: $vnetName in $rgName"
                
                # Validate key subnets exist
                $subnets = @('web', 'app', 'data', 'management')
                foreach ($subnet in $subnets) {
                    $subnetName = $envConfig.workload_zone.network.subnets.$subnet.name
                    $subnetCheck = az network vnet subnet show --name $subnetName --vnet-name $vnetName --resource-group $rgName --query "id" -o tsv 2>$null
                    if ($subnetCheck) {
                        Write-Success "Subnet validated: $subnetName"
                    } else {
                        Write-Warning "Subnet not found: $subnetName (may not be created yet)"
                    }
                }
            } else {
                throw "Workload zone validation failed - VNet not found: $vnetName in $rgName"
            }
        }
        
        "VM-Deployment" {
            # Check if VMs are running using configured resource group
            $rgName = $envConfig.vm_deployment.resource_group.name
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
    
    # Get infrastructure plan if configuration management is available
    $infrastructurePlan = Get-InfrastructurePlan -Environment $Environment
    
    if ($infrastructurePlan) {
        Write-Header "Infrastructure Analysis Results"
        Write-Info "Deployment will be optimized based on existing infrastructure"
        Write-Info "Skip Control Plane: $($infrastructurePlan.skip_control_plane)"
        Write-Info "Skip Workload Zone: $($infrastructurePlan.skip_workload_zone)"
        
        # Override parameters based on plan
        if ($infrastructurePlan.skip_control_plane -and -not $SkipControlPlane) {
            Write-Info "Automatically enabling -SkipControlPlane based on infrastructure analysis"
            $script:SkipControlPlane = $true
        }
    } else {
        Write-Info "Using default deployment approach (no infrastructure analysis available)"
    }
    
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
    
    # Initialize infrastructure configuration
    Write-Info "Loading infrastructure configuration..."
    $script:InfrastructureConfig = Get-InfrastructureConfig -Environment $Environment
    Write-Success "Infrastructure configuration loaded for environment: $Environment"
    
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