# Backup Policy Module

## Overview

This module manages Azure Backup for Virtual Machines, including Recovery Services Vault creation, backup policy configuration, and VM protection enablement. It implements enterprise-grade backup capabilities with flexible retention policies.

## Features

- **Recovery Services Vault**: Managed vault with configurable redundancy
- **Flexible Backup Policies**: Daily or weekly schedules with custom retention
- **Multi-tier Retention**: Daily, weekly, monthly, and yearly retention periods
- **Instant Restore**: Fast VM recovery from local snapshots (up to 5 days)
- **Soft Delete Protection**: Safeguard against accidental backup deletion
- **Cross-region Restore**: Disaster recovery capability (with geo-redundancy)
- **Customer-managed Encryption**: Optional Key Vault integration for backup encryption
- **Infrastructure Encryption**: Double encryption for compliance requirements

## Usage

### Basic Daily Backup

```hcl
module "vm_backup" {
  source = "../../terraform-units/modules/backup-policy"
  
  resource_group_name = "rg-backup-prod"
  location            = "eastus"
  vault_name          = "rsv-vm-backup-prod"
  
  backup_policies = {
    daily = {
      name      = "daily-backup-23utc"
      frequency = "Daily"
      time      = "23:00"
      retention_daily_count = 30
    }
  }
  
  protected_vms = {
    web01 = {
      vm_id       = azurerm_linux_virtual_machine.web01.id
      policy_name = "daily"
    }
    web02 = {
      vm_id       = azurerm_linux_virtual_machine.web02.id
      policy_name = "daily"
    }
  }
  
  tags = var.tags
}
```

### Production Backup with Multi-tier Retention

```hcl
module "prod_vm_backup" {
  source = "../../terraform-units/modules/backup-policy"
  
  resource_group_name = "rg-backup-prod"
  location            = "eastus"
  vault_name          = "rsv-prod-backup"
  
  # Vault configuration
  vault_sku                  = "Standard"
  storage_mode_type          = "GeoRedundant"
  enable_cross_region_restore = true
  enable_soft_delete         = true
  
  backup_policies = {
    production = {
      name      = "prod-daily-backup"
      frequency = "Daily"
      time      = "23:00"
      timezone  = "Eastern Standard Time"
      
      # 30 days of daily backups
      retention_daily_count = 30
      
      # 12 weeks of weekly backups (Sunday)
      retention_weekly = {
        count    = 12
        weekdays = ["Sunday"]
      }
      
      # 12 months of monthly backups (first Sunday)
      retention_monthly = {
        count    = 12
        weekdays = ["Sunday"]
        weeks    = ["First"]
      }
      
      # 7 years of yearly backups (January first Sunday)
      retention_yearly = {
        count    = 7
        weekdays = ["Sunday"]
        weeks    = ["First"]
        months   = ["January"]
      }
      
      # 5 days of instant restore snapshots
      instant_restore_days = 5
    }
  }
  
  protected_vms = {
    app_server = {
      vm_id       = azurerm_windows_virtual_machine.app.id
      policy_name = "production"
    }
    db_server = {
      vm_id       = azurerm_linux_virtual_machine.db.id
      policy_name = "production"
    }
  }
  
  tags = {
    Environment = "Production"
    Backup      = "Critical"
    Compliance  = "Required"
  }
}
```

### Weekly Backup for Development

```hcl
module "dev_vm_backup" {
  source = "../../terraform-units/modules/backup-policy"
  
  resource_group_name = "rg-backup-dev"
  location            = "westus2"
  vault_name          = "rsv-dev-backup"
  
  vault_sku         = "Standard"
  storage_mode_type = "LocallyRedundant" # Cost-effective for dev
  enable_soft_delete = false              # Optional for dev
  
  backup_policies = {
    weekly = {
      name      = "weekly-backup"
      frequency = "Weekly"
      time      = "22:00"
      weekdays  = ["Sunday", "Wednesday"]
      
      retention_daily_count = 14
    }
  }
  
  protected_vms = {
    dev_vm = {
      vm_id       = azurerm_linux_virtual_machine.dev.id
      policy_name = "weekly"
    }
  }
  
  tags = var.tags
}
```

