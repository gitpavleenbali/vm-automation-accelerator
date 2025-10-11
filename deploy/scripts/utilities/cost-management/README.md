# Cost Management Utilities

Tools for Azure cost optimization, quota management, and resource cost analysis.

## 📁 Contents

- **`cost_calculator.py`** - Python script for cost estimation and analysis
- **`quota_manager.py`** - Azure quota monitoring and management
- **`Validate-Quota.ps1`** - PowerShell quota validation and alerting

---

## 💰 `cost_calculator.py`

Calculates and analyzes Azure VM costs across subscriptions with detailed breakdowns.

**Features**:
- Real-time cost calculation using Azure Cost Management API
- Cost breakdown by resource, resource group, and subscription
- VM SKU pricing analysis
- Cost forecasting based on usage trends
- Budget variance analysis
- Export to CSV, JSON, or Excel
- Support for multiple subscriptions

**Installation**:
```bash
# Install dependencies
pip install azure-mgmt-costmanagement azure-identity pandas openpyxl

# Or use requirements file
pip install -r requirements.txt
```

**Usage**:
```bash
# Basic cost analysis
python cost_calculator.py \
    --subscription-id "12345678-1234-1234-1234-123456789abc" \
    --output costs.csv

# Multi-subscription with forecast
python cost_calculator.py \
    --subscription-ids "sub-1,sub-2,sub-3" \
    --forecast-days 30 \
    --output-format excel \
    --output costs.xlsx

# Cost breakdown by tag
python cost_calculator.py \
    --subscription-id "12345678-1234-1234-1234-123456789abc" \
    --group-by tag:Environment \
    --filter "tag:CostCenter eq 'Engineering'" \
    --output env_costs.json
```

**Parameters**:
- `--subscription-id` / `--subscription-ids`: Single or comma-separated subscription IDs
- `--resource-group`: Limit to specific resource group
- `--start-date`: Analysis start date (default: 30 days ago)
- `--end-date`: Analysis end date (default: today)
- `--forecast-days`: Number of days to forecast (0-90)
- `--group-by`: Group by resource, resource-group, tag:TagName
- `--filter`: OData filter expression
- `--output`: Output file path
- `--output-format`: csv, json, or excel (default: csv)
- `--budget-name`: Compare against specific budget

**Output**:
```json
{
  "summary": {
    "total_cost": 15234.56,
    "currency": "USD",
    "period": "2024-01-01 to 2024-01-31",
    "forecast_30d": 16500.00
  },
  "by_resource_group": [
    {
      "resource_group": "rg-prod-vms",
      "cost": 8500.00,
      "resources": 45,
      "avg_daily_cost": 274.19
    }
  ],
  "by_vm_sku": [
    {
      "sku": "Standard_D4s_v3",
      "count": 10,
      "total_cost": 5200.00,
      "avg_cost_per_vm": 520.00
    }
  ],
  "budget_analysis": {
    "budget_name": "prod-monthly-budget",
    "budget_amount": 20000.00,
    "consumed": 15234.56,
    "remaining": 4765.44,
    "percent_consumed": 76.17
  }
}
```

**Prerequisites**:
- Python 3.8+
- Azure authentication (Azure CLI, Managed Identity, or Service Principal)
- Cost Management Reader role on subscription(s)
- Required Python packages: `azure-mgmt-costmanagement`, `azure-identity`, `pandas`

**Authentication**:
```bash
# Azure CLI (for local execution)
az login

# Service Principal (for automation)
export AZURE_CLIENT_ID="<client-id>"
export AZURE_CLIENT_SECRET="<client-secret>"
export AZURE_TENANT_ID="<tenant-id>"
```

**Integration**:
```yaml
# Azure DevOps Pipeline
- task: PythonScript@0
  displayName: 'Calculate Monthly Costs'
  inputs:
    scriptSource: 'filePath'
    scriptPath: 'deploy/scripts/utilities/cost-management/cost_calculator.py'
    arguments: >
      --subscription-id $(subscriptionId)
      --output $(Build.ArtifactStagingDirectory)/costs.xlsx
      --output-format excel
      --forecast-days 30

- task: PublishBuildArtifacts@1
  inputs:
    pathToPublish: $(Build.ArtifactStagingDirectory)/costs.xlsx
    artifactName: 'cost-reports'
```

---

## 📊 `quota_manager.py`

Monitors and manages Azure resource quotas to prevent provisioning failures.

**Features**:
- Real-time quota usage monitoring
- Multi-region quota checking
- VM core quota analysis
- Network quota tracking (Public IPs, VNets, NSGs)
- Storage quota monitoring
- Quota increase recommendations
- Alert when approaching limits
- Historical quota usage tracking

**Installation**:
```bash
# Install dependencies
pip install azure-mgmt-compute azure-mgmt-network azure-identity

# Or use requirements file
pip install -r requirements.txt
```

