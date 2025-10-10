# Backend Configuration for Remote State Management
# This file configures Azure Storage as the backend for Terraform state
# State locking is enabled via Azure Blob Storage lease mechanism

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.13.0"
    }
    modtm = {
      source  = "Azure/modtm"
      version = "~> 0.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
  }

  # Remote Backend Configuration
  # Backend configuration is partially defined here and completed via backend config file
  # Use: terraform init -backend-config="backend-config/prod.hcl"
  backend "azurerm" {
    # These values are provided via backend config files for different environments
    # resource_group_name  = "rg-terraform-state-prod"
    # storage_account_name = "stuniptertfstateprod"
    # container_name       = "tfstate"
    # key                  = "vm-automation/prod/terraform.tfstate"
    # use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    
    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = true
      skip_shutdown_and_force_delete = false
    }
    
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
  
  # Use Managed Identity or Service Principal authentication
  use_msi = true
}

provider "azuread" {
  use_msi = true
}
