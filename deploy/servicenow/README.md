# ServiceNow Integration Guide
## VM Automation Accelerator - Unified Solution

**Version**: 2.0.0  
**Status**: Complete  
**Last Updated**: October 10, 2025

---

## Overview

This document describes the ServiceNow integration for the VM Automation Accelerator unified solution. The integration provides a seamless self-service experience for VM lifecycle management through ServiceNow catalog items.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│              ServiceNow Service Catalog                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ VM Order     │  │ Disk Modify  │  │ SKU Change   │     │
│  │ Catalog Item │  │ Catalog Item │  │ Catalog Item │     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
│         │                  │                  │              │
└─────────┼──────────────────┼──────────────────┼──────────────┘
          │                  │                  │
          ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────┐
│           ServiceNow Workflows / Flow Designer              │
│  • Approval routing                                          │
│  • REST API calls to wrappers                                │
│  • Status tracking                                           │
└─────────┬────────────────────────────────────────┬──────────┘
          │                                        │
          ▼                                        ▼
┌─────────────────────────────────────────────────────────────┐
│          API Wrappers (Bash Scripts)                         │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │ vm-order-api.sh  │  │ vm-disk-modify-  │                │
│  │                  │  │ api.sh           │                │
│  └────────┬─────────┘  └────────┬─────────┘                │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │ vm-sku-change-   │  │ vm-restore-      │                │
│  │ api.sh           │  │ api.sh           │                │
│  └────────┬─────────┘  └────────┬─────────┘                │
│           │                      │                           │
│  • Parse ServiceNow JSON payload                            │
│  • Validate inputs                                           │
│  • Trigger Azure DevOps pipelines                           │
│  • Update ServiceNow tickets                                 │
└───────────┼──────────────────────┼──────────────────────────┘
            │                      │
            ▼                      ▼
┌─────────────────────────────────────────────────────────────┐
│           Azure DevOps Pipelines                             │
│  • vm-deployment-pipeline.yml                                │
│  • vm-operations-pipeline.yml                                │
└───────────┼──────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────┐
│           SAP Deployment Scripts                             │
│  • deploy_vm.sh                                              │
│  • Terraform execution                                       │
└─────────────────────────────────────────────────────────────┘
```

---

## Components

### 1. ServiceNow Catalog Items

Located in: `deploy/servicenow/catalog-items/`

**Available Catalog Items:**
1. **vm-order-catalog-item.xml** - New VM provisioning
2. **vm-disk-modify-catalog-item.xml** - Disk operations (add/resize/delete)
3. **vm-sku-change-catalog-item.xml** - Vertical scaling (VM size changes)
4. **vm-restore-catalog-item.xml** - Backup and restore operations

### 2. API Wrappers

Located in: `deploy/servicenow/api/`

**Available Wrappers:**

#### vm-order-api.sh (245 lines)
- Handles new VM provisioning requests
- Parses ServiceNow JSON payload
- Triggers `vm-deployment-pipeline.yml`
- Supports both pipeline and direct script execution
- Updates ServiceNow ticket status

**Usage:**
```bash
./vm-order-api.sh '{
  "sys_id": "CHG0123456",
  "variables": {
    "vm_name": "dev-vm-web-eastus-001",
    "vm_size": "Standard_D2s_v3",
    "os_type": "Linux",
    "environment": "dev",
    "enable_backup": "true",
    "enable_monitoring": "true"
  }
}'
```

#### vm-disk-modify-api.sh (220 lines)
- Handles disk add/resize/delete operations
- Validates disk size (minimum 32 GB)
- Triggers `vm-operations-pipeline.yml` with disk-modify operation
- Supports Premium_LRS, Standard_LRS, StandardSSD_LRS, UltraSSD_LRS

**Usage:**
```bash
./vm-disk-modify-api.sh '{
  "sys_id": "CHG0123457",
  "variables": {
    "vm_name": "dev-vm-web-eastus-001",
    "disk_operation": "add",
    "disk_size_gb": "256",
    "disk_type": "Premium_LRS",
    "environment": "dev"
  }
}'
```

#### vm-sku-change-api.sh (190 lines)
- Handles VM size changes (vertical scaling)
- Validates SKU against allowed list
- Automatically stops/starts VM during resize
- Triggers `vm-operations-pipeline.yml` with sku-change operation

**Usage:**
```bash
./vm-sku-change-api.sh '{
  "sys_id": "CHG0123458",
  "variables": {
    "vm_name": "dev-vm-web-eastus-001",
    "current_vm_size": "Standard_D2s_v3",
    "new_vm_size": "Standard_D4s_v3",
    "environment": "dev",
    "reason": "Increased performance requirements"
  }
}'
```

#### vm-restore-api.sh (200 lines)
- Handles backup and restore operations
- Lists available recovery points
- Restores VM from specific recovery point
- Triggers `vm-operations-pipeline.yml` with backup-restore operation

**Usage:**
```bash
# List recovery points
./vm-restore-api.sh '{
  "sys_id": "CHG0123459",
  "variables": {
    "vm_name": "prod-vm-db-eastus-042",
    "backup_action": "list-recovery-points",
    "environment": "prod"
  }
}'

