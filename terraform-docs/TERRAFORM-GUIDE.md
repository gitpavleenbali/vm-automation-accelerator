# VM Automation Accelerator - Terraform Guide

## 🎯 Executive Summary

This VM Automation Accelerator is built with **enterprise-grade Terraform** featuring robust state management, modular architecture, and production-ready best practices.

### Key Features

| Feature | Implementation |
|---------|---------------|
| **State Management** | Remote state in Azure Storage with locking |
| **Modularity** | Reusable Terraform modules with typed variables |
| **Validation** | Terraform validate + plan + Checkov security scan |
| **Versioning** | Provider version constraints and pinning |
| **State Locking** | Azure Blob lease mechanism for safe concurrent operations |
| **Drift Detection** | Manual via Portal | `terraform plan` shows drift |
| **Import** | Limited support | Full `terraform import` capability |

---

## 📁 Repository Structure (Terraform)

```
vm-automation-accelerator/
├── .gitignore                              # Terraform-specific ignores
├── README.md                               # Main documentation
├── ARCHITECTURE.md                         # Architecture overview
├── SUMMARY.md                              # Executive summary
│
├── docs/
│   └── STATE-MANAGEMENT.md                 # 🆕 State management guide
│
├── iac/
│   └── terraform/                          # 🆕 Terraform root module
│       ├── README.md                       # 🆕 Terraform setup guide
│       ├── backend.tf                      # 🆕 Backend configuration
│       ├── backend-config/                 # 🆕 Environment-specific backends
│       │   ├── prod.hcl
│       │   ├── dev.hcl
│       │   └── test.hcl
│       ├── main.tf                         # 🆕 Root module orchestration
│       ├── variables.tf                    # 🆕 Input variables with validation
│       ├── outputs.tf                      # 🆕 Output values
│       ├── terraform.tfvars.example        # 🆕 Example variables file
│       └── modules/                        # 🆕 Terraform child modules
│           ├── compute/                    # VM resources
│           ├── network-security/           # NSG with FCR rules
│           ├── network-interface/          # NIC + Public IP
│           ├── monitoring/                 # Azure Monitor + DCR
│           ├── domain-join/                # AD domain join
│           ├── hardening/                  # Security hardening
│           ├── backup/                     # Azure Backup
│           └── site-recovery/              # Azure Site Recovery
│
├── pipelines/
│   └── azure-devops/
│       └── terraform-vm-deploy-pipeline.yml # 🆕 Terraform pipeline
│
└── scripts/
    └── powershell/
        ├── Validate-Quota.ps1
        ├── Get-CostForecast.ps1
        └── Update-ServiceNowTicket.ps1
```

---

## 🔑 Key Terraform Features

### 1. Remote State Management

**Azure Storage Backend** with automatic locking:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state-prod"
    storage_account_name = "stuniptertfstateprod"
    container_name       = "tfstate"
    key                  = "vm-automation/prod/terraform.tfstate"
    use_azuread_auth     = true
  }
}
```

**Benefits**:
- ✅ **State Locking**: Azure Blob lease prevents concurrent modifications
- ✅ **State Versioning**: Blob versioning tracks state file history
- ✅ **Team Collaboration**: Shared state accessible by all team members
- ✅ **Encryption**: State encrypted at rest and in transit
- ✅ **RBAC Access**: Azure AD authentication for secure access

### 2. Environment Separation

Separate state files per environment:

```
tfstate container
├── vm-automation/prod/terraform.tfstate   # Production
├── vm-automation/dev/terraform.tfstate    # Development
└── vm-automation/test/terraform.tfstate   # Test
```

Initialize with environment-specific backend:

```bash
# Production
terraform init -backend-config="backend-config/prod.hcl"

# Development
terraform init -backend-config="backend-config/dev.hcl"
```

### 3. Variable Validation

Production-safe validation rules:

```hcl
variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be dev, test, or prod."
  }
}

variable "vm_size" {
  type = string
  validation {
    condition     = can(regex("^Standard_[A-Z][0-9]+[a-z]*s?_v[0-9]+$", var.vm_size))
    error_message = "VM size must match Azure SKU naming convention."
  }
}
```

### 4. Modular Architecture

Reusable, composable modules:

```hcl
module "virtual_machine" {
  source = "./modules/compute"
  
  vm_name             = var.vm_name
  resource_group_name = data.azurerm_resource_group.main.name
  # ... other parameters
}

module "monitoring" {
  source = "./modules/monitoring"
  
  vm_id = module.virtual_machine.vm_id
  # ... monitoring configuration
}
```

### 5. Comprehensive Outputs

Outputs for automation and integration:

```hcl
output "vm_id" {
  value = module.virtual_machine.vm_id
}

