###############################################################################
# Transform Layer - Simplified
# Purpose: Essential local values for resource referencing
###############################################################################

data "azurerm_client_config" "current" {}

locals {
  # Subscription ID
  subscription_id = coalesce(var.subscription_id, data.azurerm_client_config.current.subscription_id)
  
  # Common tags
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
}
