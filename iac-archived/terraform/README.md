# VM Automation Accelerator - Terraform Setup

## Prerequisites

### Required Tools
- **Terraform**: v1.5.0 or later
- **Azure CLI**: v2.50.0 or later
- **PowerShell**: v7.0 or later (for helper scripts)
- **Git**: For version control
- **Azure DevOps CLI** (optional): For pipeline management

### Azure Permissions
- **Contributor** role on target subscription/resource groups
- **Storage Blob Data Contributor** on Terraform state storage account
- **Key Vault Secrets User** on secrets Key Vault

## Quick Start

### 1. Clone Repository

```bash
git clone <repository-url>
cd vm-automation-accelerator/iac/terraform
```

### 2. Set Up Terraform Backend Storage

The backend storage account stores Terraform state files with locking and versioning.

```bash
# Set variables
ENVIRONMENT="prod"  # or "dev", "test"
LOCATION="westeurope"
RG_NAME="rg-terraform-state-${ENVIRONMENT}"
SA_NAME="stuniptertfstate${ENVIRONMENT}"
CONTAINER_NAME="tfstate"

# Create resource group
az group create \
  --name $RG_NAME \
  --location $LOCATION

# Create storage account with security features
az storage account create \
  --name $SA_NAME \
  --resource-group $RG_NAME \
  --location $LOCATION \
  --sku Standard_LRS \
  --kind StorageV2 \
  --https-only true \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --encryption-services blob

# Enable blob versioning (state file history)
az storage account blob-service-properties update \
  --account-name $SA_NAME \
  --enable-versioning true

# Enable soft delete (30 days retention)
az storage account blob-service-properties update \
  --account-name $SA_NAME \
  --enable-delete-retention true \
  --delete-retention-days 30

# Create container
az storage container create \
  --name $CONTAINER_NAME \
  --account-name $SA_NAME \
  --auth-mode login

# Grant yourself access (replace with your user/group)
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee "$(az ad signed-in-user show --query id -o tsv)" \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RG_NAME/providers/Microsoft.Storage/storageAccounts/$SA_NAME"
```

### 3. Configure Variables

Copy the example variables file and customize:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
# Environment
environment     = "prod"
location_short  = "weu"
instance_id     = 1

# VM Configuration
vm_name = "vm-app-prod-001"
vm_size = "Standard_D4s_v3"
os_type = "Windows"

# Network
vnet_name                   = "vnet-prod-weu-001"
subnet_name                 = "snet-app-prod-weu-001"
network_resource_group_name = "rg-network-prod-weu-001"

# ... (see terraform.tfvars.example for complete list)
```

**⚠️ IMPORTANT**: Add `terraform.tfvars` to `.gitignore` to prevent committing sensitive values!

### 4. Initialize Terraform

Initialize Terraform with the backend configuration:

```bash
# For production
terraform init -backend-config="backend-config/prod.hcl"

# For development
terraform init -backend-config="backend-config/dev.hcl"
```

Expected output:
```
Initializing the backend...

Successfully configured the backend "azurerm"!

Initializing provider plugins...
- Finding hashicorp/azurerm versions matching "~> 3.85.0"...
- Installing hashicorp/azurerm v3.85.0...

Terraform has been successfully initialized!
```

### 5. Validate Configuration

```bash
# Validate syntax
terraform validate

# Check formatting
terraform fmt -check -recursive

# Format code (if needed)
terraform fmt -recursive
```

### 6. Plan Deployment

Generate an execution plan to preview changes:

```bash
terraform plan -out=tfplan

# Save plan to a file for review
terraform show -no-color tfplan > tfplan.txt
```

Review the plan carefully before applying!

### 7. Apply Configuration

Deploy the infrastructure:

```bash
# Apply the saved plan
terraform apply tfplan

# OR apply directly (requires confirmation)
terraform apply
```

### 8. Verify Deployment

```bash
# List all resources in state
terraform state list

