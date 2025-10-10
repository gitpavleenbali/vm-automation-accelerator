# 🚀 Quick Start Guide - VM Automation Accelerator

**Get up and running in 10 minutes!**

---

## ✅ Prerequisites

Before you begin, ensure you have:

- [ ] **Azure Subscription** with Owner or Contributor role
- [ ] **Terraform** >= 1.5.0 installed ([Download](https://www.terraform.io/downloads))
- [ ] **Azure CLI** >= 2.50.0 installed ([Download](https://docs.microsoft.com/cli/azure/install-azure-cli))
- [ ] **jq** installed (for JSON parsing)
  - Linux: `sudo apt-get install jq`
  - macOS: `brew install jq`
  - Windows: Download from [stedolan.github.io/jq](https://stedolan.github.io/jq/)
- [ ] **Bash shell** (Git Bash on Windows, native on Linux/macOS)

---

## 🎯 Step 1: Clone & Setup (2 minutes)

```bash
# Clone the repository
git clone <your-repo-url> vm-automation-accelerator
cd vm-automation-accelerator

# Set environment variables
export ARM_SUBSCRIPTION_ID="your-subscription-id-here"
export VM_AUTOMATION_REPO_PATH="$(pwd)"
export CONFIG_REPO_PATH="$(pwd)"

# Login to Azure
az login
az account set --subscription "$ARM_SUBSCRIPTION_ID"

# Verify login
az account show
```

**💡 Tip:** Add these exports to your `~/.bashrc` or `~/.zshrc` for persistence.

---

## 🏗️ Step 2: Deploy Control Plane (5 minutes)

The control plane provides foundational infrastructure:
- Terraform state storage
- Key Vault for secrets
- Centralized management

```bash
# Make script executable
chmod +x deploy/scripts/bootstrap/deploy_control_plane.sh

# Deploy control plane
./deploy/scripts/bootstrap/deploy_control_plane.sh \
    ./boilerplate/WORKSPACES/CONTROL-PLANE/MGMT-EUS-CP01/control-plane.tfvars
```

**What happens:**
1. ✅ Validates dependencies (Terraform, Azure CLI, jq)
2. ✅ Validates parameter file
3. ✅ Initializes Terraform with local backend
4. ✅ Plans deployment
5. ✅ Asks for confirmation
6. ✅ Deploys infrastructure
7. ✅ Extracts outputs
8. ✅ Saves configuration to `.vm_deployment_automation/`

**Created resources:**
- Resource Group: `rg-vmaut-mgmt-eus-main-rg`
- Storage Account: `stvarmgmteusXXXXtfstate` (XXXX = random)
- Container: `tfstate`
- Key Vault: `kv-vmaut-mgmt-eus-XXXX-kv`

---

## 🎨 Step 3: Customize Your Deployment (Optional)

### Option A: Use Existing Templates

Choose from 6 ready-to-use templates:

```bash
# Control Plane (Management)
boilerplate/WORKSPACES/CONTROL-PLANE/MGMT-EUS-CP01/

# Workload Zones (Networks)
boilerplate/WORKSPACES/WORKLOAD-ZONE/DEV-EUS-NET01/   # Development
boilerplate/WORKSPACES/WORKLOAD-ZONE/UAT-EUS-NET01/   # UAT
boilerplate/WORKSPACES/WORKLOAD-ZONE/PROD-EUS-NET01/  # Production

# VM Deployments
boilerplate/WORKSPACES/VM-DEPLOYMENT/DEV-EUS-WEB01/   # Web servers
boilerplate/WORKSPACES/VM-DEPLOYMENT/PROD-EUS-DB01/   # Database servers
```

### Option B: Create Your Own

```bash
# Copy a template
cp -r boilerplate/WORKSPACES/WORKLOAD-ZONE/DEV-EUS-NET01/ \
      boilerplate/WORKSPACES/WORKLOAD-ZONE/MY-CUSTOM-ENV/

# Edit the tfvars file
nano boilerplate/WORKSPACES/WORKLOAD-ZONE/MY-CUSTOM-ENV/workload-zone.tfvars
```

---

## 🧪 Step 4: Test the Naming Module (3 minutes)

The naming module ensures consistent resource naming across your infrastructure.

### Create a test configuration:

```hcl
# test-naming.tf
module "naming" {
  source = "./deploy/terraform/terraform-units/modules/naming"
  
  environment   = "dev"
  location      = "eastus"
  project_code  = "test"
  workload_name = "web"
}

output "vm_name" {
  value = module.naming.vm_names["linux"][0]
}

output "storage_account" {
  value = module.naming.storage_account_names["main"]
}

output "key_vault" {
  value = module.naming.key_vault_name
}

output "all_names" {
  value = module.naming.names
}
```

### Test it:

```bash
# Initialize
terraform init

# Plan
terraform plan

# See outputs
terraform apply -auto-approve
terraform output

# Expected outputs:
# vm_name = "vm-dev-eus-web-01-vm"
# storage_account = "sttestdeveusXXXXmain"
# key_vault = "kv-test-dev-eus-XXXX-kv"
```

---

## 🔧 Step 5: Use Helper Scripts (1 minute)

The helper scripts provide reusable functions for common tasks.

### Test helper functions:

```bash
# Load helpers
source deploy/scripts/helpers/vm_helpers.sh

# Test functions
print_banner "Testing Helpers" "This is a test" "success"
validate_dependencies
get_region_code "eastus"  # Output: eus
estimate_monthly_cost "Standard_D2s_v3" "Linux" 2

# Test configuration persistence
source deploy/scripts/helpers/config_persistence.sh
config_file=$(init_config_dir "test" "eastus")
echo "Config file: $config_file"

# Save and load a variable
MY_VAR="test-value"
save_config_var "MY_VAR" "$config_file"
load_config_vars "$config_file" "MY_VAR"
echo "Loaded: $MY_VAR"
```

---

## 📊 Step 6: Verify Deployment

### Check Azure Portal

1. Go to [portal.azure.com](https://portal.azure.com)
2. Navigate to Resource Groups
3. Find `rg-vmaut-mgmt-eus-main-rg`
4. Verify resources:
   - Storage Account
   - Key Vault
   - Deployments (ARM tracking)

### Check Configuration

```bash
# View saved configuration
cat .vm_deployment_automation/mgmt-eus

# Should contain:
# TFSTATE_SUBSCRIPTION_ID=...
# TFSTATE_RESOURCE_GROUP=...
# TFSTATE_STORAGE_ACCOUNT=...
# TFSTATE_CONTAINER=tfstate
# KEYVAULT_NAME=kv-vmaut-mgmt-eus-XXXX-kv
# DEPLOYMENT_TYPE=bootstrap-control-plane
```

### Check Terraform State

```bash
cd deploy/terraform/bootstrap/control-plane
terraform show
terraform output
```

---

## 🎓 Next Steps

### Phase 2: Deploy Workload Zones (Coming Soon)

```bash
# Deploy development environment network
./deploy/scripts/deploy_workload_zone.sh \
    ./boilerplate/WORKSPACES/WORKLOAD-ZONE/DEV-EUS-NET01/workload-zone.tfvars
```

### Phase 3: Deploy VMs (Coming Soon)

```bash
# Deploy web servers
./deploy/scripts/deploy_vm.sh \
    ./boilerplate/WORKSPACES/VM-DEPLOYMENT/DEV-EUS-WEB01/vm-deployment.tfvars
```

---

## 📚 Learn More

### Documentation

- **Full README:** [`deploy/README.md`](deploy/README.md) - Complete guide with examples
- **SAP Analysis:** [`SAP-AUTOMATION-ANALYSIS.md`](SAP-AUTOMATION-ANALYSIS.md) - Pattern deep-dive
- **Implementation Summary:** [`IMPLEMENTATION-SUMMARY.md`](IMPLEMENTATION-SUMMARY.md) - What was built

### Key Concepts

1. **Naming Module:** Centralized, consistent naming for all resources
2. **Helper Scripts:** Reusable functions for common tasks
3. **Configuration Persistence:** Save state between deployments
4. **Bootstrap Pattern:** Local state → Remote state migration
5. **Control Plane:** Centralized management infrastructure

---

## 🐛 Troubleshooting

### Issue: "Terraform not found"

```bash
# Install Terraform
# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

### Issue: "Azure CLI not found"

```bash
# Install Azure CLI
# macOS
brew install azure-cli

# Linux
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

### Issue: "jq not found"

```bash
# Install jq
# macOS
brew install jq

# Linux
sudo apt-get install jq
```

### Issue: "ARM_SUBSCRIPTION_ID not set"

```bash
export ARM_SUBSCRIPTION_ID="your-subscription-id"

# Find your subscription ID
az account list --output table
```

### Issue: "Not logged in to Azure"

```bash
az login
az account set --subscription "$ARM_SUBSCRIPTION_ID"
az account show
```

### Issue: "Permission denied" on scripts

```bash
# Make scripts executable
chmod +x deploy/scripts/bootstrap/*.sh
chmod +x deploy/scripts/helpers/*.sh
```

---

## 🎯 Common Use Cases

### Use Case 1: Deploy Multiple Environments

```bash
# Deploy Dev
./deploy/scripts/bootstrap/deploy_control_plane.sh \
    boilerplate/WORKSPACES/CONTROL-PLANE/MGMT-EUS-CP01/control-plane.tfvars

# Later: Deploy UAT (when scripts are ready)
# ./deploy/scripts/deploy_workload_zone.sh \
#     boilerplate/WORKSPACES/WORKLOAD-ZONE/UAT-EUS-NET01/workload-zone.tfvars
```

### Use Case 2: Different Regions

```bash
# Copy template
cp -r boilerplate/WORKSPACES/CONTROL-PLANE/MGMT-EUS-CP01/ \
      boilerplate/WORKSPACES/CONTROL-PLANE/MGMT-WUS-CP01/

# Edit location
sed -i 's/eastus/westus/g' \
    boilerplate/WORKSPACES/CONTROL-PLANE/MGMT-WUS-CP01/control-plane.tfvars

# Deploy
./deploy/scripts/bootstrap/deploy_control_plane.sh \
    boilerplate/WORKSPACES/CONTROL-PLANE/MGMT-WUS-CP01/control-plane.tfvars
```

### Use Case 3: Custom Project Code

```bash
# Edit template
nano boilerplate/WORKSPACES/CONTROL-PLANE/MGMT-EUS-CP01/control-plane.tfvars

# Change project_code from "vmaut" to "myapp"
project_code = "myapp"

# Resource names will be:
# - rg-myapp-mgmt-eus-main-rg
# - stmyappmgmteusXXXXtfstate
# - kv-myapp-mgmt-eus-XXXX-kv
```

---

## ✅ Success Checklist

After completing this quick start, you should have:

- [x] Control plane deployed
- [x] Terraform state in Azure Storage
- [x] Key Vault created
- [x] Configuration saved in `.vm_deployment_automation/`
- [x] Tested naming module
- [x] Tested helper scripts
- [x] Verified resources in Azure Portal

---

## 🆘 Need Help?

1. **Check Documentation:**
   - [`deploy/README.md`](deploy/README.md)
   - [`SAP-AUTOMATION-ANALYSIS.md`](SAP-AUTOMATION-ANALYSIS.md)

2. **Review Examples:**
   - Boilerplate templates in `boilerplate/WORKSPACES/`

3. **Check Configuration:**
   ```bash
   cat .vm_deployment_automation/mgmt-eus
   ```

4. **Review Logs:**
   ```bash
   cd deploy/terraform/bootstrap/control-plane
   terraform show
   ```

---

## 🎉 You're Ready!

Congratulations! You've successfully:
- ✅ Deployed control plane infrastructure
- ✅ Tested naming module
- ✅ Learned helper scripts
- ✅ Verified everything works

**Next:** Explore the full documentation and customize for your needs!

---

**Version:** 1.0.0  
**Last Updated:** October 9, 2025  
**Estimated Completion Time:** 10 minutes
