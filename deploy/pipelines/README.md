# Azure DevOps Pipelines - Unified Solution
## SAP Automation Framework + Enterprise Features

**Created**: October 10, 2025  
**Status**: Phase 2 - Pipeline Integration ACTIVE  
**Version**: 1.0.0

---

## 📋 Overview

This directory contains Azure DevOps CI/CD pipelines that integrate **SAP Automation Framework patterns** with **enterprise features** from the original solution. The pipelines orchestrate deployment of VM infrastructure using a hierarchical approach: Control Plane → Workload Zone → VM Deployment.

### **Key Features**
✅ SAP-style deployment scripts integration  
✅ Bootstrap → Run state migration support  
✅ Multi-environment support (dev, uat, prod)  
✅ Approval gates for production  
✅ Reusable pipeline templates  
✅ Security scanning (Checkov)  
✅ Comprehensive logging and artifacts  
✅ ServiceNow integration ready  
✅ Governance policy enforcement  

---

## 🏗️ Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     FULL DEPLOYMENT PIPELINE                     │
│                  (Orchestrates all components)                   │
└───────────────┬──────────────────┬───────────────┬───────────────┘
                │                  │               │
                ▼                  ▼               ▼
    ┌───────────────────┐  ┌──────────────┐  ┌────────────────┐
    │  Control Plane    │  │  Workload    │  │  VM           │
    │  Pipeline         │  │  Zone        │  │  Deployment   │
    │                   │  │  Pipeline    │  │  Pipeline     │
    │ • State Storage   │  │ • VNet       │  │ • VMs         │
    │ • Naming          │  │ • Subnets    │  │ • Extensions  │
    │ • Foundation      │  │ • NSGs       │  │ • Monitoring  │
    └─────────┬─────────┘  └──────┬───────┘  └────┬───────────┘
              │                   │               │
              ▼                   ▼               ▼
    ┌─────────────────────────────────────────────────────────┐
    │              SAP Deployment Scripts                      │
    │  • deploy_control_plane.sh                              │
    │  • deploy_workload_zone.sh                              │
    │  • deploy_vm.sh                                         │
    └─────────────────────────────────────────────────────────┘
                              │
                              ▼
    ┌─────────────────────────────────────────────────────────┐
    │              Terraform Modules (SAP Pattern)             │
    │  • bootstrap/control-plane (local state)                │
    │  • run/control-plane, workload-zone, vm-deployment      │
    └─────────────────────────────────────────────────────────┘
```

---

## 📁 Directory Structure

```
deploy/pipelines/
├── azure-devops/
│   ├── control-plane-pipeline.yml          # Foundation deployment
│   ├── workload-zone-pipeline.yml          # Network infrastructure
│   ├── vm-deployment-pipeline.yml          # VM provisioning (TODO)
│   ├── vm-operations-pipeline.yml          # VM operations (TODO)
│   ├── full-deployment-pipeline.yml        # End-to-end orchestration (TODO)
│   └── templates/
│       ├── script-execution-template.yml   # ✅ Reusable script runner
│       └── terraform-validate-template.yml # ✅ Terraform validation
└── README.md                                # This file
```

---

## 🚀 Available Pipelines

### **1. Control Plane Pipeline** ✅ COMPLETE
**File**: `control-plane-pipeline.yml`  
**Purpose**: Deploys foundation infrastructure (state storage, naming resources)  
**Script**: `deploy/scripts/deploy_control_plane.sh`

**Parameters**:
- `environment`: Target environment (dev, uat, prod)
- `deploymentMode`: bootstrap (local state) or run (remote state)
- `action`: deploy, destroy, validate
- `workspacePrefix`: Optional workspace naming prefix
- `autoApprove`: Skip manual approval for dev/uat

**Stages**:
1. **Pre-Deployment Validation** - Checks permissions, script availability
2. **Deploy Control Plane** - Executes deployment script with SAP patterns
3. **Production Approval** (prod only) - Manual validation gate
4. **Post-Deployment** - Verification, documentation, artifacts
5. **Destroy Control Plane** (if action=destroy) - Controlled destruction
6. **Notification** - Team notifications

**Usage**:
```bash
# Initial bootstrap deployment (local state)
az pipelines run --name control-plane-pipeline \
  --parameters environment=dev deploymentMode=bootstrap action=deploy

