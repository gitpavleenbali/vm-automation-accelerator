/*
  Transform Layer - Workload Zone Input Normalization
  
  Purpose: Normalize network configuration inputs
  Pattern: SAP Automation Framework transform layer
*/

locals {
  # Environment Configuration
  environment = {
    name = lower(var.environment)
    code = lower(substr(var.environment, 0, 4))
    tags = {
      Environment = title(var.environment)
    }
  }

  # Location Configuration
  location = {
    name         = lower(var.location)
    display_name = title(var.location)
  }

  # Project Configuration
  project = {
    code        = lower(var.project_code)
    name        = "VM Automation"
    owner       = "Platform Team"
    cost_center = "IT-OPS"
  }

  # Workload Configuration
  workload = {
    name            = lower(var.workload_name)
    instance_number = var.instance_number
  }

  # Resource Group Configuration
  resource_group = {
    use_existing = var.resource_group_name != null && var.resource_group_name != ""
    name         = var.resource_group_name != null ? var.resource_group_name : ""
    location     = var.location
    tags = merge(
      local.common_tags,
      { Purpose = "Network Infrastructure" }
    )
  }

  # Virtual Network Configuration
  vnet = {
    address_space = var.vnet_address_space
    dns_servers   = var.dns_servers
    
    # DDoS protection
    enable_ddos_protection = var.enable_ddos_protection
    ddos_protection_plan_id = var.ddos_protection_plan_id
    
    tags = merge(
      local.common_tags,
      {
        Purpose     = "Virtual Network"
        Criticality = local.environment.name == "prod" ? "Critical" : "Medium"
      }
    )
  }

  # Subnet Configuration (normalized)
  subnets = {
    for name, config in var.subnets : name => {
      name                          = name
      address_prefix                = config.address_prefix
      service_endpoints             = config.service_endpoints != null ? config.service_endpoints : []
      delegation                    = config.delegation
      private_endpoint_network_policies_enabled = config.private_endpoint_network_policies_enabled
      private_link_service_network_policies_enabled = config.private_link_service_network_policies_enabled
    }
  }

  # NSG Configuration
  nsg = {
    enabled = var.enable_nsg
    rules   = var.nsg_rules
    
    # Default rules for common scenarios
    default_rules = {
      web = [
        {
          name                       = "AllowHTTP"
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "80"
          source_address_prefix      = "*"
          destination_address_prefix = "*"
        },
        {
          name                       = "AllowHTTPS"
          priority                   = 110
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "443"
          source_address_prefix      = "*"
          destination_address_prefix = "*"
        }
      ]
      app = [
        {
          name                       = "AllowAppPort"
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "8080"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "*"
        }
      ]
      data = [
        {
          name                       = "AllowSQL"
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "1433"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "*"
        }
      ]
    }
    
    tags = merge(
      local.common_tags,
      { Purpose = "Network Security" }
    )
  }

  # Route Table Configuration
  route_table = {
    enabled = var.enable_route_table
    routes  = var.routes
    
    tags = merge(
      local.common_tags,
      { Purpose = "Network Routing" }
    )
  }

  # VNet Peering Configuration
  peering = {
    enabled = var.enable_vnet_peering
    config  = var.peering_config
  }

  # Private DNS Configuration
  private_dns = {
    enabled = var.enable_private_dns_zones
    zones   = var.private_dns_zones
    
    tags = merge(
      local.common_tags,
      { Purpose = "Private DNS" }
    )
  }

  # Network Watcher Configuration
  network_watcher = {
    enabled               = var.enable_network_watcher
    enable_flow_logs      = var.enable_flow_logs
    flow_logs_retention   = var.flow_logs_retention_days
    
    tags = merge(
      local.common_tags,
      { Purpose = "Network Monitoring" }
    )
  }

  # Deployment Metadata
  deployment = {
    type              = "run-workload-zone"
    framework_version = var.automation_version
    deployed_by       = var.deployed_by != "" ? var.deployed_by : data.azurerm_client_config.current.object_id
    timestamp         = timestamp()
    id                = var.deployment_id != "" ? var.deployment_id : formatdate("YYYYMMDDhhmmss", timestamp())
  }

  # Common Tags
  common_tags = merge(
    {
      Environment     = local.environment.name
      Location        = local.location.display_name
      Project         = local.project.code
      Workload        = local.workload.name
      ManagedBy       = "Terraform"
      Framework       = "VM-Automation-Accelerator"
      Version         = local.deployment.framework_version
      DeploymentType  = local.deployment.type
      DeployedBy      = local.deployment.deployed_by
      CostCenter      = local.project.cost_center
      Owner           = local.project.owner
    },
    var.common_tags,
    var.tags
  )

  # Computed Values
  computed = {
    resource_group_id   = local.resource_group.use_existing ? data.azurerm_resource_group.existing[0].id : azurerm_resource_group.workload_zone[0].id
    create_ddos_plan    = local.vnet.enable_ddos_protection && local.vnet.ddos_protection_plan_id == null
    use_existing_ddos   = local.vnet.enable_ddos_protection && local.vnet.ddos_protection_plan_id != null
    create_arm_tracking = var.enable_arm_deployment_tracking
  }
}
