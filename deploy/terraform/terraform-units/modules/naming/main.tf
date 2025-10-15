###############################################################################
# Naming Module - Main Logic
# Centralized naming convention enforcement
###############################################################################

locals {
  # Location code mapping (SAP pattern)
  location_codes = {
    "eastus"          = "eus"
    "eastus2"         = "eus2"
    "westus"          = "wus"
    "westus2"         = "wus2"
    "westus3"         = "wus3"
    "centralus"       = "cus"
    "northcentralus"  = "ncus"
    "southcentralus"  = "scus"
    "northeurope"     = "neu"
    "westeurope"      = "weu"
    "uksouth"         = "uks"
    "ukwest"          = "ukw"
    "francecentral"   = "frc"
    "francesouth"     = "frs"
    "germanywestcentral" = "gwc"
    "norwayeast"      = "noe"
    "switzerlandnorth" = "swn"
    "swedencentral"   = "swc"
    "canadacentral"   = "cac"
    "canadaeast"      = "cae"
    "brazilsouth"     = "brs"
    "southafricanorth" = "san"
    "australiaeast"   = "aue"
    "australiasoutheast" = "ase"
    "australiacentral" = "auc"
    "japaneast"       = "jpe"
    "japanwest"       = "jpw"
    "koreacentral"    = "krc"
    "koreasouth"      = "krs"
    "southeastasia"   = "sea"
    "eastasia"        = "eas"
    "southindia"      = "sin"
    "centralindia"    = "cin"
    "westindia"       = "win"
    "uaenorth"        = "uan"
  }
  
  location_code = lookup(local.location_codes, lower(var.location), substr(replace(lower(var.location), "/[^a-z]/", ""), 0, 3))
  
  # Azure resource name length limits (SAP pattern)
  name_limits = {
    vm                    = 64
    vmss                  = 64
    nic                   = 80
    pip                   = 80
    storage_account       = 24
    disk                  = 80
    vnet                  = 64
    subnet                = 80
    nsg                   = 80
    route_table           = 80
    load_balancer         = 80
    application_gateway   = 80
    key_vault             = 24
    managed_identity      = 128
    log_analytics         = 63
    application_insights  = 255
    action_group          = 260
    resource_group        = 90
  }
  
  # Base naming components
  environment_code = lower(var.environment)
  project_code     = lower(var.project_code)
  workload_code    = var.workload_name != "" ? lower(var.workload_name) : ""
  instance_code    = var.instance_number
  random_code      = var.use_random_suffix && var.random_id != "" ? var.random_id : ""
  
  # Common tags
  common_tags = merge(
    var.tags,
    {
      Environment   = var.environment
      Location      = var.location
      ManagedBy     = "Terraform"
      Framework     = "VM-Automation-Accelerator"
      NamingModule  = "v1.0.0"
    }
  )
}

###############################################################################
# Resource Group Naming
###############################################################################
locals {
  resource_group_base = "${var.resource_prefixes["resource_group"]}-${local.project_code}-${local.environment_code}-${local.location_code}"
  
  resource_group_names = {
    main       = try(var.custom_names["resource_group_main"], "${local.resource_group_base}-main${var.resource_suffixes["resource_group"]}")
    network    = try(var.custom_names["resource_group_network"], "${local.resource_group_base}-network${var.resource_suffixes["resource_group"]}")
    compute    = try(var.custom_names["resource_group_compute"], "${local.resource_group_base}-compute${var.resource_suffixes["resource_group"]}")
    storage    = try(var.custom_names["resource_group_storage"], "${local.resource_group_base}-storage${var.resource_suffixes["resource_group"]}")
    monitoring = try(var.custom_names["resource_group_monitoring"], "${local.resource_group_base}-monitoring${var.resource_suffixes["resource_group"]}")
    security   = try(var.custom_names["resource_group_security"], "${local.resource_group_base}-security${var.resource_suffixes["resource_group"]}")
  }
}