# Production deployment (remote state)
az pipelines run --name control-plane-pipeline \
  --parameters environment=prod deploymentMode=run action=deploy
```

---

### **2. Workload Zone Pipeline** ✅ COMPLETE
**File**: `workload-zone-pipeline.yml`  
**Purpose**: Deploys network infrastructure (VNet, subnets, NSGs)  
**Script**: `deploy/scripts/deploy_workload_zone.sh`  
**Dependency**: Requires control plane to be deployed first

**Parameters**:
- `environment`: Target environment (dev, uat, prod)
- `action`: deploy, destroy, validate
- `workspacePrefix`: Optional workspace naming prefix
- `vnetAddressSpace`: Optional VNet address space override
- `autoApprove`: Skip manual approval for dev/uat

**Stages**:
1. **Pre-Deployment Validation** - Verifies control plane exists, network config
2. **Deploy Workload Zone** - Creates VNet, subnets, NSGs
3. **Production Approval** (prod only) - Manual validation gate
4. **Post-Deployment** - Network verification, diagram generation
5. **Destroy Workload Zone** (if action=destroy) - Network destruction
6. **Notification** - Team notifications

**Usage**:
```bash
# Deploy workload zone
az pipelines run --name workload-zone-pipeline \
  --parameters environment=dev action=deploy

# Deploy with custom VNet address space
az pipelines run --name workload-zone-pipeline \
  --parameters environment=uat action=deploy vnetAddressSpace="10.1.0.0/16"
```

---

### **3. VM Deployment Pipeline** 🚧 IN PROGRESS
**File**: `vm-deployment-pipeline.yml` (TODO)  
**Purpose**: Deploys VMs with monitoring, backup, extensions  
**Script**: `deploy/scripts/deploy_vm.sh`  
**Dependency**: Requires control plane and workload zone

**Planned Features**:
- VM provisioning with SAP patterns
- Automatic agent installation (monitoring, backup, AV)
- Governance policy enforcement
- Integration with ServiceNow catalog
- Post-deployment validation
- Cost estimation

**Parameters** (Planned):
- `environment`: Target environment
- `vmName`: VM name
- `vmSize`: VM SKU
- `osType`: Windows or Linux
- `serviceNowTicket`: ServiceNow request ticket
- And more...

---

### **4. VM Operations Pipeline** 📋 PLANNED
**File**: `vm-operations-pipeline.yml` (TODO)  
**Purpose**: Day-2 operations (disk modify, SKU change, restore)  
**Sources**: Merged from Day 1 operations pipelines

**Planned Operations**:
- **Disk Operations**: Add, resize, delete disks
- **SKU Changes**: Resize VM (vertical scaling)
- **Backup/Restore**: Restore VM from backup
- **Start/Stop**: Power management
- **Extension Management**: Install/update agents

---

### **5. Full Deployment Pipeline** 🎯 PLANNED
**File**: `full-deployment-pipeline.yml` (TODO)  
**Purpose**: End-to-end orchestration with approval gates

**Workflow**:
```
Control Plane → Workload Zone → VM Deployment
      ↓               ↓                ↓
   Validate       Validate         Validate
      ↓               ↓                ↓
   Deploy         Deploy           Deploy
      ↓               ↓                ↓
  (Approve)      (Approve)        (Approve)
```

---

## 🛠️ Pipeline Templates

### **script-execution-template.yml** ✅
Reusable template for executing SAP deployment scripts with standardized:
- Pre-execution validation
- Environment variable setup
- Script execution with logging
- Output capture (Terraform outputs)
- Artifact publishing
- Cleanup on failure

**Usage in Pipeline**:
```yaml
- template: templates/script-execution-template.yml
  parameters:
    scriptPath: 'deploy/scripts/deploy_control_plane.sh'
    scriptName: 'control-plane-deployment'
    environment: 'dev'
    deploymentMode: 'run'
    action: 'deploy'
    azureServiceConnection: 'azure-dev-service-connection'
```

---

### **terraform-validate-template.yml** ✅
Reusable template for Terraform validation including:
- Format checking
- Terraform init, validate, plan
- Security scanning with Checkov
- Plan summary generation
- Artifact publishing

**Usage in Pipeline**:
```yaml
- template: templates/terraform-validate-template.yml
  parameters:
    terraformDirectory: 'deploy/terraform/run/control-plane'
    environment: 'dev'
    azureServiceConnection: 'azure-dev-service-connection'
    runCheckov: true
