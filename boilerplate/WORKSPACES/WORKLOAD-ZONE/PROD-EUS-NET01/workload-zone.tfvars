# Production Workload Zone Configuration
# Network infrastructure for production environment

environment  = "prod"
location     = "eastus"
project_code = "vmaut"
workload_name = "production"

# Virtual Network
vnet_address_space = ["10.0.0.0/16"]

# Subnets
subnets = {
  web = {
    name                 = "snet-web"
    address_prefix       = "10.0.1.0/24"
    service_endpoints    = ["Microsoft.Storage", "Microsoft.KeyVault"]
  }
  app = {
    name                 = "snet-app"
    address_prefix       = "10.0.2.0/24"
    service_endpoints    = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.Sql"]
  }
  data = {
    name                 = "snet-data"
    address_prefix       = "10.0.3.0/24"
    service_endpoints    = ["Microsoft.Storage", "Microsoft.Sql"]
  }
  management = {
    name                 = "snet-management"
    address_prefix       = "10.0.10.0/24"
    service_endpoints    = []
  }
  gateway = {
    name                 = "GatewaySubnet"
    address_prefix       = "10.0.255.0/24"
    service_endpoints    = []
  }
}

# Network Security Groups
create_nsgs = true

# DNS
dns_servers = []  # Consider custom DNS for production

# High Availability
enable_ddos_protection = true  # Enable DDoS protection for production

# Peering (optional)
# enable_vnet_peering = true
# hub_vnet_id = "/subscriptions/.../resourceGroups/.../providers/Microsoft.Network/virtualNetworks/hub-vnet"

# Tags
tags = {
  Environment     = "Production"
  Purpose         = "Workload Zone"
  ManagedBy       = "Terraform"
  CostCenter      = "Operations"
  Owner           = "Platform Team"
  Project         = "VM-Automation-Accelerator"
  Criticality     = "Critical"
  DataClassification = "Confidential"
  ComplianceScope = "PCI-DSS, SOC2"
  BackupPolicy    = "Hourly"
  DisasterRecovery = "Yes"
  MaintenanceWindow = "Sunday 02:00-04:00 UTC"
}
