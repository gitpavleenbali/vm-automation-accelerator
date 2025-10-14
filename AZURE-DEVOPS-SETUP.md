# Azure DevOps Project Setup Guide
# VM Automation Accelerator

## Step 1: Create Azure DevOps Organization
1. Navigate to: https://dev.azure.com
2. Sign in with: admin@MngEnvMCAP852047.onmicrosoft.com
3. Click "Create new organization"
4. **Suggested Name**: `vm-automation-devops`
5. **URL will be**: `https://dev.azure.com/vm-automation-devops/`
6. Select region: East US (to match your Azure resources)

## Step 2: Create Project
Once organization is created:
1. Click "Create project"
2. **Project Name**: `VM-Automation-Accelerator`
3. **Visibility**: Private
4. **Version Control**: Git
5. **Work Item Process**: Agile

## Step 3: Configure CLI Access
After project creation, run these commands:

```powershell
# Configure Azure DevOps CLI with your new organization
az devops configure --defaults organization=https://dev.azure.com/vm-automation-devops/

# Configure default project
az devops configure --defaults project=VM-Automation-Accelerator

# Test connection
az devops project show --project VM-Automation-Accelerator
```

## Step 4: Repository Setup
1. In the project, go to "Repos"
2. Choose "Import repository"
3. **Source Type**: Git
4. **Clone URL**: This local repository will be pushed

## Step 5: Service Connections (Next Task)
- Azure Resource Manager connection for each environment
- Service Principal authentication
- Subscription access for deployments

## Step 6: Variable Groups (Next Task)
- `vm-automation-dev-vars` (Development environment)
- `vm-automation-uat-vars` (UAT environment) 
- `vm-automation-prod-vars` (Production environment)

## Step 7: Environments (Next Task)
- **dev**: Automatic deployment
- **uat**: Manual approval
- **prod**: Manual approval + ServiceNow integration

## Ready Files in Repository:
✅ Main CI/CD Pipeline: `.azuredevops/pipelines/vm-automation-ci-cd.yml`
✅ Component Pipelines: `deploy/pipelines/azure-devops/`
✅ Terraform Configurations: `deploy/terraform/run/`
✅ A-to-Z Deployment Script: `Deploy-VMAutomationAccelerator.ps1`

## Next Steps After Organization Creation:
Once you've created the organization and project, come back and we'll:
1. Configure service connections
2. Set up pipeline variables
3. Create environments with approval gates
4. Import and configure pipelines
5. Test the complete CI/CD workflow