# Show specific resource details
terraform state show module.virtual_machine.azurerm_windows_virtual_machine.vm[0]

# View outputs
terraform output

# Export outputs to JSON
terraform output -json > outputs.json
```

## Terraform Workflow

### Standard Workflow

```
┌─────────────┐
│  Git Clone  │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│terraform init│  ← Initialize backend
└──────┬──────┘
       │
       ▼
┌─────────────┐
│terraform plan│  ← Preview changes
└──────┬──────┘
       │
       ▼
┌─────────────┐
│Review Changes│  ← Human approval
└──────┬──────┘
       │
       ▼
┌─────────────┐
│terraform apply│ ← Deploy infrastructure
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Validate  │  ← Verify deployment
└─────────────┘
```

### CI/CD Pipeline Workflow

The Azure DevOps pipeline automates this workflow with additional governance:

1. **Init**: Initialize Terraform with environment-specific backend
2. **Validate**: Run `terraform validate`, format check, security scan (Checkov)
3. **Plan**: Generate execution plan, quota check, cost forecast
4. **Approve**: L2 manual approval gate (production only)
5. **Apply**: Deploy infrastructure
6. **Validate**: Post-deployment checks (VM status, agents, connectivity)
7. **Notify**: Update ServiceNow, send email notifications

## State Management

### Understanding Terraform State

Terraform state is a **critical file** that maps your Terraform configuration to real Azure resources.

**State contains**:
- Resource IDs and metadata
- Resource dependencies
- Outputs
- Sensitive values (encrypted)

**Never**:
- Edit state files manually
- Delete state files
- Commit state to Git
- Share state files via email/Slack

### Remote State with Azure Storage

Benefits:
- ✅ **Centralized**: Team members share the same state
- ✅ **Locked**: Automatic locking prevents concurrent modifications
- ✅ **Versioned**: Blob versioning provides state history
- ✅ **Encrypted**: State encrypted at rest
- ✅ **Backed Up**: Soft delete enabled for recovery

### State File Locations

```
Azure Storage Account: stuniptertfstateprod
└── Container: tfstate
    ├── vm-automation/prod/terraform.tfstate     # Production
    ├── vm-automation/dev/terraform.tfstate      # Development
    └── vm-automation/test/terraform.tfstate     # Test
```

### Common State Operations

```bash
# Pull current state to local file
terraform state pull > terraform.tfstate.backup

# List all resources
terraform state list

# Show resource details
terraform state show <resource_address>

# Remove resource from state (without destroying)
terraform state rm <resource_address>

# Move/rename resource in state
terraform state mv <source> <destination>

# Import existing resource into state
terraform import <resource_address> <azure_resource_id>

# Replace resource (destroy and recreate)
terraform apply -replace="<resource_address>"
```

See [STATE-MANAGEMENT.md](../../docs/STATE-MANAGEMENT.md) for detailed state management guide.

## Module Structure

```
iac/terraform/
├── backend.tf                      # Backend configuration
├── backend-config/
│   ├── prod.hcl                    # Production backend config
│   ├── dev.hcl                     # Development backend config
│   └── test.hcl                    # Test backend config
├── main.tf                         # Root module orchestration
├── variables.tf                    # Input variables
├── outputs.tf                      # Output values
├── terraform.tfvars.example        # Example variables file
├── terraform.tfvars                # Actual variables (gitignored)
└── modules/
    ├── compute/                    # VM module
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── network-security/           # NSG module
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── network-interface/          # NIC module
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── monitoring/                 # Azure Monitor agents
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── domain-join/                # Active Directory join
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── hardening/                  # Security hardening
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── backup/                     # Azure Backup
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── site-recovery/              # Azure Site Recovery
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## Security Best Practices

### 1. Sensitive Values

**Never hardcode sensitive values!**

❌ **DON'T**:
```hcl
admin_password = "MyP@ssw0rd123!"
```

