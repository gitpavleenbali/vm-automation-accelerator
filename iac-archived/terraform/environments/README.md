# Multi-Environment Configuration

This folder contains environment-specific Terraform variable files for deploying VMs across different environments.

## 📁 Available Environments

| Environment | File | Description | Characteristics |
|------------|------|-------------|-----------------|
| **Development** | `dev.tfvars` | Development environment | - Smaller VM sizes (D2s_v3)<br>- StandardSSD storage<br>- Backup disabled<br>- ASR disabled<br>- Relaxed security |
| **UAT** | `uat.tfvars` | User Acceptance Testing | - Production-like sizes (D4s_v3)<br>- Premium storage<br>- Daily backups<br>- Optional ASR<br>- Full monitoring |
| **Production** | `prod.tfvars` | Production environment | - Production sizes (D4s_v3+)<br>- Premium storage<br>- Enhanced backups<br>- ASR enabled<br>- Maximum security |

## 🚀 Usage

### Deploy to Development

```bash
cd iac/terraform

# Initialize with dev backend
terraform init -backend-config=backend-config/dev.hcl

# Plan with dev variables
terraform plan -var-file="environments/dev.tfvars"

# Apply to dev
terraform apply -var-file="environments/dev.tfvars"
```

### Deploy to UAT

```bash
cd iac/terraform

# Initialize with UAT backend
terraform init -backend-config=backend-config/uat.hcl

# Plan with UAT variables
terraform plan -var-file="environments/uat.tfvars"

# Apply to UAT
terraform apply -var-file="environments/uat.tfvars"
```

### Deploy to Production

```bash
cd iac/terraform

# Initialize with prod backend
terraform init -backend-config=backend-config/prod.hcl

# Plan with prod variables
terraform plan -var-file="environments/prod.tfvars"

# Apply to production (with approval)
terraform apply -var-file="environments/prod.tfvars"
```

## 🔧 Environment-Specific Configuration

### Development Environment

**Purpose**: Testing and development work

**Configuration Highlights**:
- VM Size: `Standard_D2s_v3` (cost-optimized)
- Storage: StandardSSD_LRS
- Backup: Disabled (optional)
- Domain Join: Disabled (optional)
- ASR: Disabled
- Monitoring: Basic
- Security Agents: Disabled

**Use Cases**:
- Developer testing
- Feature development
- Quick deployments

### UAT Environment

**Purpose**: User acceptance testing and pre-production validation

**Configuration Highlights**:
- VM Size: `Standard_D4s_v3` (production-like)
- Storage: Premium_LRS
- Backup: Daily backups enabled
- Domain Join: Enabled
- ASR: Optional
- Monitoring: Full monitoring stack
- Security Agents: Enabled

**Use Cases**:
- User acceptance testing
- Performance testing
- Production simulation
- Training environments

### Production Environment

**Purpose**: Live production workloads

**Configuration Highlights**:
- VM Size: `Standard_D4s_v3` or larger
- Storage: Premium_LRS
- Backup: Enhanced daily backups
- Domain Join: **Required**
- ASR: **Enabled** (disaster recovery)
- Monitoring: **Full stack with alerts**
- Security Agents: **All enabled**
- Key Vault: **Required** for secrets

**Use Cases**:
- Production applications
- Critical workloads
- Customer-facing services

## 🔒 Security Best Practices

### Password Management by Environment

| Environment | Recommended Approach |
|------------|---------------------|
| **Dev** | Auto-generate or inline (testing only) |
| **UAT** | Key Vault (recommended) |
| **Prod** | **Key Vault REQUIRED** |

### Key Vault Configuration

Each environment should have its own Key Vault:

```hcl
# Development
key_vault_name = "kv-Your Organization-dev-weu-001"

# UAT
key_vault_name = "kv-Your Organization-uat-weu-001"

# Production
key_vault_name = "kv-Your Organization-prod-weu-001"
```

## 📊 Resource Sizing Comparison

