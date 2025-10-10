# 🚀 Quick Reference Guide - Deployment Scripts

**Quick access guide for VM Automation Accelerator deployment scripts**

---

## 📋 Script Overview

| Script | Purpose | State Backend |
|--------|---------|---------------|
| `deploy_control_plane.sh` | Deploy remote state backend infrastructure | Local → Remote |
| `migrate_state_to_remote.sh` | Migrate state from local to remote | Local → Remote |
| `deploy_workload_zone.sh` | Deploy network infrastructure (VNet, subnets) | Remote |
| `deploy_vm.sh` | Deploy virtual machines (Linux/Windows) | Remote |

---

## 🎯 Common Commands

### **Initial Setup (One-Time)**

```bash
# 1. Deploy control plane (creates Storage Account + Key Vault)
./deploy_control_plane.sh -e dev -r eastus -p myproject

# 2. Migrate control plane to remote state
./migrate_state_to_remote.sh -m control-plane -y
```

### **Deploy Network Infrastructure**

```bash
# Development
./deploy_workload_zone.sh -e dev -r eastus

# UAT
./deploy_workload_zone.sh -e uat -r eastus2

# Production
./deploy_workload_zone.sh -e prod -r westeurope
```

### **Deploy Virtual Machines**

```bash
# Web tier
./deploy_vm.sh -e dev -r eastus -n web

# Application tier
./deploy_vm.sh -e dev -r eastus -n app

# Database tier
./deploy_vm.sh -e dev -r eastus -n db

# Jumpbox
./deploy_vm.sh -e dev -r eastus -n jumpbox
```

### **Validation (Dry Run)**

```bash
# Plan-only mode (no apply)
./deploy_workload_zone.sh -e dev -r eastus -d
./deploy_vm.sh -e dev -r eastus -n web -d
```

### **Cleanup / Destroy**

```bash
# Destroy VMs first (dependencies)
./deploy_vm.sh -e dev -r eastus -n web --destroy

# Then destroy network
./deploy_workload_zone.sh -e dev -r eastus --destroy
```

---

## 📖 Script Arguments

### **deploy_workload_zone.sh**

```bash
Usage: deploy_workload_zone.sh -e <environment> -r <region> [options]

Required:
  -e, --environment ENV    Environment (dev, uat, prod)
  -r, --region REGION     Azure region (eastus, westeurope, etc.)

Optional:
  -p, --project-code CODE Project code (default: from saved config)
  -s, --subscription ID   Subscription ID (default: current)
  -c, --control-plane-rg  Control plane resource group
  -w, --workspace PATH    Workspace configuration directory
  -d, --dry-run          Plan only (no apply)
  -y, --auto-approve     Skip confirmation
  --destroy              Destroy infrastructure
  -h, --help             Show help
```

### **deploy_vm.sh**

```bash
Usage: deploy_vm.sh -e <environment> -r <region> -n <workload> [options]

Required:
  -e, --environment ENV    Environment (dev, uat, prod)
  -r, --region REGION     Azure region (eastus, westeurope, etc.)
  -n, --name WORKLOAD     Workload name (web, app, db, cache, etc.)

Optional:
  -p, --project-code CODE Project code (default: from saved config)
  -s, --subscription ID   Subscription ID (default: current)
  -c, --control-plane-rg  Control plane resource group
  -w, --workspace PATH    Workspace configuration directory
  -d, --dry-run          Plan only (no apply)
  -y, --auto-approve     Skip confirmation
  --destroy              Destroy VMs
  -h, --help             Show help
```

### **migrate_state_to_remote.sh**

```bash
Usage: migrate_state_to_remote.sh -m <module> [options]

Required:
  -m, --module MODULE      Module (control-plane, workload-zone, vm-deployment)

Optional (for workload-zone):
  -e, --environment ENV    Environment (dev, uat, prod)
  -r, --region REGION     Azure region

Optional (for vm-deployment):
  -e, --environment ENV    Environment
  -r, --region REGION     Region
  -n, --name WORKLOAD     Workload name

Optional (all):
  -s, --subscription ID   Subscription ID
  --no-backup            Skip state backup
  -y, --auto-approve     Skip confirmation
  -h, --help             Show help
```

