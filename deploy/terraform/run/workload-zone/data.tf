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
    use_azuread_auth     = true
  }
}

# ============================================================================
# Existing Resource Group (if specified)
# ============================================================================

data "azurerm_resource_group" "existing" {
  count    = var.resource_group_name != null ? 1 : 0
  provider = azurerm.main
  name     = var.resource_group_name
}

# ============================================================================
# Outputs from Control Plane Remote State
# ============================================================================
# NOTE: These values are now in transform.tf as locals for better organization

