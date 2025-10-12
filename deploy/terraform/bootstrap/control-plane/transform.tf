/*
  Transform Layer - Input Normalization (Simplified)
  
  Purpose: Normalize inputs into consistent local objects
  Note: Simplified version without circular dependencies
*/

locals {
  # Common tags applied to all resources
  common_tags = merge(
    {
      Environment     = var.environment
      Location        = var.location
      Project         = var.project_code
      ManagedBy       = "Terraform"
      Framework       = "VM-Automation-Accelerator"
      DeploymentType  = "bootstrap-control-plane"
    },
    var.tags
  )
}
