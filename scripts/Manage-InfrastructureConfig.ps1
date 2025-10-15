# Infrastructure Configuration Manager
# Reads YAML configuration and manages infrastructure state detection

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "uat", "prod")]
    [string]$Environment,
    
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = "config\infrastructure-config.yaml",
    
    [Parameter(Mandatory=$false)]
    [switch]$ValidateOnly,
    
    [Parameter(Mandatory=$false)]
    [switch]$ShowConfig
)

# Import required modules
if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
    Write-Warning "Installing powershell-yaml module..."
    Install-Module -Name powershell-yaml -Force -AllowClobber
}
Import-Module powershell-yaml

# Colors for output
function Write-Header { param($Message) Write-Host "`n=== $Message ===" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }

function Read-InfrastructureConfig {
    param([string]$ConfigPath, [string]$Environment)
    
    Write-Info "Reading infrastructure configuration from: $ConfigPath"
    
    if (-not (Test-Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }
    
    try {
        $configContent = Get-Content -Path $ConfigPath -Raw
        $config = ConvertFrom-Yaml $configContent
        
        if (-not $config.environments.$Environment) {
            throw "Environment '$Environment' not found in configuration"
        }
        
        Write-Success "Configuration loaded successfully for environment: $Environment"
        return $config
    }
    catch {
        throw "Failed to parse configuration file: $($_.Exception.Message)"
    }
}

function Test-AzureResource {
    param(
        [string]$ResourceType,
        [string]$ResourceName,
        [string]$ResourceGroupName = $null,
        [string]$SubscriptionId
    )
    
    try {
        switch ($ResourceType) {
            "ResourceGroup" {
                $resource = az group show --name $ResourceName --subscription $SubscriptionId 2>$null
                return $resource -ne $null
            }
            "StorageAccount" {
                if ($ResourceGroupName) {
                    $resource = az storage account show --name $ResourceName --resource-group $ResourceGroupName --subscription $SubscriptionId 2>$null
                } else {
                    $resource = az storage account list --subscription $SubscriptionId --query "[?name=='$ResourceName']" 2>$null
                }
                return $resource -ne $null -and $resource -ne "[]"
            }
            "KeyVault" {
                $resource = az keyvault show --name $ResourceName --subscription $SubscriptionId 2>$null
                return $resource -ne $null
            }
            "VirtualNetwork" {
                $resource = az network vnet show --name $ResourceName --resource-group $ResourceGroupName --subscription $SubscriptionId 2>$null
                return $resource -ne $null
            }
            default {
                Write-Warning "Unknown resource type: $ResourceType"
                return $false
            }
        }
    }
    catch {
        return $false
    }
}

function Get-InfrastructureState {
    param($Config, [string]$Environment)
    
    Write-Header "Analyzing Infrastructure State for Environment: $Environment"
    
    $envConfig = $Config.environments.$Environment
    $subscriptionId = $Config.global.subscription_id
    
    $state = @{
        control_plane = @{}
        workload_zone = @{}
        vm_deployment = @{}
        actions_required = @()
    }
    
    # Check Control Plane Infrastructure
    Write-Info "Checking Control Plane infrastructure..."
    
    # Check Resource Group
    $rgExists = Test-AzureResource -ResourceType "ResourceGroup" -ResourceName $envConfig.control_plane.resource_group.name -SubscriptionId $subscriptionId
    $state.control_plane.resource_group_exists = $rgExists
    
    if ($rgExists) {
        Write-Success "✓ Resource Group exists: $($envConfig.control_plane.resource_group.name)"
    } else {
        Write-Warning "✗ Resource Group missing: $($envConfig.control_plane.resource_group.name)"
        if ($envConfig.control_plane.resource_group.create_new) {
            $state.actions_required += "Create Control Plane Resource Group"
        }
    }
    
    # Check Storage Account
    $saExists = Test-AzureResource -ResourceType "StorageAccount" -ResourceName $envConfig.control_plane.storage_account.name -ResourceGroupName $envConfig.control_plane.resource_group.name -SubscriptionId $subscriptionId
    $state.control_plane.storage_account_exists = $saExists
    
    if ($saExists) {
        Write-Success "✓ Storage Account exists: $($envConfig.control_plane.storage_account.name)"
    } else {
        Write-Warning "✗ Storage Account missing: $($envConfig.control_plane.storage_account.name)"
        if ($envConfig.control_plane.storage_account.create_new) {
            $state.actions_required += "Create Control Plane Storage Account"
        }
    }
    
    # Check Workload Zone Infrastructure
    Write-Info "Checking Workload Zone infrastructure..."
    
    $wlRgExists = Test-AzureResource -ResourceType "ResourceGroup" -ResourceName $envConfig.workload_zone.resource_group.name -SubscriptionId $subscriptionId
    $state.workload_zone.resource_group_exists = $wlRgExists
    
    if ($wlRgExists) {
        Write-Success "✓ Workload Zone Resource Group exists: $($envConfig.workload_zone.resource_group.name)"
    } else {
        Write-Warning "✗ Workload Zone Resource Group missing: $($envConfig.workload_zone.resource_group.name)"
        if ($envConfig.workload_zone.resource_group.create_new) {
            $state.actions_required += "Create Workload Zone Resource Group"
        }
    }
    
    # Check Virtual Network
    if ($wlRgExists) {
        $vnetExists = Test-AzureResource -ResourceType "VirtualNetwork" -ResourceName $envConfig.workload_zone.virtual_network.name -ResourceGroupName $envConfig.workload_zone.resource_group.name -SubscriptionId $subscriptionId
        $state.workload_zone.virtual_network_exists = $vnetExists
        
        if ($vnetExists) {
            Write-Success "✓ Virtual Network exists: $($envConfig.workload_zone.virtual_network.name)"
        } else {
            Write-Warning "✗ Virtual Network missing: $($envConfig.workload_zone.virtual_network.name)"
            $state.actions_required += "Create Workload Zone Virtual Network"
        }
    }
    
    return $state
}

function New-DeploymentPlan {
    param($Config, $State, [string]$Environment)
    
    Write-Header "Creating Deployment Plan"
    
    $plan = @{
        environment = $Environment
        phases = @()
        skip_control_plane = $false
        skip_workload_zone = $false
        terraform_commands = @()
    }
    
    # Determine what phases need to run
    if ($State.actions_required -contains "Create Control Plane Resource Group" -or 
        $State.actions_required -contains "Create Control Plane Storage Account") {
        $plan.phases += "control-plane"
        Write-Info "✓ Control Plane deployment required"
    } else {
        $plan.skip_control_plane = $true
        Write-Info "↷ Control Plane deployment will be skipped (infrastructure exists)"
    }
    
    if ($State.actions_required -contains "Create Workload Zone Resource Group" -or 
        $State.actions_required -contains "Create Workload Zone Virtual Network") {
        $plan.phases += "workload-zone"
        Write-Info "✓ Workload Zone deployment required"
    } else {
        Write-Info "✓ Workload Zone deployment recommended (configuration updates)"
        $plan.phases += "workload-zone"
    }
    
    # VM deployment is always included for now
    $plan.phases += "vm-deployment"
    Write-Info "✓ VM Deployment included"
    
    return $plan
}

# Main execution
try {
    Write-Header "Infrastructure Configuration Manager - Environment: $Environment"
    
    # Read configuration
    $config = Read-InfrastructureConfig -ConfigPath $ConfigPath -Environment $Environment
    
    if ($ShowConfig) {
        Write-Header "Configuration for Environment: $Environment"
        $config.environments.$Environment | ConvertTo-Json -Depth 10
        return
    }
    
    # Analyze current state
    $state = Get-InfrastructureState -Config $config -Environment $Environment
    
    # Create deployment plan
    $plan = New-DeploymentPlan -Config $config -State $state -Environment $Environment
    
    Write-Header "Deployment Plan Summary"
    Write-Info "Environment: $($plan.environment)"
    Write-Info "Phases to execute: $($plan.phases -join ', ')"
    Write-Info "Skip Control Plane: $($plan.skip_control_plane)"
    Write-Info "Skip Workload Zone: $($plan.skip_workload_zone)"
    
    if ($state.actions_required.Count -gt 0) {
        Write-Info "Actions required:"
        foreach ($action in $state.actions_required) {
            Write-Info "  • $action"
        }
    } else {
        Write-Success "No new infrastructure creation required"
    }
    
    if ($ValidateOnly) {
        Write-Success "Configuration validation completed successfully"
        return $plan
    }
    
    # Export plan for use by deployment script
    $planPath = "deploy\infrastructure-plan-$Environment.json"
    $plan | ConvertTo-Json -Depth 10 | Out-File -FilePath $planPath -Encoding UTF8
    Write-Success "Deployment plan saved to: $planPath"
    
    return $plan
}
catch {
    Write-Error "Configuration manager failed: $($_.Exception.Message)"
    exit 1
}