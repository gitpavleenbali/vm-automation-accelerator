# Azure DevOps Service Connections Setup
# VM Automation Accelerator

## Azure Account Information
- **Subscription ID**: `37ffd444-46e0-41dd-9e4b-f12857262095`
- **Subscription Name**: `ME-MngEnvMCAP852047-pavleenbali-1`
- **Tenant ID**: `f1755a38-88fd-47a4-a2e9-5c2019dc2535`

## Account Scenario
- **Azure DevOps Account**: Different email address
- **Azure Subscription Account**: admin@MngEnvMCAP852047.onmicrosoft.com
- **Recommended Method**: App registration or Managed Service Identity (manual)

## Service Connections to Create

### 1. Development Environment
- **Connection Name**: `azure-vm-automation-dev`
- **Connection Type**: Azure Resource Manager
- **Authentication**: App registration or Managed Service Identity (manual)
- **Scope**: Subscription
- **Subscription ID**: 37ffd444-46e0-41dd-9e4b-f12857262095
- **Tenant ID**: f1755a38-88fd-47a4-a2e9-5c2019dc2535
- **App Registration**: vm-automation-dev-sp

### 2. UAT Environment  
- **Connection Name**: `azure-vm-automation-uat`
- **Connection Type**: Azure Resource Manager
- **Authentication**: App registration or Managed Service Identity (manual)
- **Scope**: Subscription
- **Subscription ID**: 37ffd444-46e0-41dd-9e4b-f12857262095
- **Tenant ID**: f1755a38-88fd-47a4-a2e9-5c2019dc2535
- **App Registration**: vm-automation-uat-sp

### 3. Production Environment
- **Connection Name**: `azure-vm-automation-prod`
- **Connection Type**: Azure Resource Manager
- **Authentication**: App registration or Managed Service Identity (manual)
- **Scope**: Subscription
- **Subscription ID**: 37ffd444-46e0-41dd-9e4b-f12857262095
- **Tenant ID**: f1755a38-88fd-47a4-a2e9-5c2019dc2535
- **App Registration**: vm-automation-prod-sp

## Setup Steps in Azure DevOps Portal

1. Navigate to: https://dev.azure.com/azdopavleenbali/A-Z%20of%20Azure/_settings/adminservices
2. Click "Service connections" in the left menu
3. Click "New service connection" 
4. Select "Azure Resource Manager"
5. Choose "Service principal (automatic)"
6. Enter the connection details above
7. Click "Save"
8. Repeat for all three environments

## Verification Commands

After creating the connections, verify with:

```powershell
# List all service connections
az devops service-endpoint list --project "A-Z of Azure" --query "[].{name:name, type:type, isReady:isReady}" -o table

# Test specific connection
az devops service-endpoint show --id <connection-id> --project "A-Z of Azure"
```

## Required Permissions

Each service connection will automatically create a Service Principal with:
- **Contributor** role on the subscription
- Ability to create and manage resources
- Access to deploy Terraform infrastructure

## Next Steps After Creation

1. ✅ Verify all three connections are created and authorized
2. ➡️ Create pipeline environments (dev, uat, prod)
3. ➡️ Setup variable groups with environment-specific values
4. ➡️ Configure pipelines to use these connections