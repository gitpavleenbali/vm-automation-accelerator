# VM Automation Accelerator - A-to-Z Deployment Guide

## Quick Start - Single Command Deployment

The `Deploy-VMAutomationAccelerator.ps1` script provides complete A-to-Z deployment automation for the entire 3-tier VM infrastructure.

### Prerequisites
- Azure CLI installed and authenticated (`az login`)
- Terraform installed (via winget or PATH)
- PowerShell 5.1+ or PowerShell Core 7+

## Usage Examples

### 🚀 **Complete Development Environment Deployment**
```powershell
# Deploy complete dev environment (Control Plane → Workload Zone → VMs)
.\Deploy-VMAutomationAccelerator.ps1 -Environment dev
```

### ✅ **Validation Only (No Deployment)**
```powershell
# Test all configurations without deploying resources
.\Deploy-VMAutomationAccelerator.ps1 -Environment prod -ValidateOnly
```

### 🧪 **Deploy and Auto-Cleanup (Testing)**
```powershell
# Deploy everything, then automatically destroy for testing
.\Deploy-VMAutomationAccelerator.ps1 -Environment dev -DestroyAfterValidation
```

### 🎯 **Partial Deployment (Skip Existing Components)**
```powershell
# Skip control plane and workload zone (deploy VMs only)
.\Deploy-VMAutomationAccelerator.ps1 -Environment uat -SkipControlPlane -SkipWorkloadZone
```

### 🌍 **Custom Location and Subscription**
```powershell
# Deploy to specific subscription and region
.\Deploy-VMAutomationAccelerator.ps1 -Environment prod -SubscriptionId "your-sub-id" -Location "westus2"
```

## Script Parameters

| Parameter | Required | Description | Default |
|-----------|----------|-------------|---------|
| `Environment` | ✅ | Target environment (dev, uat, prod) | - |
| `SubscriptionId` | ❌ | Azure subscription ID | Current subscription |
| `Location` | ❌ | Azure region | eastus |
| `ValidateOnly` | ❌ | Only validate, don't deploy | false |
| `DestroyAfterValidation` | ❌ | Auto-cleanup after deployment | false |
| `SkipControlPlane` | ❌ | Skip control plane deployment | false |
| `SkipWorkloadZone` | ❌ | Skip workload zone deployment | false |

## What the Script Does

### Phase 1: Control Plane Deployment
- ✅ Creates foundational resource groups
- ✅ Sets up Terraform state storage
- ✅ Establishes core networking
- ✅ Configures shared security policies

### Phase 2: Workload Zone Deployment  
- ✅ Deploys environment-specific VNets
- ✅ Creates subnets for 3-tier architecture
- ✅ Configures Network Security Groups
- ✅ Sets up load balancing and routing

### Phase 3: VM Deployment
- ✅ Provisions virtual machines (web, app, mgmt tiers)
- ✅ Configures SystemAssigned managed identity
- ✅ Attaches data disks and enables monitoring
- ✅ Validates VM health and connectivity

### Phase 4: Validation & Results
- ✅ Tests resource deployment status
- ✅ Validates VM agent and network connectivity
- ✅ Generates deployment results JSON
- ✅ Provides success/failure summary

## Script Output

### Success Example
```
=== VM Automation Accelerator - Complete A-to-Z Deployment ===
ℹ️  Environment: dev
ℹ️  Subscription: Visual Studio Enterprise Subscription
ℹ️  Location: eastus
ℹ️  Mode: Full Deployment

=== Validating Prerequisites ===
✅ Azure CLI authenticated - Subscription: Visual Studio Enterprise Subscription
✅ Terraform validated - Version: 1.5.0
✅ Configuration file validated: deploy\terraform\run\control-plane\terraform.tfvars.dev

=== Deploying Control-Plane ===
✅ Terraform initialized successfully
✅ Configuration validated successfully
✅ Changes detected for Control-Plane
✅ Control-Plane deployed successfully

=== Deployment Complete! 🎉 ===
✅ Total Duration: 00:08:45
✅ Environment: dev
✅ ControlPlane: Applied
✅ WorkloadZone: Applied
✅ VMDeployment: Applied
```

## Azure DevOps Pipeline Integration

The script is designed to integrate seamlessly with Azure DevOps pipelines:

```yaml
- task: PowerShell@2
  displayName: 'Execute A-to-Z Deployment'
  inputs:
    targetType: 'filePath'
    filePath: 'Deploy-VMAutomationAccelerator.ps1'
    arguments: '-Environment $(targetEnvironment) -ValidateOnly:$(validateOnly)'
```

## ServiceNow Integration

For production deployments, the pipeline includes ServiceNow change management:

```yaml
parameters:
- name: serviceNowTicket
  displayName: 'ServiceNow Change Ticket (Required for Prod)'
  type: string
```

## Troubleshooting

### Common Issues

#### Terraform Not Found
```
Solution: Ensure Terraform is installed or use winget:
winget install Hashicorp.Terraform
```

#### Azure CLI Not Authenticated
```
Solution: Login to Azure CLI:
az login
az account set --subscription "your-subscription-name"
```

#### Configuration File Missing
```
Solution: Ensure terraform.tfvars.[environment] exists:
- deploy/terraform/run/control-plane/terraform.tfvars.dev
- deploy/terraform/run/workload-zone/terraform.tfvars.dev  
- deploy/terraform/run/vm-deployment/terraform.tfvars.dev
```

#### Remote State Dependencies
```
Solution: Deploy in correct order or use skip parameters:
1. Control Plane (foundation)
2. Workload Zone (networking)
3. VM Deployment (applications)
```

## Next Steps for Tomorrow

1. ✅ **Test A-to-Z Script**: Validate complete deployment automation
2. ✅ **Setup Azure DevOps**: Configure project and service connections
3. ✅ **Deploy Pipeline**: Test multi-environment CI/CD workflow
4. ✅ **ServiceNow Integration**: Configure change management workflow
5. ✅ **Production Controls**: Implement approval gates and validation

The A-to-Z script provides the foundation for both manual deployments and automated pipeline execution, ensuring consistent and reliable infrastructure provisioning across all environments! 🚀