# Restore from recovery point
./vm-restore-api.sh '{
  "sys_id": "CHG0123459",
  "variables": {
    "vm_name": "prod-vm-db-eastus-042",
    "backup_action": "restore",
    "recovery_point_id": "rec-20251010-120000",
    "environment": "prod",
    "reason": "Data corruption recovery"
  }
}'
```

---

## Configuration

### Environment Variables

Set these environment variables for API wrapper operation:

**Azure DevOps Configuration:**
```bash
export AZURE_DEVOPS_ORG="https://dev.azure.com/yourorg"
export AZURE_DEVOPS_PROJECT="YourProject"
export AZURE_DEVOPS_PAT="your-personal-access-token"
export VM_DEPLOYMENT_PIPELINE_ID="123"
export VM_OPERATIONS_PIPELINE_ID="124"
```

**ServiceNow Configuration:**
```bash
export SNOW_INSTANCE="your-instance.service-now.com"
export SNOW_USERNAME="api_user"
export SNOW_PASSWORD="api_password"
```

**Deployment Method:**
```bash
# Use pipeline (recommended for production)
export DEPLOYMENT_METHOD="pipeline"

# Or use direct script execution (for testing)
export DEPLOYMENT_METHOD="direct"
```

---

## ServiceNow Setup

### Step 1: Import Catalog Items

1. Navigate to **Service Catalog > Catalog Definitions > Maintain Items**
2. Click **Import XML**
3. Select catalog XML files from `deploy/servicenow/catalog-items/`
4. Import each catalog item

### Step 2: Configure REST API Endpoints

Create REST API endpoints in ServiceNow that call the API wrappers:

**Example REST Endpoint Configuration:**
- **Name**: VM Order API
- **Endpoint URL**: `https://your-api-server.com/api/vm-order`
- **HTTP Method**: POST
- **Authentication**: Basic Auth or OAuth
- **Request Body**: JSON payload from catalog variables

### Step 3: Create Workflows

Create ServiceNow workflows to:
1. Capture catalog form variables
2. Route for approval (if required)
3. Call REST API endpoint with JSON payload
4. Monitor pipeline execution
5. Update ticket status

**Workflow Example:**
```
[Start] → [Approval] → [REST API Call] → [Monitor Status] → [Complete]
```

### Step 4: Configure Approval Rules

Set up approval rules based on:
- Environment (prod requires L2 approval)
- VM size (large VMs require manager approval)
- Cost threshold

---

## Integration Testing

### Test VM Order
```bash
cd deploy/servicenow/api

# Test with dev environment
./vm-order-api.sh '{
  "sys_id": "TEST001",
  "variables": {
    "vm_name": "dev-vm-test-eastus-001",
    "vm_size": "Standard_B2s",
    "os_type": "Linux",
    "environment": "dev",
    "enable_backup": "false",
    "enable_monitoring": "true"
  }
}'
```

### Test Disk Modification
```bash
./vm-disk-modify-api.sh '{
  "sys_id": "TEST002",
  "variables": {
    "vm_name": "dev-vm-test-eastus-001",
    "disk_operation": "add",
    "disk_size_gb": "128",
    "disk_type": "Standard_LRS",
    "environment": "dev"
  }
}'
```

### Test SKU Change
```bash
./vm-sku-change-api.sh '{
  "sys_id": "TEST003",
  "variables": {
    "vm_name": "dev-vm-test-eastus-001",
    "new_vm_size": "Standard_B2ms",
    "environment": "dev"
  }
}'
```

---

## Monitoring and Troubleshooting

### Logs

All API wrappers log to `deploy/servicenow/logs/`:
- `vm-order-api.log`
- `vm-disk-modify-api.log`
- `vm-sku-change-api.log`
- `vm-restore-api.log`

### Pipeline Run Tracking

Each ServiceNow ticket gets:
- `{ticket-id}.runid` - Azure DevOps run ID
- `{ticket-id}.runurl` - Direct link to pipeline run

### Common Issues

**Issue: Pipeline trigger fails**
- Check AZURE_DEVOPS_PAT is valid
- Verify pipeline IDs are correct
- Check network connectivity to Azure DevOps

**Issue: ServiceNow ticket not updating**
- Verify SNOW_USERNAME and SNOW_PASSWORD
- Check ServiceNow API permissions
- Verify ticket ID format

**Issue: Validation errors**
- Check JSON payload structure
- Verify required fields present
- Check value constraints (disk size, SKU list)

---

## API Response Format

All API wrappers return JSON responses:

**Success Response:**
```json
{
  "status": "success",
  "message": "Pipeline triggered successfully",
  "ticket_id": "CHG0123456",
  "vm_name": "dev-vm-web-eastus-001",
  "run_url": "https://dev.azure.com/yourorg/project/_build/results?buildId=123"
}
```

**Error Response:**
```json
{
  "status": "error",
  "message": "VM name is required",
  "ticket_id": "CHG0123456"
}
```

---

## Security Considerations

1. **Authentication**: Use service accounts with least privilege
2. **PAT Tokens**: Rotate Azure DevOps PATs regularly (90 days)
3. **Network**: Restrict API wrapper access to ServiceNow IPs
4. **Encryption**: All communication over HTTPS
5. **Audit**: All operations logged with ticket ID and user

---

## Future Enhancements

- [ ] Webhook-based status updates (push instead of poll)
- [ ] Enhanced error handling and retry logic
- [ ] Cost approval workflows based on VM size
- [ ] Automated testing framework
- [ ] Dashboard for ServiceNow-initiated deployments
- [ ] Integration with CMDB for VM inventory

---

## Support

For issues or questions:
- Review logs in `deploy/servicenow/logs/`
- Check Azure DevOps pipeline runs
- Verify ServiceNow ticket work notes
- Contact DevOps team

---

**Document Version**: 1.0  
**Last Updated**: October 10, 2025  
**Status**: Complete - Phase 3 Integration
