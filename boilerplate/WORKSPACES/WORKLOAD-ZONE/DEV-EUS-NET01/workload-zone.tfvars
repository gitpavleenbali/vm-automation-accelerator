# Development Workload Zone Configuration
# Network infrastructure for development environment

environment  = "dev"
location     = "eastus"
project_code = "vmaut"
workload_name = "development"

# Virtual Network
vnet_address_space = ["10.1.0.0/16"]

# Subnets
subnets = {
  web = {
    name                 = "snet-web"
    address_prefix       = "10.1.1.0/24"
    service_endpoints    = ["Microsoft.Storage", "Microsoft.KeyVault"]
  }
  app = {
    name                 = "snet-app"
    address_prefix       = "10.1.2.0/24"
    service_endpoints    = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.Sql"]
  }
  data = {
    name                 = "snet-data"
    address_prefix       = "10.1.3.0/24"
    service_endpoints    = ["Microsoft.Storage", "Microsoft.Sql"]
  }
  management = {
    name                 = "snet-management"
    address_prefix       = "10.1.10.0/24"
    service_endpoints    = []
  }
}

# Network Security Groups
create_nsgs = true

# DNS
dns_servers = []  # Leave empty for Azure-provided DNS

# Peering (optional)
# enable_vnet_peering = false
# hub_vnet_id = "/subscriptions/.../resourceGroups/.../providers/Microsoft.Network/virtualNetworks/..."

# Tags
tags = {
  Environment     = "Development"
  Purpose         = "Workload Zone"
  ManagedBy       = "Terraform"
  CostCenter      = "Development"
  Owner           = "Dev Team"
  Project         = "VM-Automation-Accelerator"
  Criticality     = "Low"
  DataClassification = "Internal"
}
