# ⚠️ DEPRECATED - Day 3 Governance (Manual Deployment)

## Status: ARCHIVED

This directory contains the **Day 3 governance implementation** with Azure Policy definitions. This implementation has been **superseded by the unified solution** in the `deploy/terraform/run/governance/` and `deploy/scripts/deploy_governance.sh`.

---

## Why Was This Archived?

The Day 3 governance implementation had policy definitions but required manual deployment. The **unified solution** includes:

- ✅ **All Day 3 governance policies** (5 policies + initiative)
- ✅ **Plus automated deployment script** (deploy_governance.sh - 352 lines)
- ✅ **Plus environment-specific configuration** (dev=Audit, prod=Deny)
- ✅ **Plus automated tfvars generation**
- ✅ **Plus deployment record tracking**

---

## What Was in Day 3 Governance?

### Strengths
- ✅ Azure Policy definitions (5 policies)
- ✅ Policy initiative (policy set)
- ✅ Terraform-based deployment
- ✅ Good policy structure

### Limitations
- ❌ Manual deployment required
- ❌ No environment-specific configuration
- ❌ No automated tfvars generation
- ❌ No deployment tracking
- ❌ No CLI interface for easy deployment

---

## Migration to Unified Solution

### All Your Governance Policies Are Preserved!

The unified solution **includes ALL Day 3 policies**, enhanced with automation:

| Day 3 Policy | Unified Policy | Status |
|--------------|----------------|--------|
| require-encryption-at-host.json | `deploy/terraform/run/governance/main.tf` | ✅ Migrated |
| require-mandatory-tags.json | `deploy/terraform/run/governance/main.tf` | ✅ Migrated |
| enforce-naming-convention.json | `deploy/terraform/run/governance/main.tf` | ✅ Migrated |
| require-azure-backup.json | `deploy/terraform/run/governance/main.tf` | ✅ Migrated |
| restrict-vm-sku-sizes.json | `deploy/terraform/run/governance/main.tf` | ✅ Migrated |
| policy-initiative.json | `deploy/terraform/run/governance/main.tf` | ✅ Migrated |

### New: Automated Deployment Script

🆕 **deploy_governance.sh** (352 lines)

```bash
# Deploy governance policies with one command!

# Development (Audit mode - warns but doesn't block)
./deploy/scripts/deploy_governance.sh --environment dev --action deploy

# Production (Deny mode - blocks non-compliant resources)
./deploy/scripts/deploy_governance.sh --environment prod --action deploy

# Features:
# - CLI interface with options
# - Environment validation (dev/uat/prod)
# - Auto-generates terraform.tfvars
# - Configures policy effects per environment
# - Full Terraform workflow (init → validate → plan → apply)
# - Deployment record generation
# - Post-deployment policy listing
```

---

## File Mapping

| Day 3 Location | Unified Location | Status |
|----------------|------------------|--------|
| `governance/policies/*.json` | `deploy/terraform/run/governance/main.tf` | ✅ Migrated to Terraform |
| `governance/dashboards/` | `deploy/terraform/run/governance/` (future) | 📝 Planned |
| Manual deployment | `deploy/scripts/deploy_governance.sh` | ✅ Automated |

---

## Environment-Specific Policy Effects

The unified solution automatically configures policy effects based on environment:

| Environment | Encryption | Tags | Naming | Backup | SKU | Effect |
|-------------|-----------|------|--------|--------|-----|--------|
| **dev** | Audit | Audit | Audit | Audit | Audit | ⚠️ Warn only |
| **uat** | Audit | Audit | Audit | Audit | Audit | ⚠️ Warn only |
| **prod** | Deny | Deny | Deny | Deny | Deny | 🚫 Block |

This allows testing in dev/uat without blocking deployments, while enforcing compliance in production.

---

## Migration Path

**Option 1: Automated Deployment (Recommended)**

