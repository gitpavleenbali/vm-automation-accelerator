/*
  Transform Layer - Workload Zone Input Normalization
  
  Simplified configuration layer for essential workload zone setup
*/

locals {
  # Basic Configuration
  subscription_id = data.azurerm_client_config.current.subscription_id
  
  # Resource Group
  resource_group_name     = var.resource_group_name != null ? var.resource_group_name : module.naming.resource_group_names["network"]
  resource_group_location = var.location
  
  # Common Tags
  common_tags = merge(
    {
      Environment = var.environment
      Location    = var.location
      Project     = var.project_code
      Workload    = var.workload_name
      ManagedBy   = "Terraform"
      Framework   = "VM-Automation-Accelerator"
    },
    var.common_tags,
    var.tags
  )
  
  # Computed Values
  resource_group_id = var.resource_group_name != null ? data.azurerm_resource_group.existing[0].id : azurerm_resource_group.workload_zone[0].id
  
  # Control Plane Integration (from remote state in data.tf)
  control_plane_subscription_id      = data.terraform_remote_state.control_plane.outputs.subscription_id
  control_plane_resource_group       = data.terraform_remote_state.control_plane.outputs.resource_group_name
  control_plane_key_vault_name       = data.terraform_remote_state.control_plane.outputs.key_vault_name
  control_plane_key_vault_id         = data.terraform_remote_state.control_plane.outputs.key_vault_id
  control_plane_random_id            = data.terraform_remote_state.control_plane.outputs.random_id
  control_plane_backend_config       = data.terraform_remote_state.control_plane.outputs.backend_config
  
  # State Storage Information
  state_storage_subscription_id      = local.control_plane_backend_config.subscription_id
  state_storage_resource_group       = local.control_plane_backend_config.resource_group_name
  state_storage_account_name         = local.control_plane_backend_config.storage_account_name
  state_storage_container_name       = local.control_plane_backend_config.container_name
}
