# VM Operations Utilities

Day-2 operational scripts for Azure VM management including monitoring, security, and compliance tasks.

## 📁 Contents

### Monitoring (`monitoring/`)
Agent installation scripts for setting up monitoring on provisioned VMs.

- **`install-agents-linux.sh`** - Installs Azure Monitor and Log Analytics agents on Linux VMs
- **`Install-Agents-Windows.ps1`** - Installs Azure Monitor and Log Analytics agents on Windows VMs

### Security (`security/`)
Security hardening and baseline enforcement scripts.

- **`Apply-SecurityHardening.ps1`** - Applies security baselines and CIS benchmarks to VMs

### Compliance (`compliance/`)
Compliance reporting and policy validation tools.

- **`Generate-ComplianceReport.ps1`** - Generates comprehensive compliance reports for Azure Policy

---

## 🎯 Monitoring Scripts

### `install-agents-linux.sh`

Installs monitoring agents on Linux VMs (Ubuntu/RHEL/CentOS).

**Features**:
- Azure Monitor Agent (AMA) installation
- Log Analytics workspace connection
- Dependency agent installation
- VM Insights configuration
- Support for Ubuntu 18.04+, RHEL 7+, CentOS 7+

**Usage**:
```bash
# Make executable
chmod +x install-agents-linux.sh

# Run with parameters
./install-agents-linux.sh \
    --workspace-id "<workspace-id>" \
    --workspace-key "<workspace-key>" \
    --vm-name "vm-linux-01"
```

**Parameters**:
- `--workspace-id`: Log Analytics workspace ID
- `--workspace-key`: Log Analytics workspace key
- `--vm-name`: Target VM name (for logging)
- `--skip-dependency-agent`: Optional, skip dependency agent installation

**Prerequisites**:
- Root or sudo access
- Internet connectivity for package downloads
- Azure Linux extension support

**Integration**:
```yaml
# Azure DevOps Pipeline
- task: Bash@3
  displayName: 'Install Monitoring Agents - Linux'
  inputs:
    filePath: 'deploy/scripts/utilities/vm-operations/monitoring/install-agents-linux.sh'
    arguments: '--workspace-id $(LAWorkspaceId) --workspace-key $(LAWorkspaceKey) --vm-name $(vmName)'
```

---

### `Install-Agents-Windows.ps1`

Installs monitoring agents on Windows Server VMs.

**Features**:
- Azure Monitor Agent (AMA) installation
- Log Analytics workspace connection
- Dependency agent installation
- VM Insights configuration
- Support for Windows Server 2016+

**Usage**:
```powershell
.\Install-Agents-Windows.ps1 `
    -WorkspaceId "<workspace-id>" `
    -WorkspaceKey "<workspace-key>" `
    -VMName "vm-win-01" `
    -Verbose
```

**Parameters**:
- `-WorkspaceId` (required): Log Analytics workspace ID
- `-WorkspaceKey` (required): Log Analytics workspace key
- `-VMName` (required): Target VM name
- `-SkipDependencyAgent` (optional): Skip dependency agent installation
- `-Verbose` (optional): Enable detailed logging

**Prerequisites**:
- Administrator privileges
- Internet connectivity
- PowerShell 5.1+ or PowerShell 7+
- Azure VM extension support

**Integration**:
```yaml
# Azure DevOps Pipeline
- task: PowerShell@2
  displayName: 'Install Monitoring Agents - Windows'
  inputs:
    filePath: 'deploy/scripts/utilities/vm-operations/monitoring/Install-Agents-Windows.ps1'
    arguments: >
      -WorkspaceId $(LAWorkspaceId)
      -WorkspaceKey $(LAWorkspaceKey)
      -VMName $(vmName)
```

---

## 🛡️ Security Scripts

### `Apply-SecurityHardening.ps1`

Applies security baselines and CIS benchmarks to Azure VMs.

**Features**:
- CIS benchmark compliance
- Security baseline enforcement
- Windows Firewall configuration
- Audit policy configuration
- Local security policy hardening
- Service hardening
- Registry security settings

**Usage**:
```powershell
.\Apply-SecurityHardening.ps1 `
    -ResourceGroupName "rg-prod-vms" `
    -VMName "vm-web-01" `
    -SecurityProfile "Production" `
    -Verbose
```

**Parameters**:
- `-ResourceGroupName` (required): Resource group name
- `-VMName` (required): Target VM name
- `-SecurityProfile` (required): Security profile (Development, Production, HighSecurity)
- `-ApplyCISBenchmark` (optional): Apply CIS benchmark settings
- `-GenerateReport` (optional): Generate before/after security report
- `-WhatIf` (optional): Preview changes without applying

**Security Profiles**:
1. **Development**: Basic security, developer-friendly
2. **Production**: Balanced security for production workloads
3. **HighSecurity**: Maximum security for sensitive workloads

**Prerequisites**:
- Azure PowerShell module installed
- Contributor or VM Contributor role on resource group
- Azure authentication (`Connect-AzAccount`)
- VM must be running

**Integration**:
```yaml
# Azure DevOps Pipeline
- task: AzurePowerShell@5
  displayName: 'Apply Security Hardening'
  inputs:
    azureSubscription: $(azureServiceConnection)
    scriptType: 'FilePath'
    scriptPath: 'deploy/scripts/utilities/vm-operations/security/Apply-SecurityHardening.ps1'
    scriptArguments: >
      -ResourceGroupName $(resourceGroup)
      -VMName $(vmName)
      -SecurityProfile Production
    azurePowerShellVersion: 'LatestVersion'
```

**Hardening Areas**:
- Account policies (password, lockout)
- Audit policies
- User rights assignments
- Security options
- Event log settings
- Network security
- Windows services
- Firewall rules

