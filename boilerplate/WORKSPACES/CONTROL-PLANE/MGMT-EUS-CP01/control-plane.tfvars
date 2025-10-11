# Control Plane Configuration
# Management infrastructure for VM automation deployments
# Bootstrap deployment with local state backend

environment  = "mgmt"
location     = "eastus"
project_code = "vmaut"

# Resource Group
create_resource_group = true
# resource_group_name = ""  # Leave empty for auto-generation

# Terraform State Storage
tfstate_storage_account_tier      = "Standard"
tfstate_storage_replication_type  = "LRS"
tfstate_container_name            = "tfstate"

# Key Vault Configuration
create_key_vault               = true
key_vault_sku                  = "standard"
enable_purge_protection        = true
enable_soft_delete             = true
soft_delete_retention_days     = 7

# Network Security
# allowed_ip_ranges = ["YOUR_IP/32"]  # Uncomment and add your IP for Key Vault firewall

# Tags
tags = {
  Environment     = "Management"
  Purpose         = "Control Plane"
  ManagedBy       = "Terraform"
  CostCenter      = "IT-Operations"
  Owner           = "Platform Team"
  Project         = "VM-Automation-Accelerator"
  Criticality     = "High"
  BackupPolicy    = "Daily"
  MaintenanceWindow = "Sunday 02:00-06:00 UTC"
}

# Optional: Provide custom random ID for consistent naming across re-deployments
# random_id = "a1b2c3d4"