### Customer-managed Key Encryption

```hcl
module "encrypted_backup" {
  source = "../../terraform-units/modules/backup-policy"
  
  resource_group_name = "rg-backup-prod"
  location            = "eastus"
  vault_name          = "rsv-encrypted-backup"
  
  # Customer-managed encryption
  encryption_key_id               = azurerm_key_vault_key.backup_key.id
  enable_infrastructure_encryption = true # Double encryption
  
  backup_policies = {
    encrypted = {
      name      = "encrypted-daily-backup"
      frequency = "Daily"
      time      = "23:00"
      retention_daily_count = 30
    }
  }
  
  protected_vms = {
    secure_vm = {
      vm_id       = azurerm_linux_virtual_machine.secure.id
      policy_name = "encrypted"
    }
  }
  
  tags = var.tags
}
```

## Required Inputs

| Name | Description | Type |
|------|-------------|------|
| `resource_group_name` | Resource group for backup resources | `string` |
| `location` | Azure region for backup resources | `string` |
| `vault_name` | Name of the Recovery Services Vault | `string` |
| `backup_policies` | Map of backup policy configurations | `map(object)` |

## Optional Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `protected_vms` | VMs to protect with backup | `map(object)` | `{}` |
| `vault_sku` | Vault SKU: 'Standard' or 'RS0' | `string` | `"Standard"` |
| `storage_mode_type` | Storage redundancy type | `string` | `"GeoRedundant"` |
| `enable_cross_region_restore` | Enable cross-region restore | `bool` | `false` |
| `enable_soft_delete` | Enable soft delete protection | `bool` | `true` |
| `encryption_key_id` | Key Vault key ID for encryption | `string` | `null` |
| `enable_infrastructure_encryption` | Enable double encryption | `bool` | `false` |
| `tags` | Tags for backup resources | `map(string)` | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| `vault_id` | Resource ID of the Recovery Services Vault |
| `vault_name` | Name of the Recovery Services Vault |
| `backup_policy_ids` | Map of policy names to resource IDs |
| `backup_policy_names` | Map of policy keys to Azure names |
| `protected_vm_ids` | List of protected VM IDs |
| `backup_configuration` | Summary of backup configuration |

## Backup Policy Configuration

### Frequency Options

- **Daily**: Backups run once per day at specified time
- **Weekly**: Backups run on specified weekdays

### Retention Tiers

| Tier | Description | Max Retention |
|------|-------------|---------------|
| Daily | Keep daily backups | 9999 days |
| Weekly | Keep weekly backups | 5163 weeks (~99 years) |
| Monthly | Keep monthly backups | 1188 months (~99 years) |
| Yearly | Keep yearly backups | 99 years |

### Instant Restore

- **Range**: 1-5 days
- **Benefit**: Fast VM recovery from local snapshots
- **Storage**: Uses snapshot-based restore (not from vault)
- **Limitation**: Available only for recent backups

## Storage Redundancy Options

| Option | Description | Use Case | Cost |
|--------|-------------|----------|------|
| `LocallyRedundant` | 3 copies in single region | Dev/Test | Lowest |
| `ZoneRedundant` | Copies across availability zones | Single-region HA | Medium |
| `GeoRedundant` | Replicated to paired region | Disaster recovery | Highest |

## Best Practices

1. **Production Environments**:
   - Use `GeoRedundant` storage with cross-region restore
   - Enable soft delete protection
   - Implement multi-tier retention (daily/weekly/monthly/yearly)
   - Use 5-day instant restore for quick recovery

2. **Development Environments**:
   - Use `LocallyRedundant` storage for cost savings
   - Shorter retention periods (7-14 days)
   - Weekly backups may be sufficient

3. **Compliance Requirements**:
   - Enable customer-managed encryption for sensitive workloads
   - Enable infrastructure encryption for double encryption
   - Configure yearly retention for long-term compliance

4. **Cost Optimization**:
   - Balance retention periods with storage costs
   - Use instant restore for recent recoveries (no vault data transfer)
   - Consider lifecycle policies for archived backups