---

## 📊 Compliance Scripts

### `Generate-ComplianceReport.ps1`

Generates comprehensive compliance reports from Azure Policy data.

**Features**:
- Azure Policy compliance scanning
- Multi-subscription support
- Tag compliance validation
- Encryption status verification
- Backup configuration checks
- Multiple output formats (HTML, CSV, JSON)
- Email notification support

**Usage**:
```powershell
.\Generate-ComplianceReport.ps1 `
    -SubscriptionId "12345678-1234-1234-1234-123456789abc" `
    -OutputPath "C:\Reports" `
    -Format "HTML" `
    -EmailReport `
    -Recipients "compliance@contoso.com"
```

**Parameters**:
- `-SubscriptionId` (required): Azure subscription ID
- `-OutputPath` (required): Output directory for reports
- `-Format` (optional): Report format (HTML, CSV, JSON, All) - Default: HTML
- `-PolicySetName` (optional): Specific policy initiative to report on
- `-ResourceGroupName` (optional): Limit scope to specific resource group
- `-EmailReport` (optional): Send report via email
- `-Recipients` (optional): Email recipients (comma-separated)
- `-IncludeRemediation` (optional): Include remediation recommendations

**Output**:
The script generates:
1. Compliance summary report
2. Policy violation details
3. Resource compliance status
4. Remediation recommendations
5. Historical trend data (if available)

**Prerequisites**:
- Azure PowerShell module installed
- Reader access to subscription
- Azure Policy Contributor role (for remediation tasks)
- Azure authentication (`Connect-AzAccount`)
- SMTP configuration (for email reports)

**Integration**:
```yaml
# Azure DevOps Pipeline - Scheduled Compliance Reporting
- task: AzurePowerShell@5
  displayName: 'Generate Compliance Report'
  inputs:
    azureSubscription: $(azureServiceConnection)
    scriptType: 'FilePath'
    scriptPath: 'deploy/scripts/utilities/vm-operations/compliance/Generate-ComplianceReport.ps1'
    scriptArguments: >
      -SubscriptionId $(subscriptionId)
      -OutputPath $(Build.ArtifactStagingDirectory)
      -Format All
    azurePowerShellVersion: 'LatestVersion'

- task: PublishBuildArtifacts@1
  displayName: 'Publish Compliance Report'
  inputs:
    pathToPublish: $(Build.ArtifactStagingDirectory)
    artifactName: 'compliance-reports'
```

**Report Sections**:
1. **Executive Summary**: Overall compliance score and trends
2. **Policy Violations**: Detailed list of non-compliant resources
3. **Tag Compliance**: Missing or incorrect tags
4. **Security Compliance**: Encryption, backup, security settings
5. **Remediation Actions**: Recommended fixes with priority
6. **Resource Inventory**: Complete list of scanned resources

---

## 🔧 Common Prerequisites

### Azure Authentication
```powershell
# Interactive login
Connect-AzAccount

# Service principal login (for automation)
$securePassword = ConvertTo-SecureString $env:AZURE_CLIENT_SECRET -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($env:AZURE_CLIENT_ID, $securePassword)
Connect-AzAccount -ServicePrincipal -Credential $credential -Tenant $env:AZURE_TENANT_ID
```

### Azure PowerShell Module
```powershell
# Install
Install-Module -Name Az -Repository PSGallery -Force -AllowClobber

# Update
Update-Module -Name Az
```

### Log Analytics Workspace
Scripts require a configured Log Analytics workspace:
```powershell
# Get workspace details
$workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName "rg-monitoring" -Name "law-central"
$workspaceId = $workspace.CustomerId
$workspaceKey = (Get-AzOperationalInsightsWorkspaceSharedKeys -ResourceGroupName "rg-monitoring" -Name "law-central").PrimarySharedKey
```

---

## 📈 Usage Patterns

### Post-Deployment Automation
Run these scripts immediately after VM provisioning:
```yaml
# In your deployment pipeline
- stage: PostDeployment
  jobs:
  - job: ConfigureMonitoring
    steps:
    - task: PowerShell@2
      displayName: 'Install Monitoring - Windows'
      inputs:
        filePath: 'deploy/scripts/utilities/vm-operations/monitoring/Install-Agents-Windows.ps1'
        
  - job: ApplySecurity
    dependsOn: ConfigureMonitoring
    steps:
    - task: PowerShell@2
      displayName: 'Apply Security Hardening'
      inputs:
        filePath: 'deploy/scripts/utilities/vm-operations/security/Apply-SecurityHardening.ps1'
```

### Scheduled Compliance Scanning
```yaml
# Scheduled pipeline for nightly compliance reports
schedules:
- cron: "0 2 * * *"  # 2 AM daily
  displayName: 'Nightly Compliance Scan'
  branches:
    include:
    - main
  always: true

stages:
- stage: ComplianceScan
  jobs:
  - job: GenerateReports
    steps:
    - task: PowerShell@2
      displayName: 'Generate Compliance Report'
      inputs:
        filePath: 'deploy/scripts/utilities/vm-operations/compliance/Generate-ComplianceReport.ps1'
```

---

## 🔗 Related Documentation

- [Main Utilities README](../README.md)
- [Deployment Scripts](../../README.md)
- [Architecture Documentation](../../../../docs/ARCHITECTURE.md)
- [Contributing Guide](../../../../CONTRIBUTING.md)

---

## 🤝 Contributing

When adding VM operation scripts:
1. Follow the established naming conventions
2. Include comprehensive parameter validation
3. Add detailed help documentation
4. Support both interactive and pipeline execution
5. Include error handling and logging
6. Test on both Windows and Linux where applicable
7. Document integration patterns
