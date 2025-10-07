# VM Governance & Monitoring Automation

This directory contains governance policies, compliance dashboards, and automation scripts for managing Azure VM infrastructure at scale.

## 📁 Directory Structure

```
governance/
├── policies/                          # Azure Policy definitions
│   ├── require-encryption-at-host.json
│   ├── require-mandatory-tags.json
│   ├── enforce-naming-convention.json
│   ├── require-azure-backup.json
│   ├── restrict-vm-sku-sizes.json
│   └── policy-initiative.json        # Policy initiative bundling all policies
│
└── dashboards/                        # Azure Portal dashboards
    ├── vm-compliance-dashboard.json
    └── vm-cost-dashboard.json
```

## 🛡️ Azure Policies

### 1. **Require Encryption at Host**
- **File**: `require-encryption-at-host.json`
- **Purpose**: Ensures all VMs have encryption at host enabled
- **Effect**: Audit | Deny | Disabled (default: Audit)
- **Compliance**: Meets Your Organization data protection standards

### 2. **Require Mandatory Tags**
- **File**: `require-mandatory-tags.json`
- **Purpose**: Enforces required tags on all VMs
- **Required Tags**:
  - `Environment` (dev, uat, prod)
  - `CostCenter` (for chargeback)
  - `Owner` (responsible person/team)
  - `Application` (application name)
- **Effect**: Audit | Deny | Disabled (default: Audit)

### 3. **Enforce Naming Convention**
- **File**: `enforce-naming-convention.json`
- **Purpose**: Enforces VM naming standard
- **Pattern**: `[env]-vm-[app]-[region]-[###]`
- **Examples**:
  - `prod-vm-sap-weu-001`
  - `uat-vm-webapp-neu-002`
  - `dev-vm-api-eus-003`
- **Effect**: Audit | Deny | Disabled (default: Audit)

### 4. **Require Azure Backup**
- **File**: `require-azure-backup.json`
- **Purpose**: Ensures production VMs are protected by Azure Backup
- **Scope**: All VMs except those tagged with `Environment: dev`
- **Effect**: AuditIfNotExists | Disabled (default: AuditIfNotExists)

### 5. **Restrict VM SKU Sizes**
- **File**: `restrict-vm-sku-sizes.json`
- **Purpose**: Limits VM sizes to approved list for cost optimization
- **Approved SKUs**:
  - B-series: B2s, B2ms, B4ms
  - D-series v3: D2s_v3, D4s_v3, D8s_v3, D16s_v3
  - E-series v3: E2s_v3, E4s_v3, E8s_v3, E16s_v3
  - F-series v2: F2s_v2, F4s_v2, F8s_v2
- **Effect**: Audit | Deny | Disabled (default: Audit)

### 6. **Policy Initiative**
- **File**: `policy-initiative.json`
- **Purpose**: Bundles all policies for centralized assignment
- **Benefits**:
  - Single assignment point
  - Consistent compliance across subscriptions
  - Simplified management

## 📊 Compliance Dashboards

### VM Compliance Dashboard
- **File**: `vm-compliance-dashboard.json`
- **Visualizations**:
  - Overall policy compliance percentage
  - Top 10 non-compliant policies
  - VMs by environment (pie chart)
  - VM inventory with tags and sizes
- **Queries**: Uses Azure Resource Graph

### VM Cost Dashboard
- **File**: `vm-cost-dashboard.json`
- **Visualizations**:
  - Monthly cost by environment
  - Cost by VM size
  - Cost by cost center
  - Cost trends over time
  - Top 10 most expensive VMs

## 🚀 Deployment Instructions

### Deploy Policies

#### Using Azure CLI:

```bash
# Deploy individual policy
az policy definition create \
  --name "require-encryption-at-host" \
  --display-name "Enterprise - Require encryption at host for VMs" \
  --description "Ensures all VMs have encryption at host enabled" \
  --rules ./policies/require-encryption-at-host.json \
  --mode Indexed

# Deploy policy initiative
az policy set-definition create \
  --name "Enterprise-VM-compliance-initiative" \
  --display-name "Enterprise - VM Compliance Policy Initiative" \
  --description "Bundles all VM compliance policies" \
  --definitions ./policies/policy-initiative.json

# Assign policy initiative to subscription
az policy assignment create \
  --name "Enterprise-VM-compliance" \
  --display-name "VM Compliance" \
  --policy-set-definition "Enterprise-VM-compliance-initiative" \
  --scope "/subscriptions/{subscription-id}"
```

#### Using Azure PowerShell:

```powershell
# Deploy individual policy
New-AzPolicyDefinition `
  -Name "require-encryption-at-host" `
  -DisplayName "Enterprise - Require encryption at host for VMs" `
  -Policy (Get-Content ./policies/require-encryption-at-host.json -Raw)