###############################################################################
# Compute Resource Naming
###############################################################################
locals {
  vm_base = local.workload_code != "" ? "${var.resource_prefixes["vm"]}-${local.environment_code}-${local.location_code}-${local.workload_code}" : "${var.resource_prefixes["vm"]}-${local.environment_code}-${local.location_code}"
  
  vm_names = {
    linux = [
      for i in range(10) : substr(
        try(
          var.custom_names["vm_linux_${i}"],
          "${local.vm_base}-${format("%02d", i + 1)}${var.resource_suffixes["vm"]}"
        ),
        0,
        local.name_limits["vm"]
      )
    ]
    windows = [
      for i in range(10) : substr(
        try(
          var.custom_names["vm_windows_${i}"],
          "${local.vm_base}-${format("%02d", i + 1)}${var.resource_suffixes["vm"]}"
        ),
        0,
        local.name_limits["vm"]
      )
    ]
  }
  
  vmss_name = substr(
    try(
      var.custom_names["vmss"],
      local.workload_code != "" ? "${var.resource_prefixes["vmss"]}-${local.environment_code}-${local.location_code}-${local.workload_code}${var.resource_suffixes["vmss"]}" : "${var.resource_prefixes["vmss"]}-${local.environment_code}-${local.location_code}${var.resource_suffixes["vmss"]}"
    ),
    0,
    local.name_limits["vmss"]
  )
  
  nic_names = [
    for i in range(10) : substr(
      try(
        var.custom_names["nic_${i}"],
        "${var.resource_prefixes["nic"]}-${local.environment_code}-${local.location_code}-${format("%02d", i + 1)}${var.resource_suffixes["nic"]}"
      ),
      0,
      local.name_limits["nic"]
    )
  ]
  
  pip_names = [
    for i in range(10) : substr(
      try(
        var.custom_names["pip_${i}"],
        "${var.resource_prefixes["pip"]}-${local.environment_code}-${local.location_code}-${format("%02d", i + 1)}${var.resource_suffixes["pip"]}"
      ),
      0,
      local.name_limits["pip"]
    )
  ]
}

###############################################################################
# Storage Resource Naming
###############################################################################
locals {
  # Storage accounts must be lowercase alphanumeric only, no hyphens
  storage_account_base = replace(
    "${var.resource_prefixes["storage_account"]}${local.project_code}${local.environment_code}${local.location_code}",
    "/[^a-z0-9]/",
    ""
  )
  
  storage_account_names = {
    main       = substr(
      try(
        var.custom_names["storage_account_main"],
        "${local.storage_account_base}${local.random_code != "" ? local.random_code : "main"}"
      ),
      0,
      local.name_limits["storage_account"]
    )
    diag       = substr(
      try(
        var.custom_names["storage_account_diag"],
        "${local.storage_account_base}diag${local.random_code}"
      ),
      0,
      local.name_limits["storage_account"]
    )
    boot       = substr(
      try(
        var.custom_names["storage_account_boot"],
        "${local.storage_account_base}boot${local.random_code}"
      ),
      0,
      local.name_limits["storage_account"]
    )
    tfstate    = substr(
      try(
        var.custom_names["storage_account_tfstate"],
        "${local.storage_account_base}tfstate${local.random_code}"
      ),
      0,
      local.name_limits["storage_account"]
    )
  }
  
  disk_names = [
    for i in range(10) : substr(
      try(
        var.custom_names["disk_${i}"],
        "${var.resource_prefixes["disk"]}-${local.environment_code}-${local.location_code}-${format("%02d", i + 1)}${var.resource_suffixes["disk"]}"
      ),
      0,
      local.name_limits["disk"]
    )
  ]
}

