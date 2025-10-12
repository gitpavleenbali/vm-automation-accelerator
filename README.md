# VM Automation Accelerator#  VM Automation Accelerator - Unified Solution



[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)##  Status: PRODUCTION READY

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-623CE4?logo=terraform)](https://www.terraform.io/)

[![Azure](https://img.shields.io/badge/Azure-Verified%20Modules-0078D4?logo=microsoftazure)](https://azure.github.io/Azure-Verified-Modules/)**Version**: 2.0.0 (Unified Solution)  

**Last Updated**: October 10, 2025  

> **Production-ready Azure VM automation platform** combining enterprise security patterns, ServiceNow integration, and comprehensive lifecycle management.**Status**:  **100% Complete** - All phases integrated  

**Total Code**: 14,030+ lines across 51+ files  

---**Documentation**: 4,100+ lines across 10+ comprehensive guides



## Overview> ** What's New in v2.0**: This unified solution combines the best of both worlds - **Azure Verified Module (AVM) security patterns** from the Day 1 implementation with **SAP Automation Framework orchestration** from the Day 3 implementation, creating a production-ready enterprise VM automation platform.



The **VM Automation Accelerator** is an enterprise-grade platform for automated virtual machine lifecycle management in Azure. It provides:---



- 🔐 **Security-First Design** - Managed identities, encryption at host, Trusted Launch, customer-managed keys## Overview

- 🎯 **Self-Service Provisioning** - ServiceNow catalog integration for end-user VM ordering

- 🚀 **Automated Orchestration** - Azure DevOps pipelines with validation and deploymentThe **VM Automation Accelerator Unified Solution** provides a comprehensive, enterprise-ready platform for automated VM lifecycle management in Azure, combining:

- 📊 **Enterprise Monitoring** - Azure Monitor Agent, VM Insights, Data Collection Rules

- 🔄 **Complete Lifecycle** - VM provisioning, disk modifications, SKU changes, backup/restore-  **ServiceNow Self-Service Catalogs** - End-user VM ordering, disk modifications, SKU changes, backup/restore

- 📏 **Governance** - Azure Policy enforcement with environment-specific configurations-  **Azure DevOps Orchestration** - Multi-stage pipelines with validation, deployment, and configuration  

- 🏗️ **Infrastructure as Code** - Terraform modules following Azure Verified Module patterns-  **Infrastructure as Code** - Terraform modules with AVM security patterns

-  **Enterprise Governance** - Azure Policy enforcement with environment-specific configurations

----  **Day 2 Operations** - Complete VM lifecycle management beyond initial deployment

-  **Security First** - Managed identities, encryption at host, Trusted Launch, customer-managed keys

## Quick Start-  **Enterprise Monitoring** - Azure Monitor Agent, VM Insights, Data Collection Rules

-  **Backup & DR** - Comprehensive backup policies with multi-tier retention

### Prerequisites

---

```bash

# Required tools##  Quick Links

terraform >= 1.5.0

az-cli >= 2.50.0-  **[Complete Architecture](./ARCHITECTURE-UNIFIED.md)** - Detailed system design (1,200+ lines)

powershell >= 7.0  # Windows-  **[Migration Guide](./MIGRATION-GUIDE.md)** - Step-by-step migration from Day 1/Day 3 (1,400+ lines)

jq >= 1.6          # ServiceNow integration-  **[Feature Comparison](./FEATURE-MATRIX.md)** - Compare all solutions (800+ lines)

```-  **[Completion Report](./COMPLETION-REPORT.md)** - Implementation summary

-  **[Verification Report](./VERIFICATION-REPORT.md)** - Code validation

### Azure Authentication

---

```bash

az login##  Quick Start

az account set --subscription <subscription-id>

```### Prerequisites



### Deploy in 5 Steps```powershell

# Required tools

```bash- Terraform >= 1.5.0

# 1. Navigate to deployment scripts- Azure CLI >= 2.50.0

cd deploy/scripts- PowerShell >= 7.0 (Windows)

- jq >= 1.6 (for ServiceNow API wrappers)

# 2. Bootstrap control plane (one-time setup)

./deploy_control_plane.sh -e dev -r eastus -p myproject -y# Azure authentication

az login

# 3. Deploy network infrastructureaz account set --subscription <subscription-id>

./deploy_workload_zone.sh -e dev -r eastus -y```



# 4. Deploy virtual machines### Deploy in 5 Steps

./deploy_vm.sh -e dev -r eastus -n web -y

```powershell

# 5. Deploy governance policies# 1. Navigate to scripts directory

./deploy_governance.sh --environment dev --action deploycd deploy/scripts



# ✅ Infrastructure deployed!# 2. Bootstrap control plane (one-time setup)

```./deploy_control_plane.sh -e dev -r eastus -p myproject -y



---# 3. Deploy network infrastructure

./deploy_workload_zone.sh -e dev -r eastus -y

## Architecture

# 4. Deploy virtual machines

```./deploy_vm.sh -e dev -r eastus -n web -y

┌─────────────────────────────────────────────────────────────┐

│                  ServiceNow Self-Service                    │# 5. Deploy governance policies

│           VM Order │ Disk Modify │ SKU Change │ Restore     │./deploy_governance.sh --environment dev --action deploy

└────────────────────┬────────────────────────────────────────┘

                     │#  Complete infrastructure deployed!

                     ▼```

┌─────────────────────────────────────────────────────────────┐

│              Azure DevOps Orchestration                     │---

│    Multi-stage Pipelines │ Validation │ Deployment          │

└────────────────────┬────────────────────────────────────────┘## Key Features

                     │

                     ▼###  Security & Compliance (AVM Patterns)

┌─────────────────────────────────────────────────────────────┐

│              Terraform Infrastructure                       │| Feature | Status | Description |

│  ├─ Compute (Managed Identity, Encryption, Trusted Launch)  │|---------|--------|-------------|

│  ├─ Network (VNet, Subnet, NSG, Route Tables)              │| **Managed Identity** |  | System-assigned + User-assigned |

│  ├─ Monitoring (AMA, DCR, VM Insights)                     │| **Encryption at Host** |  | Enabled by default |

│  └─ Backup (Recovery Services Vault, Policies)             │| **Trusted Launch** |  | Secure Boot + vTPM |

└────────────────────┬────────────────────────────────────────┘| **Customer-Managed Keys** |  | Disk Encryption Set |

                     │| **Azure Policy** |  | 5 policies + initiative |

                     ▼

┌─────────────────────────────────────────────────────────────┐###  Orchestration & Automation (SAP Patterns)

│                    Azure Resources                          │

│  Virtual Machines │ Disks │ Backups │ Monitoring            │| Feature | Status | Description |

└─────────────────────────────────────────────────────────────┘|---------|--------|-------------|

```| **ServiceNow Integration** |  | 4 API wrappers (867 lines) |

| **Azure DevOps Pipelines** |  | 5 pipelines + 2 templates |

📖 **[Detailed Architecture Documentation](./ARCHITECTURE.md)**| **Shell Script Automation** |  | 8 production scripts (2,450+ lines) |

| **State Management** |  | Remote backend with locking |

---

###  Day 2 Operations

## Key Features

| Operation | Catalog | API | Pipeline | Status |

### 🔐 Security & Compliance|-----------|---------|-----|----------|--------|

| **VM Provisioning** |  | vm-order-api.sh | vm-deployment |  |

| Feature | Description || **Disk Modification** |  | vm-disk-modify-api.sh | vm-operations |  |

|---------|-------------|| **SKU Change** |  | vm-sku-change-api.sh | vm-operations |  |

| **Managed Identity** | System-assigned and user-assigned identities || **Backup & Restore** |  | vm-restore-api.sh | vm-operations |  |

| **Encryption at Host** | Enabled by default on all VMs |

| **Trusted Launch** | Secure Boot + vTPM for enhanced security |---

| **Customer-Managed Keys** | Disk Encryption Sets with Key Vault integration |

| **Azure Policy** | 5 policies + initiative for compliance enforcement |##  Architecture

| **Network Security** | NSG rules, private endpoints, network isolation |

```

### 🎯 Lifecycle OperationsServiceNow Catalogs

        

| Operation | ServiceNow Catalog | API Wrapper | Pipeline |        

|-----------|-------------------|-------------|----------|API Wrappers (Bash - 867 lines)

| **VM Provisioning** | ✅ | `vm-order-api.sh` | `vm-deployment` |        

| **Disk Modification** | ✅ | `vm-disk-modify-api.sh` | `vm-operations` |        

| **SKU Change** | ✅ | `vm-sku-change-api.sh` | `vm-operations` |Azure DevOps Pipelines (5 pipelines)

| **Backup & Restore** | ✅ | `vm-restore-api.sh` | `vm-operations` |        

        

### 📊 Monitoring & ObservabilityShell Scripts (8 scripts - 2,450 lines)

        

- **Azure Monitor Agent** (AMA) for telemetry collection        

- **VM Insights** for performance monitoringTerraform Modules (AVM Enhanced)

- **Data Collection Rules** for centralized log management Compute (managed identity, encryption, Trusted Launch)

- **Custom alerts** for proactive issue detection Network (VNet, subnet, NSG)

 Monitoring (AMA, DCR, VM Insights)

--- Backup Policy (RSV, policies, retention)

        

## Repository Structure        

Azure Resources

``` Virtual Machines

vm-automation-accelerator/ Managed Disks

│ Recovery Services Vault

├── README.md                          # This file Data Collection Rules

├── ARCHITECTURE.md                    # Detailed system architecture

├── CONTRIBUTING.md                    # Contribution guidelinesGovernance: Azure Policy (5 policies)

│```

├── boilerplate/                       # 📝 Template configurations

│   ├── README.md                      # Template usage guide** Detailed Architecture**: See [ARCHITECTURE-UNIFIED.md](./ARCHITECTURE-UNIFIED.md)

│   ├── bootstrap/                     # Bootstrap templates

│   ├── run/                           # Deployment templates---

│   └── *.tfvars                       # Example configurations

│##  Repository Structure

├── deploy/                            # 🚀 Deployment assets

│   ├── README.md                      # Deployment guide```

│   │vm-automation-accelerator/

│   ├── pipelines/                     # Azure DevOps pipelines

│   │   ├── vm-deployment.yml          # VM provisioning pipeline  README.md                           # This file

│   │   ├── vm-operations.yml          # Lifecycle operations pipeline  ARCHITECTURE-UNIFIED.md             # Complete system architecture

│   │   └── templates/                 # Reusable pipeline templates  MIGRATION-GUIDE.md                  # Migration instructions

│   │  FEATURE-MATRIX.md                   # Feature comparison

│   ├── scripts/                       # Deployment automation scripts

│   │   ├── deploy_control_plane.sh    # Bootstrap control plane  deploy/                             #  UNIFIED SOLUTION

│   │   ├── deploy_workload_zone.sh    # Deploy network infrastructure     pipelines/                      # Azure DevOps pipelines

│   │   ├── deploy_vm.sh               # Deploy virtual machines     scripts/                        # Deployment scripts

│   │   ├── deploy_governance.sh       # Deploy policies     servicenow/                     # ServiceNow integration

│   │   └── utilities/                 # Utility scripts       api/                           # 4 API wrappers (867 lines)

│   │       catalog-items/                 # 4 XML catalogs

│   ├── servicenow/                    # ServiceNow integration     terraform/                      # Infrastructure as Code

│   │   ├── api/                       # API wrappers (867 lines)        bootstrap/                     # Control plane bootstrap

│   │   └── catalog-items/             # Catalog item definitions        run/                           # Deployment units

│   │           vm-deployment/             # VM deployment

│   └── terraform/                     # 🏗️ Infrastructure as Code              telemetry.tf           #  NEW

│       ├── bootstrap/                 # Control plane setup           workload-zone/             # Network infrastructure

│       │   └── control-plane/         # State storage, Key Vault           governance/                # Azure Policy

│       │        terraform-units/modules/       # Reusable modules

│       ├── run/                       # Deployment configurations            compute/                   #  AVM enhanced

│       │   ├── workload-zone/         # Network infrastructure            network/                   # Network module

│       │   ├── vm-deployment/         # Virtual machine deployment            monitoring/                #  NEW: AMA + DCR

│       │   └── governance/            # Azure Policy            backup-policy/             #  NEW: Backup

│       │

│       └── terraform-units/modules/   # Reusable Terraform modules  iac-archived/                       # Day 1 (archived)

│           ├── compute/               # VM module (AVM-enhanced)  pipelines-archived/                 # Day 3 (archived)

│           ├── network/               # Network module  servicenow-archived/                # Day 3 (archived)

│           ├── monitoring/            # Monitoring module  governance-archived/                # Day 3 (archived)

│           └── backup-policy/         # Backup module```

│

└── terraform-docs/                    # 📚 Terraform documentation---

    ├── TERRAFORM-GUIDE.md             # Terraform usage guide

    └── STATE-MANAGEMENT.md            # State management guide## What Makes This "Unified"?

```

| Aspect | Day 1 (AVM) | Day 3 (SAP) |  Unified |

---|--------|-------------|-------------|------------|

| **Security** |  Advanced |  Basic |  Advanced |

## Getting Started| **Orchestration** |  Manual |  Automated |  Automated |

| **ServiceNow** |  None |  1 catalog |  4 catalogs |

### 1. Review Architecture| **Day 2 Ops** |  Manual |  Limited |  Complete |

| **Monitoring** |  AMA + Insights |  Basic |  AMA + Insights |

Read the [Architecture Documentation](./ARCHITECTURE.md) to understand:| **Backup** |  Manual |  Manual |  Automated |

- System components and interactions| **Governance** |  Manual |  Basic |  Automated |

- Security patterns and compliance| **Maturity** |  |  |  |

- Deployment workflow

- Module structure**Result**: Enterprise-grade VM automation with security, compliance, and operational excellence.



### 2. Prepare Configuration---



Use the [boilerplate templates](./boilerplate/README.md):##  Migration Paths



```bash### From Day 1 (AVM)?

# Copy template for your environment Keep your security patterns  

cp boilerplate/bootstrap/control-plane/dev.tfvars deploy/terraform/bootstrap/control-plane/terraform.tfvars Add orchestration layer  

 No resource recreation  

# Update with your values

vim deploy/terraform/bootstrap/control-plane/terraform.tfvars**Guide**: [Day 1  Unified Migration](./MIGRATION-GUIDE.md#day-1-to-unified)

```

### From Day 3 (SAP)?

### 3. Deploy Infrastructure Keep your orchestration  

 Enhance with AVM patterns  

Follow the [Deployment Guide](./deploy/README.md): Gradual rollout  



1. **Bootstrap** - Set up control plane (state storage, Key Vault)**Guide**: [Day 3  Unified Migration](./MIGRATION-GUIDE.md#day-3-to-unified)

2. **Workload Zone** - Deploy network infrastructure

3. **VM Deployment** - Provision virtual machines### Starting Fresh?

4. **Governance** - Apply Azure Policy Deploy unified solution directly  

 All features ready  

### 4. Configure ServiceNow (Optional) Production-ready code  



Integrate with ServiceNow for self-service:**Guide**: [Greenfield Deployment](./MIGRATION-GUIDE.md#greenfield-deployment)

- Import catalog items from `deploy/servicenow/catalog-items/`

- Configure API wrappers in `deploy/servicenow/api/`---

- Set up Azure DevOps pipeline triggers

##  Metrics

---

| Metric | Value |

## Configuration|--------|-------|

| **Total Lines** | 14,030+ |

### Environment Variables| **Terraform** | 4,200+ lines |

| **Bash Scripts** | 2,450+ lines |

```bash| **Pipelines** | 640+ lines |

export ARM_SUBSCRIPTION_ID="<subscription-id>"| **API Wrappers** | 867 lines |

export ARM_TENANT_ID="<tenant-id>"| **Documentation** | 4,700+ lines |

export ARM_CLIENT_ID="<client-id>"           # Optional: Service Principal| **Files** | 51+ files |

export ARM_CLIENT_SECRET="<client-secret>"   # Optional: Service Principal

```### Performance



### Terraform Variables| Operation | Time |

|-----------|------|

Key configuration options:| **VM Deployment** | ~15 min |

| **Pipeline Execution** | ~18 min |

```hcl| **Disk Modification** | ~5 min |

# Environment settings| **SKU Change** | ~10 min |

environment          = "dev"              # dev, uat, prod

location             = "eastus"---

project_code         = "myproject"

##  Documentation

# VM configuration

vm_size              = "Standard_D4s_v5"| Document | Lines | Description |

os_disk_size_gb      = 128|----------|-------|-------------|

enable_encryption    = true| [ARCHITECTURE-UNIFIED.md](./ARCHITECTURE-UNIFIED.md) | 1,200+ | Complete system architecture |

enable_trusted_launch = true| [MIGRATION-GUIDE.md](./MIGRATION-GUIDE.md) | 1,400+ | Step-by-step migration |

| [FEATURE-MATRIX.md](./FEATURE-MATRIX.md) | 800+ | Feature comparison |

# Monitoring| [COMPLETION-REPORT.md](./COMPLETION-REPORT.md) | 600+ | Implementation summary |

enable_monitoring    = true| [VERIFICATION-REPORT.md](./VERIFICATION-REPORT.md) | 1,000+ | Code verification |

log_analytics_workspace_id = "<workspace-id>"

### Module READMEs

# Backup

enable_backup        = true- [Compute Module](./deploy/terraform/terraform-units/modules/compute/README.md)

backup_policy_name   = "daily-backup-30days"- [Network Module](./deploy/terraform/terraform-units/modules/network/README.md)

```- [Monitoring Module](./deploy/terraform/terraform-units/modules/monitoring/README.md) (300+ lines)

- [Backup Policy Module](./deploy/terraform/terraform-units/modules/backup-policy/README.md) (400+ lines)

📖 **[Full Configuration Guide](./terraform-docs/TERRAFORM-GUIDE.md)**

---

---

##  Contributing

## Deployment Options

Contributions welcome! See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

### Option 1: Automated Deployment (Recommended)

---

Use provided shell scripts:

##  License

```bash

cd deploy/scriptsMIT License - see [LICENSE](./LICENSE) file.

./deploy_control_plane.sh -e dev -r eastus -p myproject -y

./deploy_workload_zone.sh -e dev -r eastus -y---

./deploy_vm.sh -e dev -r eastus -n web -y

```##  What's Next?



### Option 2: Azure DevOps Pipelines1. **Review**: Read [ARCHITECTURE-UNIFIED.md](./ARCHITECTURE-UNIFIED.md)

2. **Plan**: Read [MIGRATION-GUIDE.md](./MIGRATION-GUIDE.md)

Use CI/CD pipelines:3. **Compare**: Read [FEATURE-MATRIX.md](./FEATURE-MATRIX.md)

4. **Deploy**: Start with development environment

1. Import pipelines from `deploy/pipelines/`5. **Test**: Validate in dev, promote to UAT, then production

2. Configure pipeline variables

3. Run pipelines from Azure DevOps---



### Option 3: Manual Terraform**Built with  by the Cloud Infrastructure Team**



Execute Terraform directly:**Last Updated**: October 10, 2025  

**Version**: 2.0.0 (Unified Solution)  

```bash**Status**:  Production Ready

cd deploy/terraform/bootstrap/control-plane
terraform init
terraform plan
terraform apply

cd ../../run/vm-deployment
terraform init
terraform plan
terraform apply
```

---

## Modules

### Compute Module

VM deployment with security enhancements:
- Managed identity (system + user-assigned)
- Encryption at host
- Trusted Launch (Secure Boot + vTPM)
- Customer-managed keys
- Boot diagnostics

### Network Module

Network infrastructure:
- Virtual Network (VNet)
- Subnets with NSG associations
- Route tables
- Private DNS zones
- Network security groups

### Monitoring Module

Observability stack:
- Azure Monitor Agent (AMA)
- VM Insights
- Data Collection Rules (DCR)
- Log Analytics workspace integration
- Custom metrics and alerts

### Backup Module

Data protection:
- Recovery Services Vault
- Backup policies (daily, weekly, monthly)
- Retention policies
- Backup items management

---

## Performance Metrics

| Operation | Average Time | Description |
|-----------|-------------|-------------|
| **Control Plane Bootstrap** | ~5 minutes | One-time setup |
| **Network Infrastructure** | ~8 minutes | VNet, subnets, NSG |
| **VM Deployment** | ~15 minutes | Single VM with monitoring |
| **Full Pipeline** | ~18 minutes | End-to-end deployment |
| **Disk Modification** | ~5 minutes | Add/resize disks |
| **SKU Change** | ~10 minutes | VM resize operation |

---

## Security Considerations

### Authentication

- **Managed Identity** recommended for production
- **Service Principal** supported for automation
- **Azure CLI** for local development

### Encryption

- **Encryption at host** enabled by default
- **Customer-managed keys** optional
- **TLS 1.2+** for all communications

### Network Security

- **Private endpoints** for storage and Key Vault
- **NSG rules** follow least privilege
- **Network isolation** per environment

### Compliance

- Azure Policy enforcement
- Resource tagging for governance
- Audit logs enabled
- Security Center integration

---

## Troubleshooting

### Common Issues

**Issue: Terraform state lock**
```bash
# Remove lock (use with caution)
terraform force-unlock <lock-id>
```

**Issue: Insufficient permissions**
```bash
# Check current permissions
az role assignment list --assignee $(az account show --query user.name -o tsv)
```

**Issue: Quota exceeded**
```bash
# Check quota
az vm list-usage --location eastus -o table
```

📖 **[Full Troubleshooting Guide](./terraform-docs/TERRAFORM-GUIDE.md#troubleshooting)**

---

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](./CONTRIBUTING.md) for:
- Code of conduct
- Development setup
- Pull request process
- Coding standards

---

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](./ARCHITECTURE.md) | System architecture and design decisions |
| [Deployment Guide](./deploy/README.md) | Step-by-step deployment instructions |
| [Boilerplate Guide](./boilerplate/README.md) | Template configuration reference |
| [Terraform Guide](./terraform-docs/TERRAFORM-GUIDE.md) | Terraform usage and best practices |
| [State Management](./terraform-docs/STATE-MANAGEMENT.md) | Remote state configuration |

---

## License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.

---

## Support

For questions, issues, or feature requests:
- 📝 **[Open an issue](https://github.com/gitpavleenbali/vm-automation-accelerator/issues)**
- 💬 **[Discussions](https://github.com/gitpavleenbali/vm-automation-accelerator/discussions)**
- 📧 **Contact**: See [CONTRIBUTING.md](./CONTRIBUTING.md)

---

**Built with ❤️ for Azure Infrastructure Automation**