output "terraform_state_info" {
  value = {
    backend_type = "azurerm"
    state_key    = "vm-automation/${var.environment}/terraform.tfstate"
    workspace    = terraform.workspace
    last_updated = timestamp()
  }
}
```

---

## 🚀 Terraform Workflow

### Local Development

```bash
# 1. Initialize backend
terraform init -backend-config="backend-config/dev.hcl"

# 2. Validate configuration
terraform validate

# 3. Format code
terraform fmt -recursive

# 4. Generate plan
terraform plan -out=tfplan

# 5. Review plan
terraform show -no-color tfplan > tfplan.txt
# Review tfplan.txt

# 6. Apply changes
terraform apply tfplan

# 7. View outputs
terraform output -json > outputs.json
```

### CI/CD Pipeline (Azure DevOps)

6-stage automated workflow:

```
Stage 1: Initialize Backend
   ├── Ensure storage account exists
   ├── Enable blob versioning
   └── Enable soft delete

Stage 2: Terraform Plan
   ├── terraform init
   ├── terraform validate
   ├── terraform fmt -check
   ├── Checkov security scan
   ├── Quota validation
   ├── Cost forecasting
   └── terraform plan (saved to artifact)

Stage 3: L2 Approval (prod only)
   ├── Manual validation gate
   └── Update ServiceNow ticket

Stage 4: Terraform Apply
   ├── terraform init
   ├── Fetch secrets from Key Vault
   ├── terraform apply (using saved plan)
   └── Extract outputs

Stage 5: Post-Deployment Validation
   ├── Verify VM running status
   ├── Verify monitoring agents installed
   └── Run connectivity tests

Stage 6: Notification
   ├── Update ServiceNow (success/failure)
   └── Send email notification
```

---

## 🔒 State Management Best Practices

### ✅ DO

1. **Always use remote backend** for production
2. **Enable blob versioning** for state history
3. **Use separate state files** per environment
4. **Use Azure AD auth** instead of storage keys
5. **Restrict storage account access** with RBAC
6. **Enable soft delete** (30-day retention)
7. **Run `terraform plan` regularly** to detect drift
8. **Review plans before applying** in production
9. **Use state locking** (enabled by default)
10. **Document state operations** in change log

### ❌ DON'T

1. **Never commit state files** to Git (`.gitignore` includes `*.tfstate*`)
2. **Never manually edit state** (use `terraform state` commands)
3. **Never force-unlock** without verification
4. **Never share storage keys** (use Managed Identity)
5. **Never use same state** for multiple environments
6. **Never disable state locking**
7. **Never ignore drift** detected by `terraform plan`
8. **Never delete state files** manually

### State Operations

```bash
# Pull state to local file
terraform state pull > terraform.tfstate.backup

# List resources in state
terraform state list

# Show resource details
terraform state show azurerm_windows_virtual_machine.vm

# Remove resource from state (without destroying)
terraform state rm azurerm_windows_virtual_machine.vm

# Move/rename resource
terraform state mv old_address new_address

# Import existing resource
terraform import azurerm_windows_virtual_machine.vm /subscriptions/.../resourceGroups/.../providers/Microsoft.Compute/virtualMachines/vm-name
```

---

## 🎯 Why Terraform for This Accelerator

### Key Advantages

✅ **Multi-cloud ready** - Future-proof for hybrid/multi-cloud scenarios
✅ **Explicit state management** - Full control and visibility
✅ **Advanced drift detection** - Built-in `terraform plan` comparison
✅ **Mature module ecosystem** - Leverage Azure Verified Modules (AVM)
✅ **Import existing resources** - Full support for brownfield scenarios
✅ **Complex variable validation** - Type checking and custom validation rules
✅ **Strong testing support** - Terratest, Kitchen-Terraform, and more
✅ **Large community** - 3000+ providers and extensive documentation

### Enterprise Benefits

| Capability | Benefit |
|------------|---------|
| **State Management** | Remote state in Azure Storage with versioning |
| **State Locking** | Azure Blob lease prevents concurrent conflicts |
| **Drift Detection** | Automatic detection of configuration changes |
| **Import Support** | Manage existing Azure resources with Terraform |
| **Variable Validation** | Enforce compliance and prevent misconfigurations |
| **Modular Design** | Reusable HCL modules for consistency |
| **Provider Ecosystem** | Integrate with 3000+ services beyond Azure |
| **IDE Support** | Multiple IDEs with Language Server Protocol |
| **Testing Framework** | Comprehensive testing with Terratest |

---

## 🛠️ Quick Start (Terraform)

### Prerequisites

```bash
# Install Terraform
choco install terraform  # Windows
brew install terraform   # macOS

