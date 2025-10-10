###############################################################################
# Bootstrap Control Plane - Main Configuration
# Creates foundational infrastructure for VM automation
###############################################################################

terraform {
  required_version = ">= 1.5.0"
  
  # Local backend for bootstrap (will migrate to remote after creation)
  backend "local" {
    path = "terraform.tfstate"
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
  }
}

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
  
  subscription_id = var.subscription_id != "" ? var.subscription_id : null
}

# Get current client configuration
data "azurerm_client_config" "current" {}

# Get existing resource group if specified
data "azurerm_resource_group" "existing" {
  count = local.resource_group.use_existing ? 1 : 0
  name  = local.resource_group.name
}

# Generate random ID for globally unique resources
resource "random_id" "unique" {
  byte_length = 4
}

locals {
  random_id = var.random_id != "" ? var.random_id : random_id.unique.hex
  subscription_id = var.subscription_id != "" ? var.subscription_id : data.azurerm_client_config.current.subscription_id
}

###############################################################################
# Naming Module
###############################################################################
module "naming" {
  source = "../../terraform-units/modules/naming"
  
  environment   = var.environment
  location      = var.location
  project_code  = var.project_code
  workload_name = "controlplane"
  random_id     = local.random_id
  tags          = var.tags
}

###############################################################################
# Resource Group
###############################################################################
resource "azurerm_resource_group" "control_plane" {
  count    = var.create_resource_group ? 1 : 0
  name     = var.resource_group_name != "" ? var.resource_group_name : module.naming.resource_group_names["main"]
  location = var.location
  tags     = module.naming.common_tags
}

data "azurerm_resource_group" "control_plane" {
  count = var.create_resource_group ? 0 : 1
  name  = var.resource_group_name
}

locals {
  resource_group_name = var.create_resource_group ? azurerm_resource_group.control_plane[0].name : data.azurerm_resource_group.control_plane[0].name
  resource_group_id   = var.create_resource_group ? azurerm_resource_group.control_plane[0].id : data.azurerm_resource_group.control_plane[0].id
}

###############################################################################
# Storage Account for Terraform State
###############################################################################
resource "azurerm_storage_account" "tfstate" {
  name                     = module.naming.storage_account_names["tfstate"]
  resource_group_name      = local.resource_group_name
  location                 = var.location
  account_tier             = var.tfstate_storage_account_tier
  account_replication_type = var.tfstate_storage_replication_type
  min_tls_version          = "TLS1_2"
  
  blob_properties {
    versioning_enabled = true
    
    delete_retention_policy {
      days = 30
    }
    
    container_delete_retention_policy {
      days = 30
    }
  }
  
  tags = merge(
    module.naming.common_tags,
    {
      Purpose = "Terraform State Storage"
    }
  )
}

resource "azurerm_storage_container" "tfstate" {
  name                  = var.tfstate_container_name
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"
}

###############################################################################
# Key Vault for Secrets
###############################################################################
resource "azurerm_key_vault" "control_plane" {
  count                       = var.create_key_vault ? 1 : 0
  name                        = module.naming.key_vault_name
  location                    = var.location
  resource_group_name         = local.resource_group_name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = var.key_vault_sku
  soft_delete_retention_days  = var.soft_delete_retention_days
  purge_protection_enabled    = var.enable_purge_protection
  enable_rbac_authorization   = true
  
  network_acls {
    default_action = length(var.allowed_ip_ranges) > 0 ? "Deny" : "Allow"
    bypass         = "AzureServices"
    ip_rules       = var.allowed_ip_ranges
  }
  
  tags = merge(
    module.naming.common_tags,
    {
      Purpose = "Control Plane Secrets"
    }
  )
}

# Grant current user Key Vault Administrator role
resource "azurerm_role_assignment" "keyvault_admin" {
  count                = var.create_key_vault ? 1 : 0
  scope                = azurerm_key_vault.control_plane[0].id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

###############################################################################
# ARM Deployment Tracking
###############################################################################
resource "azurerm_resource_group_template_deployment" "control_plane" {
  name                = "VM-Automation.bootstrap.control-plane"
  resource_group_name = local.resource_group_name
  deployment_mode     = "Incremental"
  
  template_content = jsonencode({
    "$schema"        = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
    "contentVersion" = "1.0.0.0"
    "parameters" = {
      "DeploymentType" = {
        "type"         = "string"
        "defaultValue" = "Bootstrap Control Plane"
      }
      "AutomationVersion" = {
        "type"         = "string"
        "defaultValue" = "1.0.0"
      }
    }
    "resources" = []
  })
  
  tags = module.naming.common_tags
}
