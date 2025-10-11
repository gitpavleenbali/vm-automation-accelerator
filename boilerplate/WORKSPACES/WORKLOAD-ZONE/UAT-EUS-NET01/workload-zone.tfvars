# UAT Workload Zone Configuration
# Network infrastructure for UAT environment

environment  = "uat"
location     = "eastus"
project_code = "vmaut"
workload_name = "uat"

# Virtual Network
vnet_address_space = ["10.2.0.0/16"]

# Subnets
subnets = {
  web = {
    name                 = "snet-web"
    address_prefix       = "10.2.1.0/24"
    service_endpoints    = ["Microsoft.Storage", "Microsoft.KeyVault"]
  }
  app = {
    name                 = "snet-app"
    address_prefix       = "10.2.2.0/24"
    service_endpoints    = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.Sql"]
  }
  data = {
    name                 = "snet-data"
    address_prefix       = "10.2.3.0/24"
    service_endpoints    = ["Microsoft.Storage", "Microsoft.Sql"]
  }
  management = {
    name                 = "snet-management"
    address_prefix       = "10.2.10.0/24"
    service_endpoints    = []
  }
}

# Network Security Groups
create_nsgs = true

# DNS
dns_servers = []

# Tags
tags = {
  Environment     = "UAT"
  Purpose         = "Workload Zone"
  ManagedBy       = "Terraform"
  CostCenter      = "QA"
  Owner           = "QA Team"
  Project         = "VM-Automation-Accelerator"
  Criticality     = "Medium"
  DataClassification = "Internal"
}