**Usage**:
```bash
# Check all quotas in a region
python quota_manager.py \
    --subscription-id "12345678-1234-1234-1234-123456789abc" \
    --location "eastus" \
    --check-all

# Check specific VM family quotas
python quota_manager.py \
    --subscription-id "12345678-1234-1234-1234-123456789abc" \
    --location "eastus" \
    --vm-family "standardDSv3Family" \
    --threshold 80

# Generate quota increase recommendations
python quota_manager.py \
    --subscription-id "12345678-1234-1234-1234-123456789abc" \
    --location "eastus" \
    --recommend-increases \
    --output quota_recommendations.json
```

**Parameters**:
- `--subscription-id`: Azure subscription ID (required)
- `--location`: Azure region (required)
- `--check-all`: Check all quota types
- `--vm-family`: Specific VM family to check
- `--threshold`: Alert threshold percentage (default: 80)
- `--recommend-increases`: Generate quota increase recommendations
- `--output`: Output file for recommendations
- `--format`: Output format (json, csv, text)

**Output**:
```json
{
  "subscription_id": "12345678-1234-1234-1234-123456789abc",
  "location": "eastus",
  "timestamp": "2024-01-15T14:30:00Z",
  "quotas": [
    {
      "resource_type": "cores",
      "family": "standardDSv3Family",
      "limit": 100,
      "current_usage": 87,
      "available": 13,
      "usage_percent": 87.0,
      "status": "warning",
      "recommendation": "Consider requesting increase to 150 cores"
    },
    {
      "resource_type": "publicIPAddresses",
      "limit": 60,
      "current_usage": 45,
      "available": 15,
      "usage_percent": 75.0,
      "status": "ok"
    }
  ],
  "alerts": [
    {
      "severity": "warning",
      "resource": "standardDSv3Family cores",
      "message": "Usage at 87%, approaching limit of 100"
    }
  ]
}
```

**Prerequisites**:
- Python 3.8+
- Azure authentication
- Reader role on subscription
- Network Contributor role (for network quota checks)

**Integration**:
```yaml
# Pre-deployment quota validation
- task: PythonScript@0
  displayName: 'Validate Quota Availability'
  inputs:
    scriptSource: 'filePath'
    scriptPath: 'deploy/scripts/utilities/cost-management/quota_manager.py'
    arguments: >
      --subscription-id $(subscriptionId)
      --location $(location)
      --vm-family $(vmFamily)
      --threshold 85

# Fail deployment if quota insufficient
- script: |
    if grep -q '"status": "critical"' quota_check.json; then
      echo "##vso[task.logissue type=error]Insufficient quota for deployment"
      exit 1
    fi
  displayName: 'Check Quota Status'
```

---

## ✅ `Validate-Quota.ps1`

PowerShell script for quota validation with alerting and integration with Azure Monitor.

**Features**:
- Comprehensive quota validation
- Azure Monitor integration
- Email/Teams alerting
- Pre-deployment validation
- Quota usage history
- Automated quota requests (with approval workflow)
- Support for multiple subscriptions

**Usage**:
```powershell
# Validate VM core quota
.\Validate-Quota.ps1 `
    -SubscriptionId "12345678-1234-1234-1234-123456789abc" `
    -Location "eastus" `
    -ResourceType "cores" `
    -VMFamily "standardDSv3Family" `
    -RequiredAmount 50 `
    -Verbose

# Validate before deployment
.\Validate-Quota.ps1 `
    -SubscriptionId "12345678-1234-1234-1234-123456789abc" `
    -Location "eastus" `
    -DeploymentManifest "deployment.json" `
    -SendAlert `
    -AlertEmail "ops@contoso.com"

# Check all quotas and generate report
.\Validate-Quota.ps1 `
    -SubscriptionId "12345678-1234-1234-1234-123456789abc" `
    -Location "eastus" `
    -CheckAll `
    -GenerateReport `
    -OutputPath "C:\Reports\quota-report.html"
```

**Parameters**:
- `-SubscriptionId` (required): Azure subscription ID
- `-Location` (required): Azure region
- `-ResourceType`: Quota type (cores, publicIPs, vnets, etc.)
- `-VMFamily`: VM family for core quota check
- `-RequiredAmount`: Amount needed for deployment
- `-DeploymentManifest`: JSON file with deployment requirements
- `-CheckAll`: Validate all quota types
- `-ThresholdPercent`: Alert threshold (default: 80)
- `-SendAlert`: Send alert if threshold exceeded
- `-AlertEmail`: Email recipients for alerts
- `-TeamsWebhook`: Teams webhook URL for notifications
- `-GenerateReport`: Create HTML report
- `-OutputPath`: Report output path

**Deployment Manifest Example**:
```json
{
  "resources": [
    {
      "type": "virtualMachines",
      "sku": "Standard_D4s_v3",
      "count": 10,
      "cores": 4
    },
    {
      "type": "publicIPAddress",
      "count": 5
    }
  ]
}
```