# Verify installation
terraform version
# Terraform v1.5.7

# Install Azure CLI
az version
# Azure CLI 2.50.0+
```

### Initialize Project

```bash
# 1. Clone repository
git clone <repo-url>
cd vm-automation-accelerator/iac/terraform

# 2. Set up backend storage
./scripts/setup-backend.sh prod  # Creates storage account

# 3. Configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# 4. Initialize Terraform
terraform init -backend-config="backend-config/prod.hcl"

# 5. Generate plan
terraform plan -out=tfplan

# 6. Review and apply
terraform show tfplan
terraform apply tfplan
```

### First Deployment

```bash
# Validate quota
pwsh scripts/powershell/Validate-Quota.ps1 -VMSize "Standard_D4s_v3"

# Generate plan
terraform plan -var-file="terraform.tfvars" -out=tfplan

# Review plan
terraform show -no-color tfplan > tfplan.txt
cat tfplan.txt

# Apply (after review)
terraform apply tfplan

# Verify deployment
terraform output -json > outputs.json
cat outputs.json
```

---

## 🔐 Security Hardening

### State File Security

```bash
# Enable storage account firewall
az storage account update \
  --name stuniptertfstateprod \
  --default-action Deny

# Allow specific IP ranges
az storage account network-rule add \
  --account-name stuniptertfstateprod \
  --ip-address "203.0.113.0/24"

# Grant RBAC access (not storage keys)
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee user@Your Organization.com \
  --scope "/subscriptions/.../resourceGroups/rg-terraform-state-prod/providers/Microsoft.Storage/storageAccounts/stuniptertfstateprod"
```

### Secrets Management

```bash
# Fetch secrets from Key Vault in pipeline
$domainPassword = az keyvault secret show \
  --name "domain-join-password" \
  --vault-name "kv-Your Organization-prod" \
  --query value -o tsv

# Set Terraform variable
$env:TF_VAR_domain_join_password = $domainPassword

# Never hardcode secrets in .tfvars!
```

---

## 📚 Documentation

- **[iac/terraform/README.md](../iac/terraform/README.md)**: Terraform setup guide
- **[docs/STATE-MANAGEMENT.md](../docs/STATE-MANAGEMENT.md)**: Comprehensive state management guide
- **[ARCHITECTURE.md](../ARCHITECTURE.md)**: Architecture overview
- **[README.md](../README.md)**: Main project documentation

---

## 🎓 Learning Resources

### Official Documentation
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Terraform Backend: azurerm](https://developer.hashicorp.com/terraform/language/settings/backends/azurerm)
- [Azure Storage for Terraform State](https://learn.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage)

### Best Practices
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Azure Naming Conventions](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming)
- [Terraform Style Guide](https://developer.hashicorp.com/terraform/language/style)

---

---

## 🔄 Importing Existing Azure Resources

If you have existing Azure resources to manage with Terraform:

### Import Existing VMs

```bash
# List existing resources
az resource list --resource-group rg-app-prod --output table

# Import into Terraform state
terraform import module.virtual_machine.azurerm_windows_virtual_machine.vm[0] \
  "/subscriptions/.../resourceGroups/rg-app-prod/providers/Microsoft.Compute/virtualMachines/vm-app-prod-001"

# Verify import
terraform plan  # Should show no changes
```

### Brownfield Deployment Strategy

```bash
# Deploy new resources with Terraform
terraform apply -target=module.virtual_machine

# Verify all resources are managed
terraform state list

# Check for any drift from expected configuration
terraform plan
```

---

## 🚦 Next Steps

1. ✅ **Set up Terraform backend** (state storage account)
2. ✅ **Configure variables** (`terraform.tfvars`)
3. ✅ **Initialize Terraform** (`terraform init`)
4. ✅ **Generate and review plan** (`terraform plan`)
5. ✅ **Deploy first VM** (`terraform apply`)
6. 📖 **Read STATE-MANAGEMENT.md** (understand state operations)
7. 🔧 **Set up Azure DevOps pipeline**
8. 🔗 **Configure ServiceNow integration**
9. 📊 **Enable monitoring dashboards**
10. 🎓 **Train team on Terraform workflow**

---

## 📞 Support

For Terraform-specific questions:
- Check [iac/terraform/README.md](../iac/terraform/README.md)
- Review [docs/STATE-MANAGEMENT.md](../docs/STATE-MANAGEMENT.md)
- Contact: Azure CSA team (Pavleen Bali)

For general questions:
- Review [ARCHITECTURE.md](../ARCHITECTURE.md)
- Contact: Azure Landing Zones Team

---

**© 2025 Your Organization. All rights reserved.**