```

---

## 🔐 Security & Compliance

### **Security Scanning**
- **Checkov** integration for IaC security scanning
- Runs automatically in validation stages
- Results published as test results
- Soft-fail mode (warns but doesn't block)

### **Approval Gates**
- **Production deployments** require manual approval
- 24-hour timeout for approvals
- L2 approvers notified via email
- Rejection automatically cancels pipeline

### **Governance Integration** (Planned Phase 4)
- Azure Policy enforcement before deployment
- Naming convention validation
- Mandatory tag validation
- Encryption verification

---

## 📊 Artifacts & Outputs

Each pipeline publishes artifacts containing:

### **Deployment Artifacts**
- **Execution Logs**: Complete script execution logs with timestamps
- **Terraform Outputs**: JSON and text format outputs
- **Terraform Plans**: Binary tfplan and human-readable summaries
- **Validation Results**: Checkov security scan results

### **Artifact Naming**
- `control-plane-deployment-artifacts`
- `workload-zone-deployment-artifacts`
- `vm-deployment-artifacts` (planned)
- `terraform-plan-<environment>`

---

## 🌍 Multi-Environment Support

### **Environment Configuration**

| Environment | Branch      | Approval Required | Auto-Cleanup on Failure |
|-------------|-------------|-------------------|------------------------|
| **dev**     | develop     | ❌ No              | ✅ Yes                  |
| **uat**     | develop     | ❌ No              | ✅ Yes                  |
| **prod**    | main        | ✅ Yes             | ❌ No                   |

### **Variable Groups**
Each environment has a dedicated variable group:
- `vm-automation-secrets-dev`
- `vm-automation-secrets-uat`
- `vm-automation-secrets-prod`

**Required Variables**:
- Service connection names
- Key Vault references
- Storage account details
- Notification emails

---

## 🔄 State Management

### **Bootstrap → Run Pattern**

#### **Bootstrap Mode** (Initial Deployment)
- Uses **local state** (stored in pipeline workspace)
- Deploys control plane with state storage
- One-time setup per environment
- Creates: Storage account, containers, resource groups

#### **Run Mode** (Production)
- Uses **remote state** (Azure Storage backend)
- State stored in control plane storage account
- Supports team collaboration
- Includes state locking
- Supports multiple workspaces

### **State Migration**
Use `migrate_state_to_remote.sh` to migrate from bootstrap to run:
```bash
# Automated in pipelines or manual execution
deploy/scripts/migrate_state_to_remote.sh \
  --environment dev \
  --workspace-prefix myapp
```

---

## 📝 ServiceNow Integration (Planned Phase 3)

### **Catalog Item Triggers**
ServiceNow catalog items will trigger pipelines via:
1. REST API call to Azure DevOps
2. Pipeline triggered with ServiceNow ticket number
3. Deployment executes with ticket tracking
4. ServiceNow updated at each stage

### **Planned Integration Points**
- VM order catalog → vm-deployment-pipeline
- Disk modify catalog → vm-operations-pipeline
- SKU change catalog → vm-operations-pipeline
- Restore catalog → vm-operations-pipeline

---

## 🧪 Testing & Validation

### **Pre-Deployment Checks**
- Azure CLI authentication verification
- Permission checks (resource group access)
- Quota validation
- Prerequisite verification (control plane, workload zone)
- Script existence and executability

### **Post-Deployment Validation**
- Resource group existence
- Resource type verification
- Network connectivity tests (workload zone)
- VM status checks (VM deployment)
- Extension verification
- Monitoring agent checks

### **Integration Tests** (Manual)
```bash
# Test full deployment flow
cd deploy/scripts
./test_full_deployment.sh --environment dev

# Test multi-environment
./test_multi_environment.sh
```

---

## 🚦 Pipeline Execution Flow

### **Typical Deployment Sequence**

#### **Initial Setup (Bootstrap)**
```bash
# Step 1: Deploy control plane with bootstrap mode
az pipelines run --name control-plane-pipeline \
  --parameters environment=dev deploymentMode=bootstrap action=deploy

# Step 2: Migrate to remote state (if needed)
./deploy/scripts/migrate_state_to_remote.sh --environment dev

# Step 3: Deploy control plane with run mode
az pipelines run --name control-plane-pipeline \
  --parameters environment=dev deploymentMode=run action=deploy
