# Terraform State Management Guide

This document explains how to manage Terraform state for the VM Automation Accelerator in a production environment.

## Table of Contents
- [Overview](#overview)
- [Backend Configuration](#backend-configuration)
- [State Locking](#state-locking)
- [State File Management](#state-file-management)
- [Environment Separation](#environment-separation)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Overview

The VM Automation Accelerator uses **Azure Storage** as the remote backend for Terraform state management. This provides:

- **Centralized State Storage**: State files stored in Azure Blob Storage
- **State Locking**: Automatic locking via Azure Blob lease mechanism
- **State Versioning**: Blob versioning enabled for state file history
- **Encryption**: State files encrypted at rest using Azure Storage encryption
- **Access Control**: RBAC-based access to state files
- **Team Collaboration**: Multiple team members can work safely with shared state

### State Backend Architecture

```
Azure Subscription
└── Resource Group: rg-terraform-state-prod
    └── Storage Account: stuniptertfstateprod
        └── Container: tfstate
            ├── vm-automation/prod/terraform.tfstate
            ├── vm-automation/dev/terraform.tfstate
            └── vm-automation/test/terraform.tfstate
```

## Backend Configuration

### Initial Setup

The Terraform backend is configured in `backend.tf`:

```hcl
terraform {
  backend "azurerm" {
    # Configuration provided via backend config files
  }
}
```

### Environment-Specific Backend Configuration

Backend configuration is separated by environment using `.hcl` files:

**Production** (`backend-config/prod.hcl`):
```hcl
resource_group_name  = "rg-terraform-state-prod"
storage_account_name = "stuniptertfstateprod"
container_name       = "tfstate"
key                  = "vm-automation/prod/terraform.tfstate"
use_azuread_auth     = true
```

**Development** (`backend-config/dev.hcl`):
```hcl
resource_group_name  = "rg-terraform-state-dev"
storage_account_name = "stuniptertfstatedev"
container_name       = "tfstate"
key                  = "vm-automation/dev/terraform.tfstate"
use_azuread_auth     = true
```

### Initialize Terraform with Backend

```bash
# Production
terraform init -backend-config="backend-config/prod.hcl"

# Development
terraform init -backend-config="backend-config/dev.hcl"
```

## State Locking

### How State Locking Works

Terraform automatically acquires a **lease lock** on the Azure Blob when performing state-modifying operations:

1. User runs `terraform apply`
2. Terraform acquires a lease lock on the state blob
3. Terraform reads the current state
4. Terraform performs the operation
5. Terraform writes the new state
6. Terraform releases the lease lock

### Lock Behavior

- **Lock Duration**: 15 seconds (automatically renewed during long operations)
- **Concurrent Operations**: Blocked until lock is released
- **Lock Failure**: Terraform waits and retries
- **Force Unlock**: Available if lock gets stuck (use with caution)

### Force Unlock (Emergency Only)

If a lock gets stuck (e.g., process killed), you can force unlock:

```bash
# Get the Lock ID from error message
terraform force-unlock <LOCK_ID>
```

**⚠️ WARNING**: Only use force-unlock if you're certain no other process is running!

## State File Management

### State File Structure

```json
{
  "version": 4,
  "terraform_version": "1.5.7",
  "serial": 42,
  "lineage": "c8a1d0b2-...",
  "outputs": { ... },
  "resources": [ ... ]
}
```

### State File Versioning

Azure Blob Storage versioning is enabled for state files:

```bash
# List state file versions
az storage blob list \
  --account-name stuniptertfstateprod \
  --container-name tfstate \
  --prefix "vm-automation/prod/" \
  --include v \
  --auth-mode login

# Download a specific version
az storage blob download \
  --account-name stuniptertfstateprod \
  --container-name tfstate \
  --name "vm-automation/prod/terraform.tfstate" \
  --file "./terraform.tfstate.backup" \
  --version-id "<VERSION_ID>" \
  --auth-mode login
```

### Manual State Operations

#### Pull Current State

```bash
terraform state pull > terraform.tfstate.backup
```

#### Push State (Caution!)

```bash
terraform state push terraform.tfstate
```

**⚠️ WARNING**: `state push` overwrites the remote state. Use with extreme caution!

#### List Resources in State

```bash
terraform state list
```

#### Show Resource Details

```bash
terraform state show azurerm_windows_virtual_machine.vm
```

#### Move Resources

```bash
# Rename resource in state
terraform state mv azurerm_windows_virtual_machine.old azurerm_windows_virtual_machine.new
```

#### Remove Resource from State

```bash
# Remove from state without destroying resource
terraform state rm azurerm_windows_virtual_machine.vm
```

## Environment Separation

### Strategy: Separate State Files

Each environment has its **own state file**:

- **Production**: `vm-automation/prod/terraform.tfstate`
- **Development**: `vm-automation/dev/terraform.tfstate`
- **Test**: `vm-automation/test/terraform.tfstate`

### Benefits

✅ **Isolation**: Changes in dev don't affect prod
✅ **Security**: Different RBAC permissions per environment
✅ **Safety**: No risk of accidentally destroying prod resources
✅ **Clarity**: Clear separation of resources

### CI/CD Integration

The Azure DevOps pipeline automatically selects the correct backend based on the branch:

```yaml
- task: AzureCLI@2
  displayName: 'Terraform Init'
  inputs:
    scriptType: 'bash'
    inlineScript: |
      if [[ "$(Build.SourceBranchName)" == "main" ]]; then
        ENVIRONMENT="prod"
      else
        ENVIRONMENT="dev"
      fi
      
      terraform init -backend-config="backend-config/${ENVIRONMENT}.hcl"
```

## Best Practices

### ✅ DO

1. **Always use remote backend** - Never store state locally for production
2. **Enable blob versioning** - Provides state file history and recovery
3. **Use separate state files per environment** - Isolate dev/test/prod
4. **Use Azure AD authentication** - More secure than storage account keys
5. **Restrict storage account access** - Use RBAC and firewall rules
6. **Enable soft delete** - Protects against accidental state deletion
7. **Back up state regularly** - Store copies in separate location
8. **Use state locking** - Prevents concurrent modifications
9. **Review state file changes** - Check `terraform plan` before applying
10. **Document state operations** - Log all manual state modifications

### ❌ DON'T

1. **Don't commit state files to Git** - Add `*.tfstate*` to `.gitignore`
2. **Don't share storage account keys** - Use Managed Identity or SPN
3. **Don't manually edit state files** - Use Terraform state commands
4. **Don't force-unlock without verifying** - Could cause state corruption
5. **Don't use same state file for multiple environments** - Use separate files
6. **Don't disable state locking** - Prevents race conditions
7. **Don't ignore state drift** - Run `terraform plan` regularly
8. **Don't delete state files** - Use proper Terraform destroy workflow

### State File Security

#### Access Control

```bash
# Grant read/write access to specific users
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee "user@Your Organization.com" \
  --scope "/subscriptions/<SUB_ID>/resourceGroups/rg-terraform-state-prod/providers/Microsoft.Storage/storageAccounts/stuniptertfstateprod"

# Grant read-only access
az role assignment create \
  --role "Storage Blob Data Reader" \
  --assignee "user@Your Organization.com" \
  --scope "/subscriptions/<SUB_ID>/resourceGroups/rg-terraform-state-prod/providers/Microsoft.Storage/storageAccounts/stuniptertfstateprod"
```

#### Network Restrictions

```bash
# Enable firewall and restrict to specific IPs
az storage account update \
  --name stuniptertfstateprod \
  --resource-group rg-terraform-state-prod \
  --default-action Deny

# Add allowed IP ranges
az storage account network-rule add \
  --account-name stuniptertfstateprod \
  --resource-group rg-terraform-state-prod \
  --ip-address "203.0.113.0/24"
```

#### Enable Soft Delete

```bash
# Enable soft delete for 30 days
az storage account blob-service-properties update \
  --account-name stuniptertfstateprod \
  --enable-delete-retention true \
  --delete-retention-days 30
```

## Troubleshooting

### Issue: "Error locking state: blob is already locked"

**Cause**: Another Terraform process is running or a previous process crashed

**Solution**:
```bash
# Wait for the lock to expire (15 seconds)
# OR force unlock if certain no other process is running
terraform force-unlock <LOCK_ID>
```

### Issue: "Error: Failed to get existing workspaces"

**Cause**: Insufficient permissions on storage account

**Solution**:
```bash
# Grant "Storage Blob Data Contributor" role
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee "$(az ad signed-in-user show --query id -o tsv)" \
  --scope "<STORAGE_ACCOUNT_RESOURCE_ID>"
```

### Issue: "Error: state snapshot was created by Terraform v1.6.0, which is newer"

**Cause**: Terraform version mismatch

**Solution**:
```bash
# Install the required Terraform version
tfenv install 1.6.0
tfenv use 1.6.0

# OR update terraform.required_version in backend.tf
```

### Issue: "Error: Backend configuration changed"

**Cause**: Backend configuration was modified

**Solution**:
```bash
# Reinitialize with new backend configuration
terraform init -reconfigure -backend-config="backend-config/prod.hcl"
```

### Issue: State drift detected

**Cause**: Resources were modified outside Terraform

**Solution**:
```bash
# Identify drifted resources
terraform plan -detailed-exitcode

# Refresh state to match current infrastructure
terraform refresh

# Update Terraform code to match manual changes
# OR revert manual changes to match Terraform code

# Reapply to fix drift
terraform apply
```

### Recovering from State File Corruption

1. **Stop all Terraform operations immediately**

2. **Download the corrupted state file**:
   ```bash
   az storage blob download \
     --account-name stuniptertfstateprod \
     --container-name tfstate \
     --name "vm-automation/prod/terraform.tfstate" \
     --file "./corrupted-state.json" \
     --auth-mode login
   ```

3. **List available versions**:
   ```bash
   az storage blob list \
     --account-name stuniptertfstateprod \
     --container-name tfstate \
     --prefix "vm-automation/prod/" \
     --include v \
     --auth-mode login
   ```

4. **Download a previous working version**:
   ```bash
   az storage blob download \
     --account-name stuniptertfstateprod \
     --container-name tfstate \
     --name "vm-automation/prod/terraform.tfstate" \
     --file "./recovered-state.json" \
     --version-id "<PREVIOUS_VERSION_ID>" \
     --auth-mode login
   ```

5. **Test the recovered state**:
   ```bash
   terraform state pull > current-state.json
   cp recovered-state.json terraform.tfstate
   terraform plan  # Verify plan looks reasonable
   ```

6. **Push the recovered state (if verification passed)**:
   ```bash
   terraform state push recovered-state.json
   ```

7. **Verify recovery**:
   ```bash
   terraform plan  # Should show minimal or no changes
   ```

## Additional Resources

- [Terraform Backend Documentation](https://developer.hashicorp.com/terraform/language/settings/backends/azurerm)
- [Azure Storage for Terraform State](https://learn.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage)
- [Terraform State Management Best Practices](https://developer.hashicorp.com/terraform/language/state)
- [Azure Blob Lease Locking](https://learn.microsoft.com/en-us/rest/api/storageservices/lease-blob)
