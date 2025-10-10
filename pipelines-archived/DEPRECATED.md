# ⚠️ DEPRECATED - Day 3 Pipelines (SAP Orchestration)

## Status: ARCHIVED

This directory contains the **Day 3 pipeline implementation** focusing on Azure DevOps orchestration. This implementation has been **superseded by the unified solution** in the `deploy/pipelines/` directory.

---

## Why Was This Archived?

The Day 3 pipelines provided orchestration but used basic security patterns. The **unified solution** (found in `deploy/pipelines/`) combines:

- ✅ **All Day 3 orchestration capabilities** (pipelines, multi-stage deployment)
- ✅ **Plus Day 1 AVM security features** (managed identities, encryption, Trusted Launch)
- ✅ **Plus enhanced features** (more pipelines, better validation, telemetry)

---

## What Was in Day 3 Pipelines?

### Strengths
- ✅ Azure DevOps pipeline orchestration
- ✅ Multi-stage deployment workflow
- ✅ ServiceNow integration
- ✅ Basic validation and compliance checks

### Limitations
- ❌ Basic security patterns (no AVM compliance)
- ❌ Limited monitoring capabilities
- ❌ Manual backup configuration
- ❌ No telemetry tracking

---

## Migration to Unified Solution

### All Your Orchestration Is Preserved!

The unified solution **includes ALL Day 3 orchestration**, enhanced with AVM security:

| Day 3 Pipeline | Unified Pipeline | Status |
|----------------|------------------|--------|
| vm-deploy-pipeline.yml | `deploy/pipelines/vm-deployment-pipeline.yml` | ✅ Enhanced |
| terraform-vm-deploy-pipeline.yml | Integrated into vm-deployment-pipeline.yml | ✅ Consolidated |
| vm-disk-modify-pipeline.yml | `deploy/pipelines/vm-operations-pipeline.yml` | ✅ Enhanced |
| vm-sku-change-pipeline.yml | `deploy/pipelines/vm-operations-pipeline.yml` | ✅ Consolidated |
| vm-restore-pipeline.yml | `deploy/pipelines/vm-operations-pipeline.yml` | ✅ Consolidated |

### New Pipelines in Unified Solution
- ✅ `vm-full-orchestration.yml` - Complete lifecycle automation
- ✅ `state-import-pipeline.yml` - State management
- ✅ `validation-pipeline.yml` - Enhanced validation
- ✅ Reusable templates (terraform-template.yml, script-template.yml)

---

## File Mapping

| Day 3 Location | Unified Location | Status |
|----------------|------------------|--------|
| `pipelines/azure-devops/*.yml` | `deploy/pipelines/*.yml` | ✅ Enhanced |
| Manual Terraform deployment | Automated with templates | ✅ Improved |
| Basic validation | Enhanced validation pipeline | ✅ Improved |

---

## Migration Path

**Option 1: Update Pipeline References**
1. Update Azure DevOps pipeline definitions to point to `deploy/pipelines/`
2. Update service connections if needed
3. Test in dev environment
4. Roll out to UAT and production

**Option 2: Parallel Deployment**
1. Deploy unified pipelines alongside Day 3
2. Test unified pipelines thoroughly
3. Switch over when validated
4. Deprecate Day 3 pipelines

### Detailed Migration Guide

See: **[MIGRATION-GUIDE.md](../MIGRATION-GUIDE.md#day-3-to-unified)**

---

## What's in the Unified Solution?

Located in `deploy/pipelines/`:

### Enhanced Pipelines
- ✅ vm-deployment-pipeline.yml (multi-stage with AVM features)
- ✅ vm-operations-pipeline.yml (consolidated Day 2 operations)
- ✅ vm-full-orchestration.yml (complete lifecycle)
- ✅ state-import-pipeline.yml (state management)
- ✅ validation-pipeline.yml (comprehensive validation)

### Reusable Templates
- ✅ terraform-template.yml (standardized Terraform tasks)
- ✅ script-template.yml (standardized script execution)

### Security Enhancements
- ✅ AVM pattern validation
- ✅ Managed identity configuration
- ✅ Encryption verification
- ✅ Trusted Launch validation

---

## Need Help?

### Documentation
- **[ARCHITECTURE-UNIFIED.md](../ARCHITECTURE-UNIFIED.md)** - Complete system design
- **[MIGRATION-GUIDE.md](../MIGRATION-GUIDE.md)** - Migration instructions
- **[FEATURE-MATRIX.md](../FEATURE-MATRIX.md)** - Feature comparison

---

## Summary

- ⚠️ **This directory is DEPRECATED**
- ✅ **Use `deploy/pipelines/` for all new work**
- ✅ **All Day 3 orchestration preserved**
- ✅ **Plus AVM security, enhanced validation, telemetry**
- 📚 **See [MIGRATION-GUIDE.md](../MIGRATION-GUIDE.md) for details**

---

**Archived**: October 10, 2025  
**Replaced By**: Unified Solution in `deploy/pipelines/` directory  
**Migration Guide**: [MIGRATION-GUIDE.md](../MIGRATION-GUIDE.md)
