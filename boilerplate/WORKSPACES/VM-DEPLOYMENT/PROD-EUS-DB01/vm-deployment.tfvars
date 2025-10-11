# Production Database Server VM Deployment
# SQL Server VMs for production environment

environment  = "prod"
location     = "eastus"
project_code = "vmaut"
workload_name = "db"

# VM Configuration
vm_count     = 2  # HA pair
vm_size      = "Standard_E8s_v3"  # Memory-optimized for database
os_type      = "Windows"
os_image = {
  publisher = "MicrosoftSQLServer"
  offer     = "sql2022-ws2022"
  sku       = "sqldev-gen2"
  version   = "latest"
}

# Disk Configuration
os_disk = {
  caching              = "ReadWrite"
  storage_account_type = "Premium_LRS"
  disk_size_gb         = 256
}

data_disks = [
  {
    name                 = "data-disk-01"
    caching              = "ReadOnly"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 1024  # 1TB for database files
    lun                  = 0
  },
  {
    name                 = "log-disk-01"
    caching              = "None"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 512  # 512GB for log files
    lun                  = 1
  },
  {
    name                 = "tempdb-disk-01"
    caching              = "ReadOnly"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 256  # 256GB for tempdb
    lun                  = 2
  }
]

# Network Configuration
# subnet_id = "/subscriptions/.../resourceGroups/.../providers/Microsoft.Network/virtualNetworks/.../subnets/snet-data"
enable_accelerated_networking = true
enable_public_ip = false

# Authentication
admin_username = "sqladmin"
# admin_password = ""  # Will be retrieved from Key Vault
disable_password_authentication = false  # Windows requires password

# High Availability
availability_zone = ["1", "2"]  # Deploy across availability zones
proximity_placement_group = true  # Minimize latency between VMs

# Load Balancer
enable_load_balancer = true
load_balancer_type = "internal"

# Monitoring
enable_boot_diagnostics = true
enable_monitoring = true
enable_sql_insights = true

# Backup
enable_backup = true
backup_policy = "Daily"
backup_retention_days = 30

# Security
enable_disk_encryption = true
enable_azure_defender = true

# Licensing
license_type = "PAYG"  # or "AHUB" for Azure Hybrid Benefit

# SQL Configuration
sql_connectivity_type = "PRIVATE"
sql_port = 1433
sql_license_type = "PAYG"

# Tags
tags = {
  Environment     = "Production"
  Tier            = "Data"
  Application     = "SQL Server"
  ManagedBy       = "Terraform"
  CostCenter      = "Operations"
  Owner           = "Database Team"
  Project         = "VM-Automation-Accelerator"
  Criticality     = "Critical"
  DataClassification = "Confidential"
  ComplianceScope = "PCI-DSS, SOC2"
  BackupPolicy    = "Daily"
  DisasterRecovery = "Yes"
  MaintenanceWindow = "Sunday 02:00-06:00 UTC"
  HAPair          = "Yes"
  ClusterRole     = "Primary"
}
