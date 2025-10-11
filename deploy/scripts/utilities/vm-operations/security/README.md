# VM Security Hardening Scripts

This directory contains automated scripts for applying security hardening configurations to Azure VMs.

## Overview

These scripts implement security best practices and compliance requirements including:
- CIS Benchmark configurations
- Azure Security Baseline
- Zero Trust network principles
- Encryption enforcement
- Access control hardening

## Scripts

### Apply-SecurityHardening.ps1

**Purpose**: Applies comprehensive security hardening configurations to Windows-based Azure VMs according to industry standards and organizational policies.

**Supported OS Versions**:
- Windows Server 2016, 2019, 2022
- Windows 10, 11 (Enterprise/Pro)

**Prerequisites**:
- PowerShell 5.1 or later
- Administrator privileges
- Internet connectivity for downloading security baselines
- Backup of VM recommended before applying hardening

**Usage**:
```powershell
.\deploy\scripts\utilities\vm-operations\security\Apply-SecurityHardening.ps1 `
  -Profile "<SECURITY_PROFILE>" `
  -ComplianceFramework "<FRAMEWORK>" `
  -ReportPath "<OUTPUT_PATH>"
```

**Parameters**:
- `-Profile`: Security hardening profile to apply (required)
  - `CISLevel1`: CIS Benchmark Level 1 (recommended for most workloads)
  - `CISLevel2`: CIS Benchmark Level 2 (high security environments)
  - `AzureSecurityBaseline`: Microsoft Azure Security Baseline
  - `Custom`: Load custom hardening profile from JSON file

- `-ComplianceFramework`: Target compliance framework (optional)
  - `NIST800-53`: NIST 800-53 controls
  - `ISO27001`: ISO 27001 security controls
  - `HIPAA`: HIPAA security requirements
  - `PCI-DSS`: PCI-DSS requirements

- `-ReportPath`: Path to save hardening report (optional, default: `C:\SecurityReports\`)

- `-CustomProfilePath`: Path to custom hardening JSON profile (required if `-Profile Custom`)

- `-DryRun`: Preview changes without applying (switch, optional)

- `-SkipReboot`: Skip automatic reboot after hardening (switch, optional)

**Example - CIS Level 1 Hardening**:
```powershell
.\deploy\scripts\utilities\vm-operations\security\Apply-SecurityHardening.ps1 `
  -Profile "CISLevel1" `
  -ComplianceFramework "NIST800-53" `
  -ReportPath "C:\SecurityReports\hardening-report.html"
```

**Example - Azure Security Baseline with Dry Run**:
```powershell
.\deploy\scripts\utilities\vm-operations\security\Apply-SecurityHardening.ps1 `
  -Profile "AzureSecurityBaseline" `
  -DryRun `
  -ReportPath "C:\SecurityReports\preview-report.html"
```

**Example - Custom Profile**:
```powershell
.\deploy\scripts\utilities\vm-operations\security\Apply-SecurityHardening.ps1 `
  -Profile "Custom" `
  -CustomProfilePath "C:\SecurityProfiles\custom-hardening.json" `
  -SkipReboot
```

## Security Hardening Categories

The script applies configurations across multiple security domains:

### 1. Account Policies
- Password complexity requirements
- Account lockout policies
- Credential caching limits
- Administrator account renaming

### 2. Audit Policies
- Logon/logoff event auditing
- Object access tracking
- Policy change monitoring
- Account management auditing

### 3. User Rights Assignment
- Privilege restrictions
- Remote access controls
- Service account permissions
- Deny network logon rights

### 4. Security Options
- Anonymous access restrictions
- Network authentication settings
- UAC configurations
- SMB hardening

### 5. Windows Firewall
- Inbound/outbound rules
- Profile-specific settings
- Logging configurations
- IPsec enforcement

### 6. System Services
- Unnecessary service disablement
- Service permission hardening
- Service account isolation

### 7. Network Security
- TLS/SSL enforcement
- SMB signing requirements
- LDAP channel binding
- NetBIOS disablement

## Integration with Deployment Pipeline

This script is integrated into the VM deployment workflow:

1. **Post-Deployment**: Automatically triggered after VM provisioning
2. **Terraform Integration**: Called via `remote-exec` provisioner
3. **Pipeline Stage**: Included in security validation stage
4. **ServiceNow Tracking**: Hardening status updated in SNOW tickets

## Hardening Report

The script generates a comprehensive HTML report including:
- Applied configurations summary
- Before/after settings comparison
- Compliance status by framework
- Failed configurations (if any)
- Remediation recommendations

**Report Location**: Default `C:\SecurityReports\hardening-report-<timestamp>.html`

## Validation and Verification

After hardening, verify configurations:

```powershell
# Check specific security settings
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name LimitBlankPasswordUse

# Verify firewall rules
Get-NetFirewallProfile -Profile Domain,Public,Private

# Review audit policies
auditpol /get /category:*

# Export applied GPO settings
secedit /export /cfg C:\SecurityReports\current-config.inf
```

## Rollback

If issues occur after hardening:

```powershell
# Restore from backup (if created)
Restore-Computer -RestorePoint "Pre-Hardening"

# Or reset specific policy
secedit /configure /cfg C:\Windows\security\templates\defltbase.inf /db defltbase.sdb /verbose
```

## Custom Profile Format

Create custom hardening profiles in JSON:

```json
{
  "profileName": "CustomHardening",
  "description": "Custom security hardening for application servers",
  "registrySettings": [
    {
      "path": "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Lsa",
      "name": "LimitBlankPasswordUse",
      "value": 1,
      "type": "DWord"
    }
  ],
  "auditPolicies": [
    {
      "subcategory": "Logon",
      "auditType": "Success,Failure"
    }
  ],
  "services": [
    {
      "name": "RemoteRegistry",
      "startupType": "Disabled"
    }
  ]
}
```

## Troubleshooting

### Common Issues

**Problem**: Script fails with "Access Denied"
```powershell
# Solution: Run as Administrator
Start-Process powershell -Verb RunAs
```

**Problem**: Some settings not applied
```powershell
# Solution: Check Group Policy precedence
gpresult /h C:\gpo-report.html
```

**Problem**: System unstable after hardening
```powershell
# Solution: Boot in Safe Mode and rollback
# Press F8 during boot, select Safe Mode with Command Prompt
secedit /configure /cfg C:\Windows\security\templates\defltbase.inf /db defltbase.sdb
```

## Logs

- **Execution Log**: `C:\SecurityReports\hardening-execution.log`
- **Error Log**: `C:\SecurityReports\hardening-errors.log`
- **Audit Log**: Windows Event Viewer > Security

## Related Documentation

- [Security Compliance Guide](../../../../../../docs/security/compliance-guide.md)
- [Azure Security Best Practices](../../../../../../docs/security/azure-security-best-practices.md)
- [VM Deployment Security](../../../../../../terraform-docs/SECURITY-GUIDE.md)
- [CIS Benchmarks Reference](../../../../../../docs/security/cis-benchmarks.md)