5. **Security**:
   - Enable soft delete to protect against accidental deletion
   - Use RBAC to control who can modify backup policies
   - Enable Azure AD authentication for vault access
   - Audit backup operations regularly

## Backup Schedule Examples

### Standard Business Hours (EST)

```hcl
frequency = "Daily"
time      = "23:00"  # 11 PM UTC = 6 PM EST (outside business hours)
timezone  = "Eastern Standard Time"
```

### Weekend-only Backups

```hcl
frequency = "Weekly"
weekdays  = ["Saturday", "Sunday"]
time      = "02:00"
```

### Mid-week and Weekend

```hcl
frequency = "Weekly"
weekdays  = ["Wednesday", "Saturday"]
time      = "22:00"
```

## Recovery Operations

### Portal-based Restore

1. Navigate to Recovery Services Vault
2. Select "Backup Items" → "Azure Virtual Machine"
3. Choose VM and select "Restore VM"
4. Select recovery point
5. Choose restore configuration (new VM, replace existing, restore disks)

### CLI-based Restore

```bash
# List recovery points
az backup recoverypoint list \
  --resource-group rg-backup-prod \
  --vault-name rsv-vm-backup-prod \
  --container-name <container-name> \
  --item-name <vm-name>

# Restore VM
az backup restore restore-azurevm \
  --resource-group rg-backup-prod \
  --vault-name rsv-vm-backup-prod \
  --container-name <container-name> \
  --item-name <vm-name> \
  --rp-name <recovery-point-name> \
  --target-resource-group <target-rg> \
  --storage-account <staging-storage>
```

## Monitoring and Alerts

### Recommended Alerts

1. **Backup Job Failed**: Alert when backup job fails
2. **Backup Job Taking Longer**: Alert for unusually long backup duration
3. **No Recent Backup**: Alert if no backup in last 25 hours (daily schedule)
4. **Vault Storage Threshold**: Alert when vault storage reaches threshold

### Log Analytics Queries

```kusto
// Recent backup jobs
AzureDiagnostics
| where Category == "AzureBackupReport"
| where OperationName == "Backup"
| project TimeGenerated, BackupItemUniqueId, JobStatus, JobDuration
| order by TimeGenerated desc
| take 50
```

## Cost Estimation

Backup costs consist of:

1. **Protected Instance**: $10/month per VM (approximate)
2. **Storage**: Varies by redundancy type and retention
   - GeoRedundant: ~$0.20/GB/month
   - LocallyRedundant: ~$0.10/GB/month
3. **Instant Restore Snapshots**: Additional snapshot storage costs

Example: 100 GB VM with 30-day retention
- Protected instance: $10/month
- Storage (GeoRedundant): ~$20/month (100 GB × $0.20)
- Total: ~$30/month

## Dependencies

This module requires:

- **azurerm provider** version >= 3.80
- **Terraform** version >= 1.5.0
- VMs must exist before backup protection can be enabled
- Sufficient permissions to create Recovery Services Vault

## Limitations

1. **Vault Limits**: Single vault supports up to 1000 VMs
2. **Backup Frequency**: Minimum once per day
3. **Instant Restore**: Maximum 5 days
4. **Cross-region Restore**: Requires GeoRedundant storage
5. **Encryption**: Customer-managed keys must be in same region as vault

## Troubleshooting

### Backup Job Failures

```bash
# Check backup job status
az backup job list \
  --resource-group rg-backup-prod \
  --vault-name rsv-vm-backup-prod \
  --status Failed

# View job details
az backup job show \
  --resource-group rg-backup-prod \
  --vault-name rsv-vm-backup-prod \
  --name <job-id>
```

### Common Issues

1. **VM Not Found**: Ensure VM exists and is in running state
2. **Insufficient Permissions**: Verify vault has permissions to access VM
3. **Snapshot Failure**: Check VM disk space and snapshot quota
4. **Slow Backups**: Review VM workload during backup window

## Related Modules

- [Compute Module](../compute/README.md) - VM deployment that can use this backup module
- [Monitoring Module](../monitoring/README.md) - Monitoring for backup operations

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2024 | Initial release with full backup policy support |

## License

This module is part of the Uniper VM Automation Accelerator.
