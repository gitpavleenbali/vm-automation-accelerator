# Utilities Scripts

This directory contains Day-2 operational utilities for managing Azure VMs after deployment. These scripts complement the deployment automation in `deploy/scripts/` by providing ongoing VM operations, monitoring, security, compliance, and cost management capabilities.

## 📁 Directory Structure

```
utilities/
├── vm-operations/          # VM operational tasks
│   ├── monitoring/         # Monitoring agent installation
│   ├── security/          # Security hardening and compliance
│   └── compliance/        # Compliance reporting
├── cost-management/       # Cost optimization and quota management
└── servicenow/           # ServiceNow API integration
```

## 🎯 Purpose

These utilities are designed for:
- **Post-deployment operations**: Tasks performed after VMs are provisioned
- **Ongoing maintenance**: Regular operational activities
- **Monitoring & compliance**: Ensuring VMs meet security and compliance requirements
- **Cost optimization**: Managing quotas and calculating costs
- **Integration**: Connecting with external systems like ServiceNow

## 🔄 Integration with Deployment Pipelines

These utilities can be triggered:
1. **Manually**: Run directly by operators for ad-hoc tasks
2. **Via Pipelines**: Called from Azure DevOps pipelines for automation
3. **Scheduled**: Executed on a schedule for regular maintenance
4. **Event-driven**: Triggered by Azure events or ServiceNow workflows

Reference these scripts in your pipelines using relative paths:
```yaml
- script: |
    pwsh deploy/scripts/utilities/vm-operations/security/Apply-SecurityHardening.ps1
  displayName: 'Apply Security Hardening'
```

## 📚 Categories

### VM Operations
Scripts for managing VM operational tasks including monitoring agent installation, security hardening, and compliance reporting.

**See**: [vm-operations/README.md](vm-operations/README.md)

### Cost Management
Tools for cost calculation, quota management, and resource optimization across Azure subscriptions.

**See**: [cost-management/README.md](cost-management/README.md)

### ServiceNow Integration
Python client library for interacting with ServiceNow API, enabling automated catalog requests, incident management, and change workflows.

**See**: [servicenow/README.md](servicenow/README.md)

## 🔧 Prerequisites

### General Requirements
- Azure subscription with appropriate permissions
- Azure CLI installed and authenticated
- PowerShell 7.0+ (for .ps1 scripts)
- Python 3.8+ (for .py scripts)
- Bash shell (for .sh scripts on Linux)

### Specific Requirements
- **Monitoring scripts**: Azure Monitor workspace configured
- **Security scripts**: Azure Policy assignments in place
- **Compliance scripts**: Access to Azure Policy compliance data
- **Cost scripts**: Reader access to subscriptions and Cost Management data
- **ServiceNow scripts**: ServiceNow instance URL and API credentials

## 📖 Usage Patterns

### Running Scripts Locally

**PowerShell**:
```powershell
# Navigate to utilities directory
cd deploy/scripts/utilities

# Run with parameters
.\vm-operations\security\Apply-SecurityHardening.ps1 `
    -ResourceGroupName "rg-prod-vms" `
    -VMName "vm-web-01"
```

**Python**:
```bash
# Install dependencies
pip install -r requirements.txt

# Run script
python cost-management/cost_calculator.py --subscription-id <sub-id>
```

**Bash**:
```bash
# Make executable
chmod +x vm-operations/monitoring/install-agents-linux.sh

# Run
./vm-operations/monitoring/install-agents-linux.sh
```

### Running from Pipelines

Include in Azure DevOps pipeline:
```yaml
- task: PowerShell@2
  displayName: 'Generate Compliance Report'
  inputs:
    filePath: 'deploy/scripts/utilities/vm-operations/compliance/Generate-ComplianceReport.ps1'
    arguments: '-SubscriptionId $(subscriptionId) -OutputPath $(Build.ArtifactStagingDirectory)'
```

## 🛡️ Security Considerations

1. **Credential Management**: Use Azure Key Vault or pipeline variables for secrets
2. **Least Privilege**: Grant minimum required permissions
3. **Audit Logging**: All scripts log actions for audit trails
4. **Error Handling**: Scripts include try-catch blocks and proper error reporting
5. **Validation**: Input parameters are validated before execution

## 📊 Monitoring & Logging

All scripts support:
- **Verbose logging**: Use `-Verbose` flag for detailed output
- **Log files**: Scripts write to standard log locations
- **Azure Monitor**: Integration with Log Analytics workspaces
- **Status codes**: Exit codes indicate success/failure for pipeline integration

## 🔗 Related Documentation

- [Deployment Scripts](../README.md) - Day-1 infrastructure deployment
- [Architecture Overview](../../../docs/ARCHITECTURE.md)
- [Contributing Guide](../../../CONTRIBUTING.md)
- [Project Summary](../../../PROJECT-SUMMARY.md)

## 🤝 Contributing

When adding new utilities:
1. Place in appropriate category directory
2. Follow naming conventions (PascalCase for PowerShell, snake_case for Python)
3. Include parameter validation and help documentation
4. Add integration tests
5. Update category README.md
6. Document in PROJECT-SUMMARY.md

## 📝 Script Inventory

### Monitoring (2 scripts)
- `install-agents-linux.sh` - Linux monitoring agent installation
- `Install-Agents-Windows.ps1` - Windows monitoring agent installation

### Security (1 script)
- `Apply-SecurityHardening.ps1` - Security baseline enforcement

### Compliance (1 script)
- `Generate-ComplianceReport.ps1` - Automated compliance reporting

### Cost Management (3 scripts)
- `cost_calculator.py` - Cost estimation and analysis
- `quota_manager.py` - Azure quota monitoring
- `Validate-Quota.ps1` - Quota validation and alerting

### ServiceNow (1 script)
- `servicenow_client.py` - ServiceNow API wrapper

**Total**: 8 utility scripts supporting Day-2 operations