```

#### **Standard Deployment**
```bash
# Step 1: Deploy/verify control plane
az pipelines run --name control-plane-pipeline \
  --parameters environment=prod deploymentMode=run action=deploy

# Step 2: Deploy workload zone
az pipelines run --name workload-zone-pipeline \
  --parameters environment=prod action=deploy

# Step 3: Deploy VM (when pipeline ready)
az pipelines run --name vm-deployment-pipeline \
  --parameters environment=prod vmName=prod-vm-app-001 action=deploy
```

---

## 📚 Migration from Day 1 Pipelines

### **Old Pipeline Structure** (Day 1)
```
pipelines/azure-devops/
├── terraform-vm-deploy-pipeline.yml        # Monolithic deployment
├── vm-disk-modify-pipeline.yml             # Disk operations
├── vm-restore-pipeline.yml                 # Restore operations
├── vm-sku-change-pipeline.yml              # SKU changes
└── vm-deploy-pipeline.yml                  # VM deployment
```

### **New Pipeline Structure** (Unified)
```
deploy/pipelines/azure-devops/
├── control-plane-pipeline.yml              # NEW - Foundation
├── workload-zone-pipeline.yml              # NEW - Networking
├── vm-deployment-pipeline.yml              # ADAPTED from Day 1
├── vm-operations-pipeline.yml              # MERGED operations
└── full-deployment-pipeline.yml            # NEW - Orchestration
```

### **Migration Benefits**
✅ SAP hierarchical deployment pattern  
✅ Better state management (bootstrap → run)  
✅ Reusable templates reduce duplication  
✅ Better separation of concerns  
✅ Easier to maintain and extend  
✅ Supports complex multi-tier deployments  

---

## 🎯 Roadmap & Next Steps

### **✅ Completed** (Phase 2 - Pipelines)
- [x] Pipeline directory structure
- [x] Reusable templates (script-execution, terraform-validate)
- [x] Control plane pipeline
- [x] Workload zone pipeline
- [x] Pipeline documentation

### **🚧 In Progress**
- [ ] VM deployment pipeline (adapting from Day 1)
- [ ] VM operations pipeline (merging Day 1 operations)

### **📋 Planned** (Phase 2 Completion)
- [ ] Full deployment orchestration pipeline
- [ ] Pipeline integration testing
- [ ] Update MERGE-STRATEGY.md with progress

### **🔮 Future Phases**
- **Phase 3**: ServiceNow Integration
- **Phase 4**: Governance & Compliance Integration
- **Phase 5**: Module Consolidation
- **Phase 6**: Enterprise Features
- **Phase 7**: Documentation & Cleanup

---

## 🆘 Troubleshooting

### **Common Issues**

#### **Issue: Control plane not found**
```
Error: Control plane not found: rg-dev-controlplane
```
**Solution**: Deploy control plane first using `control-plane-pipeline.yml`

#### **Issue: Azure CLI not authenticated**
```
Error: Azure CLI authentication failed
```
**Solution**: Check service connection configuration in Azure DevOps

#### **Issue: Script not executable**
```
Error: Permission denied: deploy_control_plane.sh
```
**Solution**: Pipeline automatically runs `chmod +x`. If issue persists, check Git file permissions.

#### **Issue: Terraform state locked**
```
Error: State is locked
```
**Solution**: Check for concurrent deployments. Force unlock if needed:
```bash
cd <terraform-directory>
terraform force-unlock <lock-id>
```

---

## 📞 Support & Contact

For pipeline issues or questions:
- **DevOps Team**: devops-team@yourdomain.com
- **L2 Approvers**: l2-approvers@yourdomain.com
- **Documentation**: `deploy/docs/`
- **GitHub Issues**: (if applicable)

---

## 📄 Related Documentation

- [MERGE-STRATEGY.md](../../MERGE-STRATEGY.md) - Overall merge strategy
- [deploy/README.md](../README.md) - SAP deployment overview
- [iac/terraform/README.md](../../iac/terraform/README.md) - Day 1 solution (deprecated)
- [deploy/scripts/README.md](../scripts/README.md) - Deployment scripts documentation

---

**Version**: 1.0.0  
**Last Updated**: October 10, 2025  
**Status**: Phase 2 - Pipeline Integration (70% Complete)  
**Maintainer**: DevOps Team
