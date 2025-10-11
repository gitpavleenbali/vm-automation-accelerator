# VM Compliance Reporting Scripts

This directory contains automated scripts for generating compliance reports for Azure VMs.

## Overview

These scripts audit and report on compliance status across multiple frameworks:
- Azure Policy compliance
- Security baseline adherence
- Regulatory framework alignment
- Configuration drift detection
- Remediation tracking

## Scripts

### Generate-ComplianceReport.ps1

**Purpose**: Generates comprehensive compliance reports for Azure VMs covering security configurations, policy adherence, and regulatory requirements.

**Supported OS Versions**:
- Windows Server 2016, 2019, 2022
- Windows 10, 11 (Enterprise/Pro)

**Prerequisites**:
- PowerShell 5.1 or later
- Azure PowerShell module (`Az.PolicyInsights`, `Az.Security`, `Az.Compute`)
- Reader permissions on target VMs
- Contributor permissions on Log Analytics workspace

**Usage**:
```powershell
.\deploy\scripts\utilities\vm-operations\compliance\Generate-ComplianceReport.ps1 `
  -SubscriptionId "<SUBSCRIPTION_ID>" `
  -ResourceGroupName "<RESOURCE_GROUP>" `
  -ComplianceFramework "<FRAMEWORK>" `
  -OutputPath "<REPORT_PATH>"
```

**Parameters**:
- `-SubscriptionId`: Azure subscription ID (required)
- `-ResourceGroupName`: Target resource group name (optional, default: all RGs in subscription)
- `-VMName`: Specific VM name (optional, default: all VMs in scope)
- `-ComplianceFramework`: Compliance framework to evaluate (required)
  - `AzureSecurityBenchmark`: Azure Security Benchmark v3
  - `CIS`: CIS Microsoft Azure Foundations Benchmark
  - `NIST800-53`: NIST 800-53 Rev 5
  - `ISO27001`: ISO/IEC 27001:2013
  - `HIPAA`: HIPAA Security Rule
  - `PCI-DSS`: PCI-DSS v3.2.1
  - `SOC2`: SOC 2 Type II
  - `All`: Generate reports for all frameworks