```bash
# 1. Navigate to scripts directory
cd deploy/scripts

# 2. Deploy to development (Audit mode)
./deploy_governance.sh --environment dev --action deploy

# 3. Test and validate
# Check Azure Policy compliance in portal

# 4. Deploy to UAT
./deploy_governance.sh --environment uat --action deploy

# 5. Deploy to production (Deny mode)
./deploy_governance.sh --environment prod --action deploy
```

**Option 2: Manual Terraform Deployment**

```bash
# 1. Navigate to governance directory
cd deploy/terraform/run/governance

# 2. Initialize Terraform
terraform init

# 3. Create tfvars file
cat > terraform.tfvars <<EOF
environment         = "prod"
location            = "eastus"
subscription_id     = "<your-subscription-id>"
policy_effects = {
  encryption_effect = "Deny"
  tags_effect       = "Deny"
  naming_effect     = "Deny"
  backup_effect     = "Deny"
  sku_effect        = "Deny"
}
EOF

# 4. Deploy
terraform plan
terraform apply
```

### Detailed Migration Guide

See: **[MIGRATION-GUIDE.md](../MIGRATION-GUIDE.md#governance-integration)**

---

## What's in the Unified Solution?

Located in `deploy/terraform/run/governance/` and `deploy/scripts/`:

### Governance Policies (5 Total)
1. ✅ **Encryption at Host** - Require encryption for all VMs
2. ✅ **Mandatory Tags** - Enforce required tags
3. ✅ **Naming Convention** - Enforce naming standards
4. ✅ **Azure Backup Required** - Require backup configuration
5. ✅ **VM SKU Restrictions** - Limit allowed VM sizes

### Policy Initiative
- ✅ Groups all 5 policies into one initiative
- ✅ Assigns to subscription
- ✅ Environment-specific effects

### Deployment Script Features
- ✅ **CLI Interface**: Options for environment, action, auto-approve
- ✅ **Validation**: Checks for valid environment, Azure CLI, Terraform
- ✅ **Auto-tfvars**: Generates configuration automatically
- ✅ **Environment-Specific**: Different effects for dev/uat/prod
- ✅ **Full Workflow**: init → validate → plan → apply
- ✅ **Deployment Records**: Saves deployment metadata
- ✅ **Policy Listing**: Shows deployed policies after completion
- ✅ **Error Handling**: Comprehensive error checks
- ✅ **Colored Output**: Easy-to-read console output

---

## Policy Compliance Dashboard

The unified solution includes governance tracking:

```bash
# View deployed policies
az policy assignment list --query "[?displayName=='VM Automation Governance Initiative']"

# Check compliance status
az policy state summarize --policy-assignment-name "vm-automation-governance"

# List non-compliant resources
az policy state list --policy-assignment-name "vm-automation-governance" \
  --filter "complianceState eq 'NonCompliant'"
```

---

## Need Help?

### Documentation
- **[deploy/terraform/run/governance/README.md](../deploy/terraform/run/governance/README.md)** - Governance documentation
- **[MIGRATION-GUIDE.md](../MIGRATION-GUIDE.md)** - Migration instructions
- **[ARCHITECTURE-UNIFIED.md](../ARCHITECTURE-UNIFIED.md)** - System architecture

### Support
- Review governance module documentation
- Check deploy_governance.sh script
- Test in dev environment first

---

## Summary

- ⚠️ **This directory is DEPRECATED**
- ✅ **Use `deploy/terraform/run/governance/` for all new work**
- ✅ **All 5 policies + initiative preserved**
- ✅ **Manual deployment → One-command automation**
- ✅ **Environment-specific policy effects**
- ✅ **Deployment tracking and records**
- 📚 **See [MIGRATION-GUIDE.md](../MIGRATION-GUIDE.md) for details**

---

**Archived**: October 10, 2025  
**Replaced By**: Unified Solution in `deploy/terraform/run/governance/` and `deploy/scripts/deploy_governance.sh`  
**Migration Guide**: [MIGRATION-GUIDE.md](../MIGRATION-GUIDE.md)