| Resource | Development | UAT | Production |
|----------|------------|-----|------------|
| **VM Size** | Standard_D2s_v3 | Standard_D4s_v3 | Standard_D4s_v3+ |
| **CPU Cores** | 2 | 4 | 4+ |
| **Memory** | 8 GB | 16 GB | 16+ GB |
| **OS Disk** | 127 GB (StandardSSD) | 127 GB (Premium) | 127 GB (Premium) |
| **Data Disks** | 256 GB x 1 | 512 GB x 2 | 1024 GB x 2 |
| **Storage Type** | StandardSSD_LRS | Premium_LRS | Premium_LRS |

## 💰 Cost Optimization

### Development Environment
- **Estimated Monthly Cost**: $150-250/month
- Use B-series or D2s for cost savings
- Shutdown during off-hours (use auto-shutdown)
- Disable backup and ASR

### UAT Environment
- **Estimated Monthly Cost**: $400-600/month
- Use production-like sizes for accurate testing
- Enable backups but shorter retention
- Optional ASR based on criticality

### Production Environment
- **Estimated Monthly Cost**: $600-1000/month
- Use right-sized VMs for workload
- Enable all protection features
- Consider Reserved Instances for 40-60% savings

## 🔄 Promotion Workflow

### Dev → UAT → Prod

```bash
# 1. Test in Development
terraform apply -var-file="environments/dev.tfvars"

# 2. Validate configuration
terraform plan -var-file="environments/dev.tfvars"

# 3. Promote to UAT (after testing)
terraform apply -var-file="environments/uat.tfvars"

# 4. User acceptance testing in UAT
# Run tests, validate functionality

# 5. Deploy to Production (after UAT sign-off)
terraform apply -var-file="environments/prod.tfvars"
```

## 🏷️ Environment Tagging

Each environment uses consistent tagging:

```hcl
# Development
tags = {
  Environment = "Development"
  Compliance  = "Standard"
}

# UAT
tags = {
  Environment = "UAT"
  Compliance  = "High"
}

# Production
tags = {
  Environment = "Production"
  Compliance  = "Critical"
}
```

## 📝 Customization Guide

### Step 1: Copy Environment File

```bash
cp environments/dev.tfvars environments/dev.tfvars.local
```

### Step 2: Update Required Values

```hcl
# Update subscription IDs
log_analytics_workspace_id = "/subscriptions/YOUR-SUBSCRIPTION-ID/..."

# Update Key Vault names
key_vault_name = "kv-yourorg-dev-weu-001"

# Update network configuration
vnet_name = "vnet-yourapp-dev-weu-001"
subnet_name = "snet-yourapp-dev-001"

# Update storage accounts (must be globally unique)
boot_diagnostics_storage_account = "styourorgdiagdev001"
```

### Step 3: Deploy

```bash
terraform apply -var-file="environments/dev.tfvars.local"
```

## ⚠️ Important Notes

1. **Never commit actual `.tfvars` files** with real values to Git
2. Use `.tfvars.example` as templates
3. Store actual `.tfvars` files in:
   - Azure Key Vault
   - Secure variable groups (Azure DevOps)
   - GitHub Secrets (GitHub Actions)
4. Each environment should have **separate state files** (configured in `backend-config/`)
5. **Always** run `terraform plan` before `apply` in production

## 🔗 Related Files

- **Backend Configuration**: `../backend-config/`
  - `dev.hcl` - Development state backend
  - `uat.hcl` - UAT state backend
  - `prod.hcl` - Production state backend

- **Main Configuration**: `../main.tf`
- **Variable Definitions**: `../variables.tf`
- **Module README**: `../README.md`

## 📚 Additional Resources

- [Terraform Workspaces](https://www.terraform.io/docs/language/state/workspaces.html)
- [Azure Naming Conventions](https://docs.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/naming-and-tagging)
- [Environment Strategy Best Practices](https://docs.microsoft.com/azure/cloud-adoption-framework/ready/considerations/environments)
