###############################################################################
# Run Control Plane - Main Configuration
# Production deployment with remote state backend
###############################################################################

terraform {
  required_version = ">= 1.5.0"
  
  # Remote backend configuration (parameters provided via backend-config)
  backend "azurerm" {
    # Configuration provided via:
    # terraform init \
    #   -backend-config="subscription_id=xxx" \
    #   -backend-config="resource_group_name=xxx" \
    #   -backend-config="storage_account_name=xxx" \
    #   -backend-config="container_name=tfstate" \
    #   -backend-config="key=control-plane.tfstate"
  }
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.10"
    }
  }
}

# Main provider for control plane resources
provider "azurerm" {
  alias = "main"
  
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy    = !var.enable_purge_protection
      recover_soft_deleted_key_vaults = var.enable_soft_delete
    }
  }
  
  subscription_id = local.subscription_id
}

# Default provider (aliases to main)
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy    = !var.enable_purge_protection
      recover_soft_deleted_key_vaults = var.enable_soft_delete
    }
  }
  
  subscription_id = local.subscription_id
}

# AzAPI provider for advanced features
provider "azapi" {
  subscription_id = local.subscription_id
}

# ============================================================================
# Data Sources
# ============================================================================

# Get current client configuration
data "azurerm_client_config" "current" {
  provider = azurerm.main
}

# Get existing resource group if specified
data "azurerm_resource_group" "existing" {
  count    = !var.create_resource_group ? 1 : 0
  provider = azurerm.main
  name     = var.resource_group_name
}

# Generate random ID for globally unique resources
resource "random_id" "unique" {
  byte_length = 4
}

locals {
  random_id       = var.random_id != "" ? var.random_id : random_id.unique.hex
  subscription_id = var.subscription_id != "" ? var.subscription_id : data.azurerm_client_config.current.subscription_id
}

# ============================================================================
# Naming Module
# ============================================================================

module "naming" {
  source = "../../terraform-units/modules/naming"
  
  environment      = var.environment
  location         = var.location
  project_code     = var.project_code
  workload_name    = "control"
  instance_number  = "01"
  random_id        = ""
  
  resource_prefixes = {
    resource_group  = "rg"
    storage_account = "st"
    key_vault       = "kv"
  }
  
  resource_suffixes = {
    resource_group  = "cp-rg"
    storage_account = "tfstate"
    key_vault       = "cp-kv"
  }
}

# ============================================================================
# Resource Group
# ============================================================================

resource "azurerm_resource_group" "control_plane" {
  count    = var.create_resource_group ? 1 : 0
  provider = azurerm.main
  
  name     = var.resource_group_name != null && var.resource_group_name != "" ? var.resource_group_name : module.naming.resource_group_name
  location = var.location
  tags     = local.common_tags
}

locals {
  resource_group_name = var.create_resource_group ? (
    azurerm_resource_group.control_plane[0].name
  ) : (
    data.azurerm_resource_group.existing[0].name
  )
  
  resource_group_location = var.create_resource_group ? (
    azurerm_resource_group.control_plane[0].location
  ) : (
    data.azurerm_resource_group.existing[0].location
  )
}

# ============================================================================
# State Storage Account
# ============================================================================

resource "azurerm_storage_account" "tfstate" {
  provider = azurerm.main
  
  name                     = module.naming.storage_account_names["main"]
  resource_group_name      = local.resource_group_name
  location                 = local.resource_group_location
  account_tier             = var.state_storage_account_tier
  account_replication_type = var.state_storage_account_replication
  access_tier              = "Hot"
  
  https_traffic_only_enabled = true
  min_tls_version            = "TLS1_2"
  
  blob_properties {
    versioning_enabled = true
    
    delete_retention_policy {
      days = 30
    }
    
    container_delete_retention_policy {
      days = 30
    }
  }
  
  tags = local.common_tags
  
  depends_on = [azurerm_resource_group.control_plane]
}

# State storage container
resource "azurerm_storage_container" "tfstate" {
  provider = azurerm.main
  
  name                  = var.state_storage_container_name
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

# ============================================================================
# Key Vault
# ============================================================================

resource "azurerm_key_vault" "control_plane" {
  provider = azurerm.main
  
  name                = module.naming.key_vault_name
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  
  sku_name = var.key_vault_sku
  
  soft_delete_retention_days = var.key_vault_soft_delete_retention_days
  purge_protection_enabled   = var.key_vault_enable_purge_protection
  
  network_acls {
    default_action             = var.key_vault_network_default_action
    bypass                     = var.key_vault_network_bypass
    ip_rules                   = var.key_vault_allowed_ip_addresses
    virtual_network_subnet_ids = var.key_vault_subnet_ids
  }
  
  tags = local.common_tags
  
  depends_on = [azurerm_resource_group.control_plane]
}

# Grant current user Key Vault Administrator role
resource "azurerm_role_assignment" "keyvault_admin" {
  provider = azurerm.main
  
  scope                = azurerm_key_vault.control_plane.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# ============================================================================
# ARM Deployment Tracking (for Azure Portal visibility)
# ============================================================================

resource "azurerm_resource_group_template_deployment" "control_plane" {
  count               = local.computed.create_arm_tracking ? 1 : 0
  provider            = azurerm.main
  
  name                = "vm-automation-control-plane-${local.deployment.id}"
  resource_group_name = local.resource_group_name
  deployment_mode     = "Incremental"
  
  template_content = jsonencode({
    "$schema"      = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
    contentVersion = "1.0.0.0"
    resources      = []
    outputs = {
      deploymentType = {
        type  = "string"
        value = local.deployment.type
      }
      frameworkVersion = {
        type  = "string"
        value = local.deployment.framework_version
      }
      deployedBy = {
        type  = "string"
        value = local.deployment.deployed_by
      }
      timestamp = {
        type  = "string"
        value = local.deployment.timestamp
      }
    }
  })
  
  tags = merge(
    local.common_tags,
    {
      DeploymentTracking = "ARM"
    }
  )
  
  depends_on = [
    azurerm_storage_account.tfstate,
    azurerm_key_vault.control_plane
  ]
}