---

## 🔄 Deployment Workflows

### **Workflow 1: New Environment Setup**

```bash
# Step 1: Control plane (one-time)
./deploy_control_plane.sh -e dev -r eastus -p myproject
./migrate_state_to_remote.sh -m control-plane -y

# Step 2: Network infrastructure
./deploy_workload_zone.sh -e dev -r eastus

# Step 3: Virtual machines
./deploy_vm.sh -e dev -r eastus -n web
./deploy_vm.sh -e dev -r eastus -n app
./deploy_vm.sh -e dev -r eastus -n db
```

### **Workflow 2: Multi-Tier Application**

```bash
# Deploy all tiers in sequence
for tier in web app db cache; do
    ./deploy_vm.sh -e dev -r eastus -n $tier -y
done
```

### **Workflow 3: Multi-Environment Deployment**

```bash
# Deploy across environments
for env in dev uat prod; do
    ./deploy_workload_zone.sh -e $env -r eastus -y
    ./deploy_vm.sh -e $env -r eastus -n web -y
done
```

### **Workflow 4: Complete Teardown**

```bash
# Destroy all VMs first
for tier in db app web; do
    ./deploy_vm.sh -e dev -r eastus -n $tier --destroy -y
done

# Then destroy network
./deploy_workload_zone.sh -e dev -r eastus --destroy -y
```

---

## 📂 Generated Files

### **Backend Configuration**
```
.vm_deployment_automation/
├── backend-config-dev-eastus.tfbackend
├── backend-config-vm-dev-eastus-web.tfbackend
├── backend-config-vm-dev-eastus-app.tfbackend
└── backend-config-vm-dev-eastus-db.tfbackend
```

### **Deployment Outputs**
```
.vm_deployment_automation/
├── workload-zone-dev-eastus-outputs.json
├── vm-deployment-dev-eastus-web-outputs.json
├── vm-deployment-dev-eastus-app-outputs.json
└── vm-deployment-dev-eastus-db-outputs.json
```

### **State Backups**
```
deploy/terraform/bootstrap/control-plane/.state-backups/
└── terraform.tfstate.backup.YYYYMMDD_HHMMSS

deploy/terraform/run/workload-zone/.state-backups/
└── terraform.tfstate.backup.YYYYMMDD_HHMMSS
```

---

## 🔍 Checking Deployment Status

### **View Terraform State**

```bash
# Navigate to module directory
cd deploy/terraform/run/workload-zone
terraform state list

cd deploy/terraform/run/vm-deployment
terraform state list
```

### **View Deployment Outputs**

```bash
# View saved outputs
cat .vm_deployment_automation/workload-zone-dev-eastus-outputs.json | jq .
cat .vm_deployment_automation/vm-deployment-dev-eastus-web-outputs.json | jq .

# Or from Terraform directly
cd deploy/terraform/run/vm-deployment
terraform output
terraform output -json | jq .
```

### **Check Azure Portal**

```bash
# Get resource group name
az group list --query "[?tags.Environment=='dev' && tags.Region=='eastus'].name" -o table

# List resources in group
az resource list --resource-group <rg-name> -o table
```

---

## ⚙️ Environment Variables

### **Azure Authentication**
```bash
export ARM_SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000"
export ARM_TENANT_ID="00000000-0000-0000-0000-000000000000"
export ARM_CLIENT_ID="00000000-0000-0000-0000-000000000000"
export ARM_CLIENT_SECRET="your-secret"
```

### **Terraform Variables**
```bash
export TF_VAR_environment="dev"
export TF_VAR_location="eastus"
export TF_VAR_project_code="myproject"
```

---

## 🐛 Troubleshooting

### **Issue: "Control plane resource group not found"**

**Solution:**
```bash
# Deploy control plane first
./deploy_control_plane.sh -e dev -r eastus -p myproject

# Or specify resource group manually
./deploy_workload_zone.sh -e dev -r eastus -c "rg-controlplane-dev-eastus"
```

