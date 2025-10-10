###############################################################################
# Run VM Deployment - Data Sources
# Remote state references for control plane and workload zone
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
# Workload Zone Remote State
# ============================================================================

data "terraform_remote_state" "workload_zone" {
  backend = "azurerm"
  
  config = {
    subscription_id      = var.workload_zone_subscription_id
    resource_group_name  = var.control_plane_resource_group
    storage_account_name = var.control_plane_storage_account
    container_name       = var.control_plane_container_name
    key                  = var.workload_zone_key
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
  control_plane_key_vault_uri        = data.terraform_remote_state.control_plane.outputs.key_vault_uri
  control_plane_random_id            = data.terraform_remote_state.control_plane.outputs.random_id
  control_plane_backend_config       = data.terraform_remote_state.control_plane.outputs.backend_config
  
  # State storage information
  state_storage_subscription_id      = local.control_plane_backend_config.subscription_id
  state_storage_resource_group       = local.control_plane_backend_config.resource_group_name
  state_storage_account_name         = local.control_plane_backend_config.storage_account_name
  state_storage_container_name       = local.control_plane_backend_config.container_name
}

# ============================================================================
# Outputs from Workload Zone Remote State
# ============================================================================

locals {
  # Workload zone outputs
  workload_zone_resource_group = data.terraform_remote_state.workload_zone.outputs.resource_group_name
  workload_zone_vnet_name      = data.terraform_remote_state.workload_zone.outputs.vnet_name
  workload_zone_vnet_id        = data.terraform_remote_state.workload_zone.outputs.vnet_id
  workload_zone_subnet_ids     = data.terraform_remote_state.workload_zone.outputs.subnet_ids
  workload_zone_subnet_names   = data.terraform_remote_state.workload_zone.outputs.subnet_names
  workload_zone_subnets        = data.terraform_remote_state.workload_zone.outputs.subnets
  
  # Network summary
  workload_zone_summary = data.terraform_remote_state.workload_zone.outputs.network_summary
}

# ============================================================================
# Subnet ID Lookup Helper
# ============================================================================

locals {
  # Create map of subnet keys to IDs for easy lookup
  subnet_id_map = {
    for key, id in local.workload_zone_subnet_ids : key => id
  }
  
  # Validate that all required subnets exist
  required_subnet_keys = distinct(concat(
    [for vm in local.linux_vms : vm.subnet_key],
    [for vm in local.windows_vms : vm.subnet_key]
  ))
  
  # Check if all required subnets are available
  missing_subnets = [
    for key in local.required_subnet_keys : key
    if !contains(keys(local.subnet_id_map), key)
  ]
}
