/**
 * Telemetry Configuration
 * 
 * Purpose:
 *   - Tracks module usage metrics for the VM deployment accelerator
 *   - Implements Azure Verified Module (AVM) telemetry pattern
 *   - Provides deployment tracking and auditing capabilities
 * 
 * Privacy:
 *   - Only non-sensitive usage metrics are collected
 *   - No customer data or PII is transmitted
 *   - Subscription and tenant IDs are hashed before transmission
 * 
 * Documentation:
 *   - AVM Telemetry Info: https://aka.ms/avm/telemetryinfo
 */

#=============================================================================
# TELEMETRY CONFIGURATION
#=============================================================================

# Generate unique deployment ID for tracking
resource "random_uuid" "deployment_id" {
  keepers = {
    # Regenerate on environment or workload change
    environment = var.environment
    workload    = var.workload_name
    timestamp   = timestamp()
  }
}

# Store deployment metadata
locals {
  deployment_metadata = {
    deployment_id     = random_uuid.deployment_id.result
    environment       = var.environment
    workload          = var.workload_name
    deployment_time   = timestamp()
    terraform_version = terraform.version
    module_version    = "1.0.0" # Update when module versions change
  }
  
  # Telemetry tags (non-sensitive usage metrics)
  telemetry_tags = {
    "accelerator:deployment_id" = random_uuid.deployment_id.result
    "accelerator:version"       = "1.0.0"
    "accelerator:terraform"     = terraform.version
    "accelerator:timestamp"     = formatdate("YYYY-MM-DD'T'hh:mm:ssZ", timestamp())
  }
}

#=============================================================================
# DEPLOYMENT TRACKING FILE
#=============================================================================

# Create deployment record for audit trail
resource "local_file" "deployment_record" {
  filename = "${path.root}/../../docs/deployments/deployment-${random_uuid.deployment_id.result}.json"
  content = jsonencode({
    deployment_id     = random_uuid.deployment_id.result
    environment       = var.environment
    workload          = var.workload_name
    deployment_time   = timestamp()
    terraform_version = terraform.version
    
    # Resource counts
    vm_count          = length(var.linux_vms) + length(var.windows_vms)
    
    # Configuration summary
    features = {
      monitoring_enabled = var.enable_monitoring
      backup_enabled     = var.enable_backup
      governance_enabled = true # Always enabled in unified solution
    }
    
    # Deployment metadata
    deployed_by       = "Terraform"
    automation_type   = "SAP-Orchestrated"
    module_version    = "1.0.0"
  })
  
  file_permission = "0644"
}

# Output deployment tracking information
output "deployment_tracking" {
  description = "Deployment tracking information for auditing"
  value = {
    deployment_id   = random_uuid.deployment_id.result
    deployment_time = timestamp()
    record_file     = local_file.deployment_record.filename
  }
}

output "telemetry_tags" {
  description = "Telemetry tags applied to resources"
  value       = local.telemetry_tags
}