# Deploy policy initiative
New-AzPolicySetDefinition `
  -Name "Enterprise-VM-compliance-initiative" `
  -DisplayName "Enterprise - VM Compliance Policy Initiative" `
  -PolicyDefinition (Get-Content ./policies/policy-initiative.json -Raw)

# Assign policy initiative
New-AzPolicyAssignment `
  -Name "Enterprise-VM-compliance" `
  -DisplayName "VM Compliance" `
  -PolicySetDefinition (Get-AzPolicySetDefinition -Name "Enterprise-VM-compliance-initiative") `
  -Scope "/subscriptions/{subscription-id}"
```

### Deploy Dashboards

```bash
# Deploy compliance dashboard
az portal dashboard create \
  --resource-group "rg-governance-prod" \
  --name "Enterprise-VM-Compliance-Dashboard" \
  --input-path ./dashboards/vm-compliance-dashboard.json

# Deploy cost dashboard
az portal dashboard create \
  --resource-group "rg-governance-prod" \
  --name "Enterprise-VM-Cost-Dashboard" \
  --input-path ./dashboards/vm-cost-dashboard.json
```

## 📈 Monitoring & Reporting

### Policy Compliance Report

Run this Azure Resource Graph query to get compliance status:

```kusto
PolicyResources
| where type == 'microsoft.policyinsights/policystates'
| where properties.resourceType == 'Microsoft.Compute/virtualMachines'
| summarize 
    Total = count(),
    Compliant = countif(properties.complianceState == 'Compliant'),
    NonCompliant = countif(properties.complianceState == 'NonCompliant')
  by tostring(properties.policyDefinitionName)
| extend CompliancePercentage = round((Compliant * 100.0) / Total, 2)
| project PolicyName = properties_policyDefinitionName, Total, Compliant, NonCompliant, CompliancePercentage
| order by CompliancePercentage asc
```

### Non-Compliant Resources

```kusto
PolicyResources
| where type == 'microsoft.policyinsights/policystates'
| where properties.complianceState == 'NonCompliant'
| where properties.resourceType == 'Microsoft.Compute/virtualMachines'
| project 
    VMName = tostring(properties.resourceId),
    PolicyName = tostring(properties.policyDefinitionName),
    Reason = tostring(properties.complianceReasonCode),
    Timestamp = todatetime(properties.timestamp)
| order by Timestamp desc
```

## 🔄 Automation Scripts

### Generate Compliance Report

```powershell
# Run from scripts/powershell/
.\Generate-ComplianceReport.ps1 -SubscriptionId "xxx" -OutputPath "compliance-report.html"
```

### Remediate Non-Compliant VMs

```powershell
# Tag remediation
.\Remediate-MissingTags.ps1 -SubscriptionId "xxx" -WhatIf

# Backup enrollment
.\Enroll-VmsInBackup.ps1 -SubscriptionId "xxx" -VaultName "rsv-backup-prod" -WhatIf
```

## 📋 Best Practices

### Policy Enforcement Strategy

1. **Phase 1 - Audit Mode** (Weeks 1-4)
   - Deploy all policies in Audit mode
   - Monitor compliance reports
   - Identify non-compliant resources
   - Communicate with resource owners

2. **Phase 2 - Remediation** (Weeks 5-8)
   - Remediate existing non-compliant resources
   - Update documentation and runbooks
   - Train teams on compliance requirements

3. **Phase 3 - Enforce Mode** (Week 9+)
   - Switch critical policies to Deny mode
   - Monitor for violations
   - Continuous improvement

### Recommended Policy Effects

| Policy | Dev | UAT | Prod |
|--------|-----|-----|------|
| Encryption at Host | Audit | Audit | Deny |
| Mandatory Tags | Audit | Deny | Deny |
| Naming Convention | Audit | Deny | Deny |
| Azure Backup | Disabled | Audit | AuditIfNotExists |
| SKU Restrictions | Audit | Audit | Audit |

## 🆘 Troubleshooting

### Policy Not Evaluating

```bash
# Check policy assignment
az policy assignment list --query "[?displayName=='VM Compliance']"

# Trigger policy evaluation
az policy state trigger-scan --resource-group "rg-prod-001"
```

### Dashboard Not Showing Data

1. Verify Azure Resource Graph permissions
2. Check query syntax in dashboard JSON
3. Ensure subscription ID is correct in queries
4. Wait 15-30 minutes for data propagation

## 📚 Additional Resources

- [Azure Policy Documentation](https://docs.microsoft.com/azure/governance/policy/)
- [Azure Resource Graph Queries](https://docs.microsoft.com/azure/governance/resource-graph/)
- [Azure Cost Management](https://docs.microsoft.com/azure/cost-management-billing/)
- [Your Organization Cloud Governance Handbook](../../docs/GOVERNANCE-HANDBOOK.md)

## 🔐 Security Considerations

- Policy definitions are stored in source control
- Assignments require Contributor or Owner role
- Use managed identities for remediation tasks
- Regularly review and update policy parameters
- Enable Azure Policy compliance notifications

## 📞 Support

For questions or issues with governance policies:
- **Team**: Cloud Governance Team
- **Email**: cloud-governance@Your Organization.com
- **ServiceNow**: Create ticket under "Cloud Governance" category
