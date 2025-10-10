# Migration Guide: Day 1/Day 3 → Unified Solution

## Table of Contents

1. [Overview](#overview)
2. [Pre-Migration Assessment](#pre-migration-assessment)
3. [Breaking Changes](#breaking-changes)
4. [Migration Paths](#migration-paths)
5. [Step-by-Step Migration](#step-by-step-migration)
6. [Testing & Validation](#testing--validation)
7. [Rollback Procedures](#rollback-procedures)
8. [Post-Migration Tasks](#post-migration-tasks)

---

## Overview

This guide provides comprehensive instructions for migrating from either Day 1 (AVM-focused) or Day 3 (SAP-orchestrated) solutions to the Unified VM Automation Accelerator.

### Migration Benefits

**From Day 1 Solution**:
- ✅ Gain ServiceNow self-service capabilities
- ✅ Add Day 2 operations (disk modify, SKU change, backup/restore)
- ✅ Implement SAP orchestration patterns
- ✅ Add Azure DevOps pipeline automation
- ✅ Keep all AVM security patterns

**From Day 3 Solution**:
- ✅ Enhance with AVM security patterns
- ✅ Add managed identity support
- ✅ Implement encryption at host
- ✅ Add Trusted Launch capabilities
- ✅ Improve module quality with AVM standards

### Migration Timeline

| Phase | Duration | Activities |
|-------|----------|------------|
| Assessment | 2-3 days | Inventory, gap analysis, planning |
| Preparation | 3-5 days | Tool setup, access validation, testing environment |
| Migration | 5-10 days | Code migration, testing, validation |
| Validation | 3-5 days | End-to-end testing, performance validation |
| Production | 2-3 days | Production cutover, monitoring |
| **Total** | **15-26 days** | Complete migration with validation |

---

## Pre-Migration Assessment

### Current State Inventory

#### For Day 1 Users

**What to Document**:
- [ ] Number of Terraform modules currently in use
- [ ] VM count and configuration (sizes, OS types, regions)
- [ ] Custom Azure Policy assignments
- [ ] Key Vault secrets and certificates
- [ ] Managed identities in use
- [ ] Network configurations (VNets, subnets, NSGs)
- [ ] Monitoring configurations (Log Analytics, alerts)
- [ ] Backup policies and protected items

**Terraform State Files**:
```bash
# List current state files
ls -R iac/terraform/*.tfstate
terraform state list  # Run in each module directory
```

#### For Day 3 Users

**What to Document**:
- [ ] ServiceNow catalog items in use
- [ ] Azure DevOps pipeline configurations
- [ ] Shell script customizations
- [ ] Terraform workspace configurations
- [ ] Environment-specific configurations (dev/uat/prod)
- [ ] API wrapper integrations
- [ ] Deployment records and audit logs

**Pipeline Inventory**:
```bash
# List active pipelines
az pipelines list --project <project-name>

# Check pipeline run history
az pipelines runs list --pipeline-id <id>
```

### Gap Analysis

**Identify Customizations**:
1. Custom Terraform modules not in standard solution
2. Modified shell scripts
3. Additional ServiceNow catalog fields
4. Custom Azure Policy definitions
5. Non-standard networking requirements

**Template for Gap Documentation**:
```markdown
| Component | Current State | Unified Solution | Action Required |
|-----------|---------------|------------------|-----------------|
| Compute Module | Custom network config | Standard module | Migrate custom config |
| API Wrapper | Additional validation | Standard wrapper | Preserve validation logic |
| ... | ... | ... | ... |
```

### Prerequisites Checklist

- [ ] **Azure Access**:
  - [ ] Subscription Owner or Contributor role
  - [ ] Permission to create service principals
  - [ ] Access to Key Vault (if using secrets)

- [ ] **Tools Installed**:
  - [ ] Azure CLI >= 2.50.0
  - [ ] Terraform >= 1.5.0
  - [ ] Git >= 2.30.0
  - [ ] jq >= 1.6 (for JSON parsing)
  - [ ] PowerShell >= 7.0 (Windows) or Bash >= 5.0 (Linux)

- [ ] **Azure DevOps**:
  - [ ] Project created
  - [ ] Service connection configured
  - [ ] Pipeline permissions granted

- [ ] **ServiceNow** (if applicable):
  - [ ] REST API access
  - [ ] Catalog import permissions
  - [ ] Workflow configuration access

---

## Breaking Changes

### Critical Breaking Changes

#### 1. Directory Structure Change

**Old (Day 1)**:
```
iac/terraform/modules/compute/
iac/terraform/modules/monitoring/
```

**New (Unified)**:
```
deploy/terraform/terraform-units/modules/compute/
deploy/terraform/terraform-units/modules/monitoring/
```

**Impact**: All module source paths must be updated

**Migration Action**:
```hcl
# OLD
module "compute" {
  source = "../../iac/terraform/modules/compute"
}

# NEW
module "compute" {
  source = "../../terraform-units/modules/compute"
}
```

#### 2. Compute Module Variable Changes

**Breaking Change**: `managed_identities` structure changed

**Old (Day 1)**:
```hcl
managed_identities = {
  system_assigned            = true
  user_assigned_resource_ids = ["/subscriptions/.../identity1"]
}
```

**New (Unified)**: *Same structure* - ✅ No breaking change for Day 1 users

**For Day 3 Users** (adding managed identities):
```hcl
# Must ADD this variable to existing VM configs
vms = {
  web01 = {
    # ... existing config ...
    
    # NEW: Add managed identity support
    managed_identities = {
      system_assigned            = true
      user_assigned_resource_ids = []
    }
  }
}
```

#### 3. State Backend Configuration

**Old (Day 3)**:
```hcl
backend "azurerm" {
  key = "vm-deployment.tfstate"
}
```

**New (Unified)**:
```hcl
backend "azurerm" {
  key = "vm-deployment/${environment}/${workload}.tfstate"
}
```

**Impact**: State file location changes

**Migration Strategy**: 
- Option A: Migrate state (complex, not recommended)
- Option B: Fresh deployment with controlled cutover (recommended)

#### 4. Pipeline YAML Structure

**Old (Day 3)**: Single-file pipeline

**New (Unified)**: Multi-stage pipeline with templates

**Impact**: Pipeline definitions must be updated

**Migration Action**: Replace entire pipeline YAML with unified version

### Non-Breaking Changes (Backward Compatible)

- ✅ Monitoring module variable names (unchanged)
- ✅ Network module structure (unchanged)
- ✅ ServiceNow JSON payload format (backward compatible)
- ✅ API wrapper endpoints (unchanged)

---

## Migration Paths

### Path A: Day 1 → Unified (Greenfield Migration)

**Scenario**: Deploying new workloads with unified solution

**Steps**:
1. Set up unified repository structure
2. Update module references
3. Deploy new workloads using unified pipelines
4. Gradually migrate existing workloads during maintenance windows

**Recommended For**:
- New projects
- Non-critical environments (dev/test)
- Workloads with flexible maintenance windows

### Path B: Day 3 → Unified (In-Place Upgrade)

**Scenario**: Enhancing existing Day 3 deployment with AVM patterns

**Steps**:
1. Merge AVM patterns into existing modules
2. Add managed identity support
3. Enable encryption at host
4. Update pipelines to reference enhanced modules
5. Test in dev environment first

**Recommended For**:
- Production workloads with minimal downtime requirement
- Large-scale deployments (50+ VMs)
- Environments with complex dependencies

### Path C: Parallel Deployment (Blue/Green)

**Scenario**: Running unified solution alongside existing solution

**Steps**:
1. Deploy unified solution in parallel
2. Route new requests to unified solution
3. Migrate existing workloads gradually
4. Decommission old solution when migration complete

**Recommended For**:
- Mission-critical workloads
- Compliance-sensitive environments
- Risk-averse organizations

---

## Step-by-Step Migration

### Phase 1: Preparation (Days 1-5)

#### Day 1-2: Environment Setup

**1. Clone Unified Repository**:
```bash
git clone <unified-repo-url>
cd vm-automation-accelerator
```

**2. Set Up Azure Resources**:
```bash
# Create resource group for Terraform state
az group create \
  --name rg-terraform-state-prod \
  --location eastus

# Create storage account for state
az storage account create \
  --name sttfstateprod \
  --resource-group rg-terraform-state-prod \
  --sku Standard_LRS \
  --encryption-services blob

# Create container
az storage container create \
  --name tfstate \
  --account-name sttfstateprod
```

**3. Create Service Principal**:
```bash
# Create SP for Terraform
az ad sp create-for-rbac \
  --name sp-terraform-unified \
  --role Contributor \
  --scopes /subscriptions/<subscription-id>

# Save output: appId, password, tenant
```

**4. Configure Azure DevOps**:
```bash
# Create project
az devops project create \
  --name "VM-Automation-Unified"

# Create service connection
az devops service-endpoint azurerm create \
  --name "Azure-Terraform-Connection" \
  --azure-rm-service-principal-id <appId> \
  --azure-rm-subscription-id <subscription-id> \
  --azure-rm-subscription-name <subscription-name> \
  --azure-rm-tenant-id <tenant-id>
```

#### Day 3-4: Code Migration

**From Day 1**:

**1. Update Module Paths**:
```bash
# Find all module references
grep -r "source.*modules" .

# Replace with unified paths
sed -i 's|../../iac/terraform/modules/|../../terraform-units/modules/|g' *.tf
```

**2. Verify AVM Patterns** (already present in Day 1):
- ✅ Managed identities: No change needed
- ✅ Encryption at host: No change needed
- ✅ Trusted Launch: No change needed

**3. Add Orchestration Layer**:
```bash
# Copy pipeline files
cp deploy/pipelines/* <your-repo>/pipelines/

# Copy shell scripts
cp deploy/scripts/* <your-repo>/scripts/

# Update variables in scripts
nano scripts/deploy_vm.sh  # Update subscription IDs, resource groups
```

**From Day 3**:

**1. Enhance Compute Module**:
```bash
# Back up current module
cp -r terraform/modules/compute terraform/modules/compute.bak

# Replace with unified module
cp -r deploy/terraform/terraform-units/modules/compute terraform/modules/
```

**2. Update VM Configurations**:

Add managed identity support:
```hcl
# In your vm-deployment/main.tf
module "vms" {
  source = "../../terraform-units/modules/compute"
  
  vms = {
    web01 = {
      vm_name  = "vm-web01-prod"
      vm_size  = "Standard_D2s_v3"
      # ... existing config ...
      
      # ADD: Managed identity (AVM pattern)
      managed_identities = {
        system_assigned            = true
        user_assigned_resource_ids = []
      }
      
      # ADD: Encryption at host (AVM pattern)
      encryption_at_host_enabled = true
      
      # ADD: Trusted Launch (AVM pattern)
      enable_secure_boot = true
      enable_vtpm        = true
    }
  }
}
```

**3. Add Monitoring Module**:
```bash
# Copy monitoring module
cp -r deploy/terraform/terraform-units/modules/monitoring terraform/modules/
```

```hcl
# In your vm-deployment/main.tf
module "monitoring" {
  for_each = module.vms.vm_ids
  
  source = "../../terraform-units/modules/monitoring"
  
  vm_id                       = each.value
  vm_name                     = each.key
  resource_group_name         = var.resource_group_name
  location                    = var.location
  os_type                     = lookup(var.vms[each.key], "os_type", "Linux")
  log_analytics_workspace_id  = var.log_analytics_workspace_id
  log_analytics_workspace_key = var.log_analytics_workspace_key
  
  enable_vm_insights = true
  
  tags = var.tags
}
```

**4. Add Backup Module**:
```bash
# Copy backup module
cp -r deploy/terraform/terraform-units/modules/backup-policy terraform/modules/
```

```hcl
# In your vm-deployment/main.tf
module "backup" {
  source = "../../terraform-units/modules/backup-policy"
  
  resource_group_name = var.resource_group_name
  location            = var.location
  vault_name          = "rsv-backup-${var.environment}"
  
  backup_policies = {
    daily = {
      name      = "daily-backup-${var.environment}"
      frequency = "Daily"
      time      = "23:00"
      retention_daily_count = 30
    }
  }
  
  protected_vms = {
    for k, v in module.vms.vm_ids : k => {
      vm_id       = v
      policy_name = "daily"
    }
  }
  
  tags = var.tags
}
```

#### Day 5: ServiceNow Integration (Optional)

**1. Import Catalog Items**:
```bash
# From ServiceNow admin console:
# System Definition > Catalog Items > Import XML

# Import files:
deploy/servicenow/catalog-items/vm-order-catalog-item.xml
deploy/servicenow/catalog-items/vm-disk-modify-catalog-item.xml
deploy/servicenow/catalog-items/vm-sku-change-catalog-item.xml
deploy/servicenow/catalog-items/vm-restore-catalog-item.xml
```

**2. Configure API Wrappers**:
```bash
# Copy API wrappers to execution environment
cp deploy/servicenow/api/*.sh /opt/servicenow-api/

# Make executable
chmod +x /opt/servicenow-api/*.sh

# Set environment variables
export AZURE_DEVOPS_ORG="https://dev.azure.com/<org>"
export AZURE_DEVOPS_PROJECT="VM-Automation-Unified"
export AZURE_DEVOPS_PAT="<personal-access-token>"
export SNOW_INSTANCE="<instance>.service-now.com"
export SNOW_USERNAME="<api-user>"
export SNOW_PASSWORD="<api-password>"
```

### Phase 2: Testing (Days 6-10)

#### Day 6-7: Dev Environment Testing

**1. Deploy Test VM**:
```bash
# Navigate to vm-deployment directory
cd deploy/terraform/run/vm-deployment

# Initialize Terraform
terraform init \
  -backend-config="resource_group_name=rg-terraform-state-dev" \
  -backend-config="storage_account_name=sttfstatedev" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=vm-deployment/dev/test-workload.tfstate"

# Plan deployment
terraform plan \
  -var="environment=dev" \
  -var="workload_name=test-workload" \
  -out=tfplan

# Apply
terraform apply tfplan
```

**2. Validate VM Creation**:
```bash
# Check VM status
az vm show \
  --resource-group rg-vms-dev \
  --name vm-test01-dev \
  --query "provisioningState"

# Verify managed identity
az vm identity show \
  --resource-group rg-vms-dev \
  --name vm-test01-dev

# Check encryption at host
az vm show \
  --resource-group rg-vms-dev \
  --name vm-test01-dev \
  --query "securityProfile.encryptionAtHost"
```

**3. Test Monitoring**:
```bash
# Verify Azure Monitor Agent installed
az vm extension list \
  --resource-group rg-vms-dev \
  --vm-name vm-test01-dev \
  --query "[?publisher=='Microsoft.Azure.Monitor'].{Name:name,Status:provisioningState}"

# Query Log Analytics for VM data
az monitor log-analytics query \
  --workspace <workspace-id> \
  --analytics-query "Heartbeat | where Computer == 'vm-test01-dev' | take 10"
```

**4. Test Backup**:
```bash
# Verify backup protection
az backup protection check-vm \
  --resource-group rg-vms-dev \
  --vm-name vm-test01-dev

# Trigger on-demand backup
az backup protection backup-now \
  --resource-group rg-backup-dev \
  --vault-name rsv-backup-dev \
  --container-name <container-name> \
  --item-name vm-test01-dev \
  --retain-until $(date -d "+30 days" +%d-%m-%Y)
```

#### Day 8-9: Day 2 Operations Testing

**1. Test Disk Operations**:
```bash
# Add disk
./scripts/vm_operations.sh \
  --operation add-disk \
  --vm-name vm-test01-dev \
  --disk-name data-disk-01 \
  --disk-size 128 \
  --disk-type Premium_LRS

# Verify disk attached
az vm show \
  --resource-group rg-vms-dev \
  --name vm-test01-dev \
  --query "storageProfile.dataDisks"

# Resize disk
./scripts/vm_operations.sh \
  --operation resize-disk \
  --vm-name vm-test01-dev \
  --disk-name data-disk-01 \
  --new-size 256

# Delete disk
./scripts/vm_operations.sh \
  --operation delete-disk \
  --vm-name vm-test01-dev \
  --disk-name data-disk-01
```

**2. Test SKU Change**:
```bash
# Change VM size
./scripts/vm_operations.sh \
  --operation change-size \
  --vm-name vm-test01-dev \
  --new-size Standard_D4s_v3

# Verify new size
az vm show \
  --resource-group rg-vms-dev \
  --name vm-test01-dev \
  --query "hardwareProfile.vmSize"
```

**3. Test Backup Restore**:
```bash
# List recovery points
./scripts/vm_operations.sh \
  --operation list-recovery-points \
  --vm-name vm-test01-dev

# Restore VM
./scripts/vm_operations.sh \
  --operation restore \
  --vm-name vm-test01-dev \
  --recovery-point-id <recovery-point-id>
```

#### Day 10: Performance & Load Testing

**Performance Metrics to Validate**:
- [ ] VM deployment time < 15 minutes
- [ ] Pipeline execution time < 20 minutes
- [ ] API wrapper response time < 5 seconds
- [ ] ServiceNow catalog submission < 3 seconds
- [ ] Terraform plan/apply success rate > 99%

**Load Testing**:
```bash
# Deploy 10 VMs concurrently
for i in {1..10}; do
  az pipelines run \
    --name vm-deployment-pipeline \
    --parameters environment=dev vmName=vm-load-test-$i &
done

# Monitor pipeline runs
az pipelines runs list \
  --query "[?status=='inProgress']" \
  --output table
```

### Phase 3: UAT Migration (Days 11-15)

#### Day 11-12: UAT Deployment

**1. Update UAT Configuration**:
```hcl
# deploy/terraform/run/vm-deployment/terraform.uat.tfvars
environment      = "uat"
workload_name    = "<your-workload>"
resource_group_name = "rg-vms-uat"
location         = "eastus"

vms = {
  app01 = {
    vm_name               = "vm-app01-uat"
    os_type               = "linux"
    vm_size               = "Standard_D4s_v3"
    availability_set_name = "avset-app-uat"
    
    managed_identities = {
      system_assigned            = true
      user_assigned_resource_ids = []
    }
    
    encryption_at_host_enabled = true
    enable_secure_boot         = true
    enable_vtpm                = true
  }
  
  app02 = {
    # ... similar config ...
  }
}
```

**2. Deploy UAT Environment**:
```bash
terraform apply \
  -var-file="terraform.uat.tfvars" \
  -out=uat.tfplan

terraform apply uat.tfplan
```

#### Day 13-14: UAT Testing

**Test Scenarios**:
1. [ ] End-to-end ServiceNow catalog submission
2. [ ] Pipeline approval workflows
3. [ ] Monitoring agent deployment and data collection
4. [ ] Backup policy application and verification
5. [ ] Governance policy enforcement (Audit mode in UAT)
6. [ ] Day 2 operations (disk, SKU, backup/restore)

**User Acceptance Testing**:
- [ ] IT team tests ServiceNow catalogs
- [ ] Operations team tests Day 2 operations
- [ ] Security team validates encryption and compliance
- [ ] Application team tests VM functionality

#### Day 15: UAT Sign-off

**Sign-off Checklist**:
- [ ] All test scenarios passed
- [ ] Performance meets requirements
- [ ] Security controls validated
- [ ] Documentation reviewed
- [ ] Training completed
- [ ] Rollback plan approved

### Phase 4: Production Migration (Days 16-20)

#### Day 16-17: Production Preparation

**1. Production Configuration Review**:
```hcl
# deploy/terraform/run/vm-deployment/terraform.prod.tfvars
environment      = "prod"
workload_name    = "<your-workload>"

# Production-specific settings
vault_sku                  = "Standard"
storage_mode_type          = "GeoRedundant"
enable_cross_region_restore = true
enable_soft_delete         = true

# Governance: Deny mode in prod
governance_policy_effect = "Deny"

vms = {
  # ... production VM configs ...
}
```

**2. Pre-Production Checklist**:
- [ ] Backup current production configuration
- [ ] Document current VM inventory
- [ ] Create rollback plan
- [ ] Schedule maintenance window
- [ ] Notify stakeholders
- [ ] Prepare incident response team

**3. Backup Current State**:
```bash
# Export current VM configurations
az vm list --query "[].{name:name,rg:resourceGroup,size:hardwareProfile.vmSize}" -o json > prod-vms-backup.json

# Backup Terraform state (if migrating state)
az storage blob download \
  --account-name sttfstateprod \
  --container-name tfstate \
  --name vm-deployment.tfstate \
  --file vm-deployment.tfstate.backup
```

#### Day 18-19: Production Deployment

**Option A: Parallel Deployment (Recommended)**

**1. Deploy New Infrastructure**:
```bash
# Deploy with new naming convention
terraform apply \
  -var="vm_name_prefix=vm-new" \
  -var-file="terraform.prod.tfvars"

# VMs created: vm-new-app01-prod, vm-new-app02-prod, etc.
```

**2. Test New VMs**:
```bash
# Verify new VMs operational
# Run application smoke tests
# Validate monitoring and backup
```

**3. Traffic Cutover**:
```bash
# Update load balancer backend pool
az network lb address-pool address add \
  --lb-name lb-prod \
  --pool-name backend-pool \
  --vnet <vnet-name> \
  --ip-address <new-vm-ip>

# Remove old VMs from pool
az network lb address-pool address remove \
  --lb-name lb-prod \
  --pool-name backend-pool \
  --ip-address <old-vm-ip>
```

**4. Decommission Old VMs** (after validation period):
```bash
# Stop old VMs (keep for rollback)
az vm stop --ids $(az vm list --query "[?starts_with(name,'vm-old')].id" -o tsv)

# After 7 days: Delete old VMs
az vm delete --ids $(az vm list --query "[?starts_with(name,'vm-old')].id" -o tsv) --yes
```

**Option B: In-Place Upgrade** (Higher Risk)

**1. Maintenance Mode**:
```bash
# Stop application traffic
# Drain connections
# Stop VMs
az vm stop --resource-group rg-vms-prod --name vm-app01-prod
```

**2. Apply Infrastructure Updates**:
```bash
# Update Terraform configuration
terraform apply -var-file="terraform.prod.tfvars"

# This will update VM properties in-place where possible
# Some changes may require VM recreation
```

**3. Restart and Validate**:
```bash
# Start VMs
az vm start --resource-group rg-vms-prod --name vm-app01-prod

# Run validation tests
# Resume application traffic
```

#### Day 20: Production Validation

**Post-Deployment Validation**:
```bash
# 1. Verify all VMs running
az vm list \
  --resource-group rg-vms-prod \
  --query "[].{Name:name,State:powerState,Provisioning:provisioningState}" \
  --output table

# 2. Check managed identities
for vm in $(az vm list --resource-group rg-vms-prod --query "[].name" -o tsv); do
  echo "VM: $vm"
  az vm identity show --resource-group rg-vms-prod --name $vm
done

# 3. Verify encryption at host
az vm list \
  --resource-group rg-vms-prod \
  --query "[].{Name:name,EncryptionAtHost:securityProfile.encryptionAtHost}"

# 4. Check monitoring agents
az vm extension list \
  --resource-group rg-vms-prod \
  --vm-name vm-app01-prod \
  --query "[?publisher=='Microsoft.Azure.Monitor'].name"

# 5. Verify backup protection
az backup container list \
  --resource-group rg-backup-prod \
  --vault-name rsv-backup-prod \
  --backup-management-type AzureIaasVM

# 6. Test Day 2 operations
./scripts/vm_operations.sh --operation list-recovery-points --vm-name vm-app01-prod
```

**Monitoring Setup**:
```bash
# Create alerts for new VMs
az monitor metrics alert create \
  --name "vm-app01-prod-cpu-high" \
  --resource-group rg-vms-prod \
  --scopes $(az vm show --resource-group rg-vms-prod --name vm-app01-prod --query id -o tsv) \
  --condition "avg Percentage CPU > 80" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action-group <action-group-id>
```

---

## Testing & Validation

### Test Matrix

| Test Scenario | Environment | Expected Result | Pass/Fail |
|---------------|-------------|-----------------|-----------|
| Deploy single VM | Dev | VM created with managed identity | ☐ |
| Deploy VM with data disks | Dev | VM + 2 data disks created | ☐ |
| Deploy availability set VMs | Dev | 2 VMs in same avset | ☐ |
| Add disk to existing VM | Dev | Disk attached successfully | ☐ |
| Resize disk | Dev | Disk size increased | ☐ |
| Change VM size | Dev | VM resized successfully | ☐ |
| List backup recovery points | Dev | Recovery points listed | ☐ |
| Restore VM from backup | Dev | VM restored from snapshot | ☐ |
| Deploy with monitoring | UAT | AMA and DCR deployed | ☐ |
| Deploy with backup | UAT | Backup protection enabled | ☐ |
| Governance policy enforcement | UAT | Policy violations audited | ☐ |
| ServiceNow catalog submission | UAT | VM provisioned from ServiceNow | ☐ |
| Production deployment | Prod | All VMs operational | ☐ |
| Production monitoring | Prod | Metrics flowing to Log Analytics | ☐ |
| Production backup | Prod | First backup completed | ☐ |

### Validation Scripts

**1. Comprehensive VM Validation**:
```bash
#!/bin/bash
# validate_vm.sh

VM_NAME=$1
RESOURCE_GROUP=$2

echo "Validating VM: $VM_NAME in RG: $RESOURCE_GROUP"

# Check VM exists and is running
STATE=$(az vm get-instance-view \
  --name $VM_NAME \
  --resource-group $RESOURCE_GROUP \
  --query "instanceView.statuses[?starts_with(code, 'PowerState')].displayStatus" \
  --output tsv)

if [ "$STATE" != "VM running" ]; then
  echo "❌ VM is not running. Current state: $STATE"
  exit 1
fi
echo "✅ VM is running"

# Check managed identity
IDENTITY_TYPE=$(az vm show \
  --name $VM_NAME \
  --resource-group $RESOURCE_GROUP \
  --query "identity.type" \
  --output tsv)

if [ "$IDENTITY_TYPE" == "SystemAssigned" ] || [ "$IDENTITY_TYPE" == "SystemAssigned, UserAssigned" ]; then
  echo "✅ Managed identity enabled: $IDENTITY_TYPE"
else
  echo "❌ Managed identity not enabled"
fi

# Check encryption at host
ENCRYPTION=$(az vm show \
  --name $VM_NAME \
  --resource-group $RESOURCE_GROUP \
  --query "securityProfile.encryptionAtHost" \
  --output tsv)

if [ "$ENCRYPTION" == "true" ]; then
  echo "✅ Encryption at host enabled"
else
  echo "⚠️  Encryption at host not enabled"
fi

# Check Azure Monitor Agent
AMA_STATUS=$(az vm extension show \
  --resource-group $RESOURCE_GROUP \
  --vm-name $VM_NAME \
  --name AzureMonitorLinuxAgent \
  --query "provisioningState" \
  --output tsv 2>/dev/null)

if [ "$AMA_STATUS" == "Succeeded" ]; then
  echo "✅ Azure Monitor Agent installed"
else
  echo "⚠️  Azure Monitor Agent not installed"
fi

# Check backup protection
BACKUP_PROTECTED=$(az backup protection check-vm \
  --vm-id $(az vm show --name $VM_NAME --resource-group $RESOURCE_GROUP --query id -o tsv) \
  --query "protectionState" \
  --output tsv 2>/dev/null)

if [ "$BACKUP_PROTECTED" == "Protected" ]; then
  echo "✅ Backup protection enabled"
else
  echo "⚠️  Backup protection not enabled"
fi

echo "Validation complete!"
```

**2. Run Validation**:
```bash
chmod +x validate_vm.sh
./validate_vm.sh vm-app01-prod rg-vms-prod
```

---

## Rollback Procedures

### Scenario 1: Rollback During Dev/UAT Testing

**If Issues Found**:
```bash
# Simply destroy test environment
cd deploy/terraform/run/vm-deployment
terraform destroy -var-file="terraform.dev.tfvars"

# Revert code changes
git checkout <previous-commit>

# Redeploy with previous version
terraform apply
```

### Scenario 2: Rollback During Production Migration (Parallel Deployment)

**Rollback Steps**:
```bash
# 1. Route traffic back to old VMs
az network lb address-pool address add \
  --lb-name lb-prod \
  --pool-name backend-pool \
  --ip-address <old-vm-ip>

# 2. Remove new VMs from load balancer
az network lb address-pool address remove \
  --lb-name lb-prod \
  --pool-name backend-pool \
  --ip-address <new-vm-ip>

# 3. Stop new VMs (keep for troubleshooting)
az vm stop --ids $(az vm list --query "[?starts_with(name,'vm-new')].id" -o tsv)

# 4. Verify old VMs operational
az vm list \
  --query "[?starts_with(name,'vm-old')].{Name:name,State:powerState}" \
  --output table

# 5. Resume normal operations
```

### Scenario 3: Rollback During Production Migration (In-Place Upgrade)

**Critical: Requires VM recreation**

**Rollback Steps**:
```bash
# 1. Stop current VMs
az vm stop --resource-group rg-vms-prod --name vm-app01-prod

# 2. Restore from backup
az backup restore restore-azurevm \
  --resource-group rg-backup-prod \
  --vault-name rsv-backup-prod \
  --container-name <container-name> \
  --item-name vm-app01-prod \
  --rp-name <recovery-point-before-migration> \
  --target-resource-group rg-vms-prod \
  --storage-account <staging-storage>

# 3. Alternatively: Redeploy from previous Terraform state
terraform init \
  -backend-config="key=vm-deployment/prod/workload.tfstate.backup"

terraform apply -var-file="terraform.prod.tfvars.backup"
```

**Rollback Decision Matrix**:

| Issue | Severity | Rollback Action | Rollback Time |
|-------|----------|-----------------|---------------|
| Performance degradation < 10% | Low | Monitor, optimize | No rollback |
| Monitoring not working | Medium | Fix forward | No rollback |
| VM not starting | High | Restore from backup | 2-4 hours |
| Data corruption | Critical | Immediate rollback | 1-2 hours |
| Security vulnerability | Critical | Immediate rollback | < 1 hour |

---

## Post-Migration Tasks

### Day 1 Post-Migration

**Immediate Tasks**:
- [ ] Confirm all production VMs running
- [ ] Verify monitoring data flowing
- [ ] Check backup job completion
- [ ] Review Azure Activity Logs for errors
- [ ] Update runbooks and documentation
- [ ] Send migration completion notification

**Monitoring Setup**:
```bash
# Set up comprehensive alerts
az monitor action-group create \
  --name ag-vm-prod-alerts \
  --resource-group rg-monitoring-prod \
  --short-name vm-alerts \
  --email-receiver name=ops-team email=ops@company.com

# VM availability alert
az monitor metrics alert create \
  --name vm-availability-prod \
  --resource-group rg-vms-prod \
  --scopes $(az vm list --resource-group rg-vms-prod --query "[].id" -o tsv) \
  --condition "avg Percentage CPU > 0" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action-group ag-vm-prod-alerts
```

### Week 1 Post-Migration

**Validation Tasks**:
- [ ] Verify first backup completed successfully
- [ ] Review monitoring dashboards
- [ ] Check governance policy compliance reports
- [ ] Validate ServiceNow integration working
- [ ] Review performance metrics vs. baseline
- [ ] Collect user feedback

**Performance Baseline**:
```bash
# Capture performance metrics
az monitor metrics list \
  --resource $(az vm show --name vm-app01-prod --resource-group rg-vms-prod --query id -o tsv) \
  --metric-names "Percentage CPU" "Available Memory Bytes" "Disk Read Bytes" \
  --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --interval PT1H \
  --output table > performance-baseline.txt
```

### Month 1 Post-Migration

**Optimization Tasks**:
- [ ] Analyze cost optimization opportunities
- [ ] Review and optimize backup policies
- [ ] Fine-tune monitoring and alerting
- [ ] Conduct security review
- [ ] Update disaster recovery plan
- [ ] Archive old infrastructure

**Cost Analysis**:
```bash
# Review cost by resource
az costmanagement query \
  --type Usage \
  --dataset-aggregation name=Cost function=Sum \
  --dataset-grouping name=ResourceGroup type=Dimension \
  --timeframe MonthToDate \
  --query "rows" \
  --output table

# Identify cost-saving opportunities
# - Unused disks
# - Over-provisioned VMs
# - Redundant backup policies
```

**Decommission Old Infrastructure** (after validation period):
```bash
# Archive old Terraform code
git archive --format=tar.gz --prefix=old-solution/ \
  -o old-solution-$(date +%Y%m%d).tar.gz HEAD:iac/

# Delete old resource groups (after final backup)
az group delete --name rg-old-vms-prod --yes --no-wait

# Update documentation
# Remove deprecated runbooks
# Archive old pipeline definitions
```

---

## Summary Checklist

### Pre-Migration
- [ ] Current state documented
- [ ] Gap analysis completed
- [ ] Prerequisites met
- [ ] Testing environment ready
- [ ] Rollback plan prepared

### Migration Execution
- [ ] Dev environment migrated and tested
- [ ] UAT environment migrated and tested
- [ ] Production migration completed
- [ ] All validations passed
- [ ] Documentation updated

### Post-Migration
- [ ] Day 1 tasks completed
- [ ] Week 1 validation done
- [ ] Month 1 optimization complete
- [ ] Old infrastructure decommissioned
- [ ] Lessons learned documented

---

## Support and Escalation

### Common Issues and Solutions

**Issue: Terraform state lock conflict**
```bash
# Force unlock (use with caution)
terraform force-unlock <lock-id>
```

**Issue: Module not found**
```bash
# Reinitialize Terraform
terraform init -upgrade
```

**Issue: Azure CLI authentication expired**
```bash
# Re-authenticate
az login
az account set --subscription <subscription-id>
```

### Escalation Path

| Issue Severity | Contact | Response Time |
|----------------|---------|---------------|
| Critical (P1) | ops-team@company.com | 15 minutes |
| High (P2) | support@company.com | 1 hour |
| Medium (P3) | helpdesk@company.com | 4 hours |
| Low (P4) | helpdesk@company.com | 1 business day |

---

**Document Version**: 1.0  
**Last Updated**: 2024  
**Maintained By**: Uniper VM Automation Team