### **Issue: "Workload zone outputs not found"**

**Solution:**
```bash
# Deploy workload zone first
./deploy_workload_zone.sh -e dev -r eastus

# Verify outputs exist
ls -la .vm_deployment_automation/workload-zone-dev-eastus-outputs.json
```

### **Issue: "Terraform initialization failed"**

**Solution:**
```bash
# Clean Terraform cache
cd deploy/terraform/run/workload-zone
rm -rf .terraform .terraform.lock.hcl
terraform init -reconfigure

# Or re-run script
./deploy_workload_zone.sh -e dev -r eastus
```

### **Issue: "State lock error"**

**Solution:**
```bash
# Check for existing lock
az storage blob lease break \
  --account-name <storage-account> \
  --container-name tfstate \
  --blob-name <state-file>.tfstate

# Or force unlock (use with caution)
cd deploy/terraform/run/workload-zone
terraform force-unlock <lock-id>
```

### **Issue: "Invalid backend configuration"**

**Solution:**
```bash
# Regenerate backend config
rm .vm_deployment_automation/backend-config-*.tfbackend

# Re-run deployment
./deploy_workload_zone.sh -e dev -r eastus
```

---

## 📊 Checking Script Logs

### **Enable Verbose Output**
```bash
# Run with bash -x for debugging
bash -x ./deploy_workload_zone.sh -e dev -r eastus

# Or add to script
set -x  # Enable debug mode
set +x  # Disable debug mode
```

### **Capture Output to File**
```bash
# Save output to log file
./deploy_workload_zone.sh -e dev -r eastus 2>&1 | tee deployment.log

# Save only errors
./deploy_workload_zone.sh -e dev -r eastus 2>errors.log
```

---

## 🎯 Best Practices

### **1. Always Use Dry Run First**
```bash
# Plan first
./deploy_workload_zone.sh -e prod -r westeurope -d

# Review plan, then apply
./deploy_workload_zone.sh -e prod -r westeurope -y
```

### **2. Use Environment-Specific Workspaces**
```
boilerplate/WORKSPACES/
├── WORKLOAD-ZONE/
│   ├── dev/
│   │   └── terraform.tfvars
│   ├── uat/
│   │   └── terraform.tfvars
│   └── prod/
│       └── terraform.tfvars
└── VM-DEPLOYMENT/
    ├── dev/
    │   ├── web.tfvars
    │   ├── app.tfvars
    │   └── db.tfvars
    └── prod/
        └── web.tfvars
```

### **3. Version Control Backend Config**
```bash
# Commit backend configs to version control
git add .vm_deployment_automation/*.tfbackend
git commit -m "Add backend configurations for dev environment"
```

### **4. Regular State Backups**
```bash
# Backup current state
cd deploy/terraform/run/workload-zone
terraform state pull > backup-$(date +%Y%m%d).tfstate
```

### **5. Use Tags for Organization**
- Environment: dev, uat, prod
- Project: Project code
- CostCenter: Cost tracking
- Owner: Team/person responsible
- ManagedBy: "Terraform"

---

## 🔗 Related Documentation

- [DEPLOYMENT-SCRIPTS-COMPLETE.md](./DEPLOYMENT-SCRIPTS-COMPLETE.md) - Detailed script documentation
- [ARCHITECTURE-DIAGRAM.md](./ARCHITECTURE-DIAGRAM.md) - Infrastructure architecture
- [VM-DEPLOYMENT-COMPLETE.md](./VM-DEPLOYMENT-COMPLETE.md) - VM module documentation
- [README.md](./README.md) - Project overview

---

## 🆘 Getting Help

### **View Script Help**
```bash
./deploy_workload_zone.sh -h
./deploy_vm.sh -h
./migrate_state_to_remote.sh -h
```

### **Check Prerequisites**
```bash
# Terraform version
terraform version

# Azure CLI version
az version

# Authentication status
az account show

# jq version
jq --version
```

---

**Last Updated:** 2025-10-09  
**Version:** 1.0.0
