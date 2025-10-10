###############################################################################
# Run Workload Zone - Data Sources
# Remote state references and existing resource lookups
###############################################################################

# ============================================================================
# Current Azure Context
# ============================================================================

data "azurerm_client_config" "current" {
  provider = azurerm.main
}

# ============================================================================
# Control Plane Remote State
# ============================================================================

data "terraform_remote_state" "control_plane" {
  backend = "azurerm"
  
  config = {
    subscription_id      = var.control_plane_subscription_id
    resource_group_name  = var.control_plane_resource_group
    storage_account_name = var.control_plane_storage_account
    container_name       = var.control_plane_container_name
    key                  = "control-plane.tfstate"
  }
}

# ============================================================================
# Existing Resource Group (if specified)
# ============================================================================

data "azurerm_resource_group" "existing" {
  count    = local.resource_group.use_existing ? 1 : 0
  provider = azurerm.main
  name     = local.resource_group.name
}

# ============================================================================
# Outputs from Control Plane Remote State
# ============================================================================

locals {
  # Control plane outputs
  control_plane_subscription_id      = data.terraform_remote_state.control_plane.outputs.subscription_id
  control_plane_resource_group       = data.terraform_remote_state.control_plane.outputs.resource_group_name
  control_plane_key_vault_name       = data.terraform_remote_state.control_plane.outputs.key_vault_name
  control_plane_key_vault_id         = data.terraform_remote_state.control_plane.outputs.key_vault_id
  control_plane_random_id            = data.terraform_remote_state.control_plane.outputs.random_id
  control_plane_backend_config       = data.terraform_remote_state.control_plane.outputs.backend_config
  
  # State storage information
  state_storage_subscription_id      = local.control_plane_backend_config.subscription_id
  state_storage_resource_group       = local.control_plane_backend_config.resource_group_name
  state_storage_account_name         = local.control_plane_backend_config.storage_account_name
  state_storage_container_name       = local.control_plane_backend_config.container_name
}