- `-OutputPath`: Directory path for report output (optional, default: `.\ComplianceReports\`)
- `-OutputFormat`: Report output format (optional, default: `HTML`)
  - `HTML`: Interactive HTML dashboard
  - `JSON`: Machine-readable JSON
  - `CSV`: CSV export for data analysis
  - `PDF`: Printable PDF report (requires wkhtmltopdf)
  - `All`: Generate all formats

- `-IncludeRemediation`: Include remediation steps in report (switch, optional)
- `-EmailReport`: Email report to recipients (switch, optional)
- `-EmailTo`: Email recipient addresses (required if `-EmailReport` specified)
- `-Detailed`: Include detailed configuration analysis (switch, optional)

**Example - Azure Security Benchmark Report**:
```powershell
.\deploy\scripts\utilities\vm-operations\compliance\Generate-ComplianceReport.ps1 `
  -SubscriptionId "12345678-1234-1234-1234-123456789012" `
  -ResourceGroupName "rg-production-vms" `
  -ComplianceFramework "AzureSecurityBenchmark" `
  -OutputPath "C:\ComplianceReports\" `
  -OutputFormat "HTML" `
  -IncludeRemediation
```

**Example - Multi-Framework Report for Specific VM**:
```powershell
.\deploy\scripts\utilities\vm-operations\compliance\Generate-ComplianceReport.ps1 `
  -SubscriptionId "12345678-1234-1234-1234-123456789012" `
  -ResourceGroupName "rg-production-vms" `
  -VMName "vm-app-server-01" `
  -ComplianceFramework "All" `
  -OutputPath "C:\ComplianceReports\" `
  -OutputFormat "All" `
  -Detailed
```

**Example - Email Report to Compliance Team**:
```powershell
.\deploy\scripts\utilities\vm-operations\compliance\Generate-ComplianceReport.ps1 `
  -SubscriptionId "12345678-1234-1234-1234-123456789012" `
  -ComplianceFramework "HIPAA" `
  -OutputPath "C:\ComplianceReports\" `
  -EmailReport `
  -EmailTo "compliance@company.com,security@company.com" `
  -IncludeRemediation
```

## Compliance Checks

The script evaluates VMs across multiple compliance domains:

### 1. Identity and Access Management
- **Azure AD integration**: VM joined to Azure AD
- **Role-based access control**: Appropriate RBAC assignments
- **JIT VM access**: Just-In-Time access configured
- **MFA enforcement**: Multi-factor authentication enabled
- **Privileged accounts**: No local admin credentials stored

### 2. Network Security
- **Network Security Groups**: NSG rules properly configured
- **Network isolation**: VM in appropriate subnet
- **DDoS protection**: Azure DDoS Protection enabled
- **Private endpoints**: No public IP addresses (where applicable)
- **Traffic encryption**: TLS/SSL enforced

### 3. Data Protection
- **Disk encryption**: Azure Disk Encryption enabled
- **Encryption at rest**: Customer-managed keys configured
- **Backup configuration**: Azure Backup enabled and tested
- **Data classification**: Tags reflect data sensitivity
- **Retention policies**: Backup retention meets requirements

### 4. Security Monitoring
- **Azure Monitor**: Monitoring agents installed
- **Log Analytics**: Connected to workspace
- **Security Center**: Azure Defender enabled
- **Vulnerability assessment**: VA solution deployed
- **Threat detection**: Advanced threat protection configured

### 5. Patch Management
- **Update Management**: Connected to Update Management
- **Patch compliance**: Critical updates installed within SLA
- **Reboot requirements**: Pending reboots tracked
- **Patch schedule**: Automatic updates configured

### 6. Configuration Management
- **Guest Configuration**: Azure Policy guest configuration enabled
- **Configuration drift**: No drift from baseline
- **Security baselines**: OS hardening applied
- **Audit settings**: Appropriate audit policies configured

### 7. Disaster Recovery
- **Site Recovery**: Azure Site Recovery configured
- **RTO/RPO**: Recovery objectives defined and tested
- **Failover testing**: Regular DR drills performed
- **Backup testing**: Restore testing completed

## Report Contents

### HTML Report Dashboard
Interactive dashboard includes:
- **Executive Summary**: Overall compliance score and status
- **Framework Overview**: Compliance by framework percentage
- **Control Status**: Pass/fail by control category
- **Trend Analysis**: Compliance over time (if historical data available)
- **Failed Controls**: Detailed list with remediation steps
- **Asset Inventory**: VM details with compliance status
- **Risk Assessment**: Risk scoring by control failure

### JSON Report Structure
```json
{
  "reportMetadata": {
    "generatedDate": "2024-01-15T10:30:00Z",
    "framework": "AzureSecurityBenchmark",
    "scope": "Subscription",
    "subscriptionId": "12345678-1234-1234-1234-123456789012"
  },
  "complianceSummary": {
    "totalControls": 150,
    "passedControls": 135,
    "failedControls": 15,
    "complianceScore": 90.0
  },
  "vmCompliance": [
    {
      "vmName": "vm-app-server-01",
      "resourceId": "/subscriptions/.../virtualMachines/vm-app-server-01",
      "complianceStatus": "NonCompliant",
      "failedControls": [
        {
          "controlId": "ASB-1.1",
          "controlName": "Enable Azure Disk Encryption",
          "status": "Failed",
          "remediation": "Apply disk encryption..."
        }
      ]
    }
  ]
}
```

## Integration with Deployment Pipeline

Compliance reporting integrated into CI/CD workflow:

1. **Scheduled Execution**: Daily/weekly compliance scans
2. **Pipeline Integration**: Post-deployment compliance gate
3. **ServiceNow Integration**: Non-compliant findings create SNOW tickets
4. **Azure Policy**: Automated remediation via Azure Policy
5. **Notification**: Email/Teams alerts on compliance failures

## Remediation Guidance

For common non-compliant findings:

### Disk Encryption Not Enabled
```powershell
# Enable Azure Disk Encryption
Set-AzVMDiskEncryptionExtension `
  -ResourceGroupName "rg-name" `
  -VMName "vm-name" `
  -DiskEncryptionKeyVaultUrl "https://kv-name.vault.azure.net/" `
  -DiskEncryptionKeyVaultId "/subscriptions/.../vaults/kv-name"
```

### Monitoring Agent Not Installed
```powershell
# Install monitoring agent
.\deploy\scripts\utilities\vm-operations\monitoring\Install-Agents-Windows.ps1 `
  -WorkspaceId "workspace-id" `
  -WorkspaceKey "workspace-key"
```

### Security Baseline Not Applied
```powershell
# Apply security hardening
.\deploy\scripts\utilities\vm-operations\security\Apply-SecurityHardening.ps1 `
  -Profile "AzureSecurityBaseline"
```

## Automation and Scheduling

Schedule automated compliance reporting:

```powershell
# Create scheduled task for daily compliance report
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-File C:\deploy\scripts\utilities\vm-operations\compliance\Generate-ComplianceReport.ps1 -SubscriptionId 'sub-id' -ComplianceFramework 'AzureSecurityBenchmark' -EmailReport -EmailTo 'compliance@company.com'"

$trigger = New-ScheduledTaskTrigger -Daily -At 6:00AM

Register-ScheduledTask -TaskName "DailyComplianceReport" -Action $action -Trigger $trigger -RunLevel Highest
```

## Troubleshooting

### Common Issues

**Problem**: Script fails with "Insufficient permissions"
```powershell
# Solution: Verify Azure RBAC assignments
Get-AzRoleAssignment -SignInName user@domain.com | Where-Object {$_.RoleDefinitionName -like "*Reader*"}
```

**Problem**: No data in report
```powershell
# Solution: Verify Log Analytics connectivity
Test-NetConnection -ComputerName <workspace-id>.ods.opinsights.azure.com -Port 443
```

**Problem**: PDF generation fails
```powershell
# Solution: Install wkhtmltopdf
choco install wkhtmltopdf -y
# Or download from: https://wkhtmltopdf.org/downloads.html
```

## Logs and Output

- **Execution Log**: `<OutputPath>\execution.log`
- **Error Log**: `<OutputPath>\errors.log`
- **Report Archive**: `<OutputPath>\Archive\<YYYY-MM-DD>\`

## Related Documentation

- [Azure Policy Compliance](../../../../../../docs/compliance/azure-policy.md)
- [Security Benchmark Mapping](../../../../../../docs/compliance/benchmark-mapping.md)
- [Remediation Playbooks](../../../../../../docs/compliance/remediation-playbooks.md)
- [Compliance Dashboard Guide](../../../../../../docs/compliance/dashboard-guide.md)
