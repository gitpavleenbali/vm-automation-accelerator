# AVM Telemetry Implementation
# This file implements the Azure Verified Module telemetry pattern for module usage tracking
# For more information: https://aka.ms/avm/telemetryinfo

# Get the module source information for telemetry
data "modtm_module_source" "telemetry" {
  count = var.enable_telemetry ? 1 : 0

  module_path = path.module
}

# Generate a unique ID for this deployment for telemetry tracking
resource "random_uuid" "telemetry" {
  count = var.enable_telemetry ? 1 : 0
}

# Get Azure client configuration for telemetry context
data "azapi_client_config" "telemetry" {
  count = var.enable_telemetry ? 1 : 0
}

# Send telemetry data to Microsoft (non-sensitive usage metrics only)
resource "modtm_telemetry" "telemetry" {
  count = var.enable_telemetry ? 1 : 0

  tags = merge({
    subscription_id = one(data.azapi_client_config.telemetry).subscription_id
    tenant_id       = one(data.azapi_client_config.telemetry).tenant_id
    module_source   = one(data.modtm_module_source.telemetry).module_source
    module_version  = one(data.modtm_module_source.telemetry).module_version
    random_id       = one(random_uuid.telemetry).result
  }, { location = var.location })
}

# Build User-Agent header for Azure API calls (used in backup azapi_resource)
locals {
  avm_azapi_headers = !var.enable_telemetry ? {} : (local.fork_avm ? {
    fork_avm  = "true"
    random_id = one(random_uuid.telemetry).result
    } : {
    avm                = "true"
    random_id          = one(random_uuid.telemetry).result
    avm_module_source  = one(data.modtm_module_source.telemetry).module_source
    avm_module_version = one(data.modtm_module_source.telemetry).module_version
  })
}

# Validate if this is an official Azure module or a fork
locals {
  valid_module_source_regex = [
    "registry.terraform.io/[A|a]zure/.+",
    "registry.opentofu.io/[A|a]zure/.+",
    "git::https://github\\.com/[A|a]zure/.+",
    "git::ssh:://git@github\\.com/[A|a]zure/.+",
  ]
}

locals {
  fork_avm = !anytrue([for r in local.valid_module_source_regex : can(regex(r, one(data.modtm_module_source.telemetry).module_source))])
}

# Build User-Agent string for azapi_resource headers
locals {
  # tflint-ignore: terraform_unused_declarations
  avm_azapi_header = join(" ", [for k, v in local.avm_azapi_headers : "${k}=${v}"])
}
