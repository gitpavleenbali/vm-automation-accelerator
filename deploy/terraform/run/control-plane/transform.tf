###############################################################################
# Transform Layer - Simplified
# Purpose: Essential local values for resource referencing
###############################################################################

# Note: azurerm_client_config and subscription_id are already defined in main.tf

locals {
  # Common tags (only the additional ones not in main.tf)
  common_tags = merge(
    {
      Environment     = var.environment
      Location        = var.location
      Project         = var.project_code
      ManagedBy       = "Terraform"
      Framework       = "VM-Automation-Accelerator"
      DeploymentType  = "run-control-plane"
    },
    var.tags
  )
  
  # Computed values for deployment tracking
  computed = {
    create_arm_tracking = false  # Disable ARM tracking for simplified deployment
    resource_group_id   = var.create_resource_group ? azurerm_resource_group.control_plane[0].id : data.azurerm_resource_group.existing[0].id
  }
  
  # Deployment metadata
  deployment = {
    id                = local.random_id
    type              = "control-plane"
    framework_version = "1.0.0"
    deployed_by       = "vm-automation-accelerator"
    timestamp         = timestamp()
  }
}