**Prerequisites**:
- PowerShell 7.0+
- Azure PowerShell module (`Az`)
- Azure authentication (`Connect-AzAccount`)
- Reader role on subscription
- SendGrid API key (for email alerts) or Teams webhook URL

**Integration**:
```yaml
# Pre-deployment quota validation stage
- stage: ValidateQuota
  jobs:
  - job: CheckQuota
    steps:
    - task: AzurePowerShell@5
      displayName: 'Validate Deployment Quota'
      inputs:
        azureSubscription: $(azureServiceConnection)
        scriptType: 'FilePath'
        scriptPath: 'deploy/scripts/utilities/cost-management/Validate-Quota.ps1'
        scriptArguments: >
          -SubscriptionId $(subscriptionId)
          -Location $(location)
          -DeploymentManifest $(System.DefaultWorkingDirectory)/deployment-manifest.json
          -SendAlert
          -AlertEmail $(alertEmail)
        azurePowerShellVersion: 'LatestVersion'
        
    - script: |
        if ($LASTEXITCODE -ne 0) {
          Write-Host "##vso[task.logissue type=error]Quota validation failed"
          exit 1
        }
      displayName: 'Check Validation Result'

# Only proceed to deployment if quota validated
- stage: Deploy
  dependsOn: ValidateQuota
  condition: succeeded()
  jobs:
  - job: DeployInfrastructure
    steps:
    - template: templates/deploy-infrastructure.yml
```

**Alert Example**:
```
Subject: [ALERT] Azure Quota Threshold Exceeded

Subscription: Production (12345678-1234-1234-1234-123456789abc)
Region: East US
Resource: Standard DSv3 Family Cores

Current Usage: 87 of 100 cores (87%)
Threshold: 80%
Available: 13 cores

Upcoming Deployment Request: 50 cores
Status: INSUFFICIENT QUOTA

Action Required:
Request quota increase to at least 150 cores to accommodate upcoming deployment.

Recommendation:
Request increase to 200 cores to allow for future growth.
```

---

## 🔧 Common Prerequisites

### Azure Authentication
```bash
# Azure CLI
az login

# Service Principal
export AZURE_CLIENT_ID="<client-id>"
export AZURE_CLIENT_SECRET="<client-secret>"
export AZURE_TENANT_ID="<tenant-id>"
```

```powershell
# PowerShell
Connect-AzAccount

# Service Principal
$securePassword = ConvertTo-SecureString $env:AZURE_CLIENT_SECRET -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($env:AZURE_CLIENT_ID, $securePassword)
Connect-AzAccount -ServicePrincipal -Credential $credential -Tenant $env:AZURE_TENANT_ID
```

### Python Dependencies
```bash
# requirements.txt
azure-mgmt-costmanagement>=4.0.0
azure-mgmt-compute>=30.0.0
azure-mgmt-network>=23.0.0
azure-identity>=1.12.0
pandas>=2.0.0
openpyxl>=3.1.0
```

---

## 📈 Usage Patterns

### Pre-Deployment Validation
Always validate quotas before large deployments:
```yaml
stages:
- stage: PreDeploymentChecks
  jobs:
  - job: ValidateQuota
    steps:
    - task: PythonScript@0
      displayName: 'Check Quota Availability'
    - task: PowerShell@2
      displayName: 'Validate Against Deployment Plan'
      
- stage: Deploy
  dependsOn: PreDeploymentChecks
  condition: succeeded()
```

### Scheduled Cost Reporting
```yaml
# Run weekly cost analysis
schedules:
- cron: "0 8 * * 1"  # Monday 8 AM
  displayName: 'Weekly Cost Report'
  branches:
    include:
    - main

stages:
- stage: CostAnalysis
  jobs:
  - job: GenerateReport
    steps:
    - task: PythonScript@0
      inputs:
        scriptPath: 'deploy/scripts/utilities/cost-management/cost_calculator.py'
```

### Continuous Quota Monitoring
```yaml
# Run hourly quota checks
schedules:
- cron: "0 * * * *"  # Every hour
  displayName: 'Hourly Quota Monitor'
  
stages:
- stage: MonitorQuota
  jobs:
  - job: CheckUsage
    steps:
    - task: PythonScript@0
      inputs:
        scriptPath: 'deploy/scripts/utilities/cost-management/quota_manager.py'
```

---

## 🔗 Related Documentation

- [Main Utilities README](../README.md)
- [VM Operations](../vm-operations/README.md)
- [Azure Cost Management Documentation](https://learn.microsoft.com/azure/cost-management-billing/)
- [Azure Subscription Limits](https://learn.microsoft.com/azure/azure-resource-manager/management/azure-subscription-service-limits)

---

## 🤝 Contributing

When adding cost management scripts:
1. Include cost forecasting capabilities
2. Support multiple output formats
3. Implement proper error handling for API calls
4. Add alerting mechanisms
5. Document API rate limits
6. Include unit tests with mocked Azure responses
7. Support both interactive and automated execution
