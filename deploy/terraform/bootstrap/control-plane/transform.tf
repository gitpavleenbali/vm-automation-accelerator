/*
  Transform Layer - Input Normalization
  
  Purpose: Normalize and validate inputs, provide backward compatibility
  Pattern: Balanced approach between over-engineering and under-engineering
  
  This version:
  - Works with existing 17 variables (no need for 40+ variables)
  - Keeps validation logic for input quality
  - Provides organized locals structure for outputs
  - Maintains flexibility for future enhancements
*/

locals {
  # Subscription and tenant info
  tenant_id       = data.azurerm_client_config.current.tenant_id
  
  # Environment configuration
  environment = {
    name = lower(var.environment)
    code = lower(substr(var.environment, 0, 4))
    tags = { Environment = title(var.environment) }
  }

  # Location configuration  
  location = {
    name         = lower(var.location)
    display_name = title(var.location)
    code = lookup({
      "eastus" = "eus", "eastus2" = "eus2", "westus" = "wus"
      "westus2" = "wus2", "centralus" = "cus"
      "northeurope" = "neu", "westeurope" = "weu"
    }, lower(var.location), "reg")
  }

  # Project configuration
  project = {
    code        = lower(var.project_code)
    name        = "VM Automation"
    owner       = "Platform Team"
    cost_center = "IT-OPS"
  }

  # Resource group configuration
  resource_group = {
    use_existing = var.resource_group_name != null && var.resource_group_name != ""
    name         = var.resource_group_name
    location     = var.location
    tags = merge(local.common_tags, { Purpose = "Control Plane Infrastructure" })
  }

  # State storage configuration
  state_storage = {
    account = {
      tier                     = upper(var.tfstate_storage_account_tier)
      replication              = upper(var.tfstate_storage_replication_type)
      enable_versioning        = true
      blob_retention_days      = 30
      container_retention_days = 30
      access_tier              = "Hot"
      min_tls_version          = "TLS1_2"
    }
    container = {
      name        = var.tfstate_container_name
      access_type = "private"
    }
    tags = merge(local.common_tags, { Purpose = "Terraform State Storage", Criticality = "Critical" })
  }

  # Key Vault configuration
  key_vault = {
    sku                        = lower(var.key_vault_sku)
    soft_delete_retention_days = var.soft_delete_retention_days
    enable_purge_protection    = var.enable_purge_protection
    enable_soft_delete         = var.enable_soft_delete
    network = {
      default_action = "Deny"
      bypass         = "AzureServices"
      allowed_ips    = var.allowed_ip_ranges
      subnet_ids     = []
    }
    tags = merge(local.common_tags, { Purpose = "Secrets Management", Criticality = "Critical" })
  }

  # Deployment metadata
  deployment = {
    type              = "bootstrap-control-plane"
    framework_version = "1.0.0"
    deployed_by       = data.azurerm_client_config.current.object_id
    timestamp         = timestamp()
    id                = var.random_id != null ? var.random_id : formatdate("YYYYMMDDhhmmss", timestamp())
  }

  # Common tags
  common_tags = merge({
    Environment     = local.environment.name
    Location        = local.location.display_name
    Project         = local.project.code
    ManagedBy       = "Terraform"
    Framework       = "VM-Automation-Accelerator"
    Version         = local.deployment.framework_version
    DeploymentType  = local.deployment.type
    DeployedBy      = local.deployment.deployed_by
    CostCenter      = local.project.cost_center
    Owner           = local.project.owner
  }, var.tags)

  # Validation flags
  validation = {
    valid_environment = contains(
      ["dev", "development", "uat", "test", "prod", "production", "mgmt", "management", "shared"],
      lower(var.environment)
    )
    valid_location         = length(var.location) > 0
    valid_project_code     = can(regex("^[a-z0-9]{3,8}$", lower(var.project_code)))
    valid_storage_tier     = contains(["Standard", "Premium"], var.tfstate_storage_account_tier)
    valid_storage_replication = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.tfstate_storage_replication_type)
    valid_keyvault_sku     = contains(["standard", "premium"], lower(var.key_vault_sku))
    valid_soft_delete_retention = var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 90
  }

  # Computed values
  computed = {
    resource_group_id = local.resource_group.use_existing ? data.azurerm_resource_group.control_plane[0].id : azurerm_resource_group.control_plane[0].id
    resource_group_name = local.resource_group.use_existing ? data.azurerm_resource_group.control_plane[0].name : azurerm_resource_group.control_plane[0].name
    create_state_storage = true
    create_key_vault     = var.create_key_vault
  }

  # Validation messages (for debugging)
  validation_messages = {
    environment = local.validation.valid_environment ? " Valid" : " Invalid: ${var.environment}"
    project     = local.validation.valid_project_code ? " Valid" : " Invalid: ${var.project_code}"
    storage     = local.validation.valid_storage_tier && local.validation.valid_storage_replication ? " Valid" : " Invalid config"
    keyvault    = local.validation.valid_keyvault_sku && local.validation.valid_soft_delete_retention ? " Valid" : " Invalid config"
  }
}