###############################################################################
# Network Resource Naming
###############################################################################
locals {
  vnet_name = substr(
    try(
      var.custom_names["vnet"],
      local.workload_code != "" ? "${var.resource_prefixes["vnet"]}-${local.environment_code}-${local.location_code}-${local.workload_code}${var.resource_suffixes["vnet"]}" : "${var.resource_prefixes["vnet"]}-${local.environment_code}-${local.location_code}${var.resource_suffixes["vnet"]}"
    ),
    0,
    local.name_limits["vnet"]
  )
  
  subnet_names = {
    default      = substr(try(var.custom_names["subnet_default"], "${var.resource_prefixes["subnet"]}-default${var.resource_suffixes["subnet"]}"), 0, local.name_limits["subnet"])
    web          = substr(try(var.custom_names["subnet_web"], "${var.resource_prefixes["subnet"]}-web${var.resource_suffixes["subnet"]}"), 0, local.name_limits["subnet"])
    app          = substr(try(var.custom_names["subnet_app"], "${var.resource_prefixes["subnet"]}-app${var.resource_suffixes["subnet"]}"), 0, local.name_limits["subnet"])
    data         = substr(try(var.custom_names["subnet_data"], "${var.resource_prefixes["subnet"]}-data${var.resource_suffixes["subnet"]}"), 0, local.name_limits["subnet"])
    management   = substr(try(var.custom_names["subnet_management"], "${var.resource_prefixes["subnet"]}-mgmt${var.resource_suffixes["subnet"]}"), 0, local.name_limits["subnet"])
    gateway      = substr(try(var.custom_names["subnet_gateway"], "GatewaySubnet"), 0, local.name_limits["subnet"])
    bastion      = substr(try(var.custom_names["subnet_bastion"], "AzureBastionSubnet"), 0, local.name_limits["subnet"])
  }
  
  nsg_names = {
    default      = substr(try(var.custom_names["nsg_default"], "${var.resource_prefixes["nsg"]}-default${var.resource_suffixes["nsg"]}"), 0, local.name_limits["nsg"])
    web          = substr(try(var.custom_names["nsg_web"], "${var.resource_prefixes["nsg"]}-web${var.resource_suffixes["nsg"]}"), 0, local.name_limits["nsg"])
    app          = substr(try(var.custom_names["nsg_app"], "${var.resource_prefixes["nsg"]}-app${var.resource_suffixes["nsg"]}"), 0, local.name_limits["nsg"])
    data         = substr(try(var.custom_names["nsg_data"], "${var.resource_prefixes["nsg"]}-data${var.resource_suffixes["nsg"]}"), 0, local.name_limits["nsg"])
    management   = substr(try(var.custom_names["nsg_management"], "${var.resource_prefixes["nsg"]}-mgmt${var.resource_suffixes["nsg"]}"), 0, local.name_limits["nsg"])
  }
  
  route_table_name = substr(
    try(var.custom_names["route_table"], "${var.resource_prefixes["route_table"]}-${local.environment_code}-${local.location_code}${var.resource_suffixes["route_table"]}"),
    0,
    local.name_limits["route_table"]
  )
  
  load_balancer_name = substr(
    try(var.custom_names["load_balancer"], "${var.resource_prefixes["load_balancer"]}-${local.environment_code}-${local.location_code}${var.resource_suffixes["load_balancer"]}"),
    0,
    local.name_limits["load_balancer"]
  )
  
  application_gateway_name = substr(
    try(var.custom_names["application_gateway"], "${var.resource_prefixes["application_gateway"]}-${local.environment_code}-${local.location_code}${var.resource_suffixes["application_gateway"]}"),
    0,
    local.name_limits["application_gateway"]
  )
}

###############################################################################
# Security Resource Naming
###############################################################################
locals {
  key_vault_name = substr(
    replace(
      try(
        var.custom_names["key_vault"],
        local.random_code != "" ? 
          "${var.resource_prefixes["key_vault"]}-${local.project_code}-${local.environment_code}-${local.location_code}-${local.random_code}${var.resource_suffixes["key_vault"]}" :
          "${var.resource_prefixes["key_vault"]}-${local.project_code}-${local.environment_code}-${local.location_code}${var.resource_suffixes["key_vault"]}"
      ),
      "/[^a-zA-Z0-9-]/",
      ""
    ),
    0,
    local.name_limits["key_vault"]
  )
  
  managed_identity_name = substr(
    try(var.custom_names["managed_identity"], "${var.resource_prefixes["managed_identity"]}-${local.environment_code}-${local.location_code}${var.resource_suffixes["managed_identity"]}"),
    0,
    local.name_limits["managed_identity"]
  )
}

###############################################################################
# Monitoring Resource Naming
###############################################################################
locals {
  log_analytics_name = substr(
    try(var.custom_names["log_analytics"], "${var.resource_prefixes["log_analytics"]}-${local.project_code}-${local.environment_code}-${local.location_code}${var.resource_suffixes["log_analytics"]}"),
    0,
    local.name_limits["log_analytics"]
  )
  
  application_insights_name = substr(
    try(var.custom_names["application_insights"], "${var.resource_prefixes["application_insights"]}-${local.project_code}-${local.environment_code}-${local.location_code}${var.resource_suffixes["application_insights"]}"),
    0,
    local.name_limits["application_insights"]
  )
  
  action_group_name = substr(
    try(var.custom_names["action_group"], "${var.resource_prefixes["action_group"]}-${local.project_code}-${local.environment_code}${var.resource_suffixes["action_group"]}"),
    0,
    local.name_limits["action_group"]
  )
}