✅ **DO**:
```hcl
# Option 1: Generate automatically
admin_password = null  # Triggers random_password generation

# Option 2: Fetch from Key Vault (in pipeline)
TF_VAR_admin_password=$(az keyvault secret show ...)
```

### 2. `.gitignore`

Ensure these files are **never** committed:

```gitignore
# Terraform state files
*.tfstate
*.tfstate.*
*.tfstate.backup

# Variable files with sensitive data
terraform.tfvars
*.auto.tfvars

# Terraform directories
.terraform/
.terraform.lock.hcl

# Plan files (may contain sensitive data)
*.tfplan
tfplan

# Crash logs
crash.log
```

### 3. RBAC Permissions

Follow principle of least privilege:

| Role | Permissions | Use Case |
|------|-------------|----------|
| **Contributor** | Deploy resources | Pipeline service principal |
| **Reader** | View resources | Auditors, read-only access |
| **Storage Blob Data Contributor** | Read/write state files | Terraform users |
| **Storage Blob Data Reader** | Read-only state files | Reviewers |
| **Key Vault Secrets User** | Read secrets | Pipeline fetching secrets |

### 4. Network Security

Restrict state storage account access:

```bash
# Enable firewall
az storage account update \
  --name stuniptertfstateprod \
  --default-action Deny

# Allow specific IPs
az storage account network-rule add \
  --account-name stuniptertfstateprod \
  --ip-address "203.0.113.0/24"

# Allow Azure services
az storage account update \
  --name stuniptertfstateprod \
  --bypass AzureServices
```

## Troubleshooting

### Issue: "Backend initialization required"

```bash
# Re-initialize backend
terraform init -reconfigure -backend-config="backend-config/prod.hcl"
```

### Issue: "Error acquiring the state lock"

```bash
# Wait for lock to expire (15 seconds) OR
terraform force-unlock <LOCK_ID>
```

⚠️ Only force-unlock if certain no other process is running!

### Issue: "Error: Invalid for_each argument"

Ensure dynamic blocks have proper conditionals:

```hcl
# Correct
dynamic "source_image_reference" {
  for_each = var.use_custom_image ? [] : [1]
  content { ... }
}
```

### Issue: State drift detected

```bash
# Refresh state
terraform refresh

# View drift
terraform plan -detailed-exitcode

# Fix drift
terraform apply
```

### Issue: Module not found

```bash
# Re-download modules
terraform get -update
```

## Additional Commands

### Working with Workspaces

```bash
# List workspaces
terraform workspace list

# Create new workspace
terraform workspace new test

# Switch workspace
terraform workspace select prod

# Show current workspace
terraform workspace show
```

⚠️ **Note**: This accelerator uses **separate state files** instead of workspaces for environment separation.

### Targeting Specific Resources

```bash
# Plan changes for specific resource
terraform plan -target=module.virtual_machine

# Apply changes to specific resource only
terraform apply -target=module.virtual_machine.azurerm_windows_virtual_machine.vm[0]
```

### Destroying Infrastructure

```bash
# Destroy all resources
terraform destroy

# Destroy specific resource
terraform destroy -target=module.virtual_machine

# Generate destroy plan
terraform plan -destroy -out=destroy.tfplan
terraform apply destroy.tfplan
```

## Next Steps

1. ✅ Set up Terraform backend storage
2. ✅ Configure `terraform.tfvars`
3. ✅ Run `terraform init`
4. ✅ Generate and review plan
5. ✅ Apply configuration
6. 📖 Read [STATE-MANAGEMENT.md](../../docs/STATE-MANAGEMENT.md)
7. 📖 Review [ARCHITECTURE.md](../../ARCHITECTURE.md)
8. 🔧 Set up Azure DevOps pipeline
9. 🔗 Configure ServiceNow integration

## Support

For issues or questions:
- Check [STATE-MANAGEMENT.md](../../docs/STATE-MANAGEMENT.md)
- Review [Terraform Azure Provider Docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- Contact: Azure Landing Zones team

## License

Copyright © 2025 Your Organization. All rights reserved.
