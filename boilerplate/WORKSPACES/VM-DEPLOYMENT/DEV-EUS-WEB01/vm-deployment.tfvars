# Development Web Server VM Deployment
# Linux web servers for development environment

environment  = "dev"
location     = "eastus"
project_code = "vmaut"
workload_name = "web"

# VM Configuration
vm_count     = 2
vm_size      = "Standard_D2s_v3"
os_type      = "Linux"
os_image = {
  publisher = "Canonical"
  offer     = "0001-com-ubuntu-server-jammy"
  sku       = "22_04-lts-gen2"
  version   = "latest"
}

# Disk Configuration
os_disk = {
  caching              = "ReadWrite"
  storage_account_type = "Premium_LRS"
  disk_size_gb         = 128
}

data_disks = [
  {
    name                 = "data-disk-01"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 256
    lun                  = 0
  }
]

# Network Configuration
# subnet_id = "/subscriptions/.../resourceGroups/.../providers/Microsoft.Network/virtualNetworks/.../subnets/snet-web"
enable_accelerated_networking = true
enable_public_ip = false

# Authentication
admin_username = "azureuser"
# admin_password = ""  # Leave empty to use SSH key from Key Vault
disable_password_authentication = true

# High Availability
availability_zone = ["1", "2"]  # Deploy VMs across zones 1 and 2

# Monitoring
enable_boot_diagnostics = true
enable_monitoring = true

# Backup
enable_backup = false  # Set to true for production

# Tags
tags = {
  Environment     = "Development"
  Tier            = "Web"
  Application     = "WebServer"
  ManagedBy       = "Terraform"
  CostCenter      = "Development"
  Owner           = "Dev Team"
  Project         = "VM-Automation-Accelerator"
  Criticality     = "Low"
  BackupPolicy    = "None"
}
