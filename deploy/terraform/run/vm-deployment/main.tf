###############################################################################
# Run VM Deployment - Main Configuration
# Virtual machine deployment with remote state backend
###############################################################################

terraform {
  required_version = ">= 1.5.0"
  
  # Remote backend configuration (parameters provided via backend-config)
  backend "azurerm" {
    # Configuration provided via:
    # terraform init \
    #   -backend-config="subscription_id=xxx" \
    #   -backend-config="resource_group_name=xxx" \
    #   -backend-config="storage_account_name=xxx" \
    #   -backend-config="container_name=tfstate" \
    #   -backend-config="key=vm-deployment-{env}-{workload}.tfstate" \
    #   -backend-config="use_azuread_auth=true"
    use_azuread_auth = true
  }
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.10"
    }
  }
}

# Main provider for VM resources
provider "azurerm" {
  alias = "main"
  storage_use_azuread = true
  
  # Use Service Principal authentication when ARM_CLIENT_ID is set (for pipelines)
  # Use Azure CLI authentication when ARM_CLIENT_ID is not set (for local dev)
  use_cli = var.arm_client_id == "" ? true : false
  
  # Service Principal configuration (used when ARM environment variables are set)
  client_id       = var.arm_client_id != "" ? var.arm_client_id : null
  client_secret   = var.arm_client_secret != "" ? var.arm_client_secret : null
  tenant_id       = var.arm_tenant_id != "" ? var.arm_tenant_id : null
  subscription_id = var.arm_subscription_id != "" ? var.arm_subscription_id : var.control_plane_subscription_id
  
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    virtual_machine {
      delete_os_disk_on_deletion     = true
      skip_shutdown_and_force_delete = false
    }
  }
}

# Default provider (aliases to main)
provider "azurerm" {
  storage_use_azuread = true
  
  # Use Service Principal authentication when ARM_CLIENT_ID is set (for pipelines)
  # Use Azure CLI authentication when ARM_CLIENT_ID is not set (for local dev)
  use_cli = var.arm_client_id == "" ? true : false
  
  # Service Principal configuration (used when ARM environment variables are set)
  client_id       = var.arm_client_id != "" ? var.arm_client_id : null
  client_secret   = var.arm_client_secret != "" ? var.arm_client_secret : null
  tenant_id       = var.arm_tenant_id != "" ? var.arm_tenant_id : null
  subscription_id = var.arm_subscription_id != "" ? var.arm_subscription_id : var.control_plane_subscription_id
  
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    virtual_machine {
      delete_os_disk_on_deletion     = true
      skip_shutdown_and_force_delete = false
    }
  }
}

# AzAPI provider for advanced features
provider "azapi" {
  # Service Principal configuration (used when ARM environment variables are set)
  client_id       = var.arm_client_id != "" ? var.arm_client_id : null
  client_secret   = var.arm_client_secret != "" ? var.arm_client_secret : null
  tenant_id       = var.arm_tenant_id != "" ? var.arm_tenant_id : null
  subscription_id = var.arm_subscription_id != "" ? var.arm_subscription_id : var.control_plane_subscription_id
  
  use_cli = var.arm_client_id == "" ? true : false
}

# Random provider
provider "random" {}

# ============================================================================
# Naming Module
# ============================================================================

module "naming" {
  source = "../../terraform-units/modules/naming"
  
  environment      = local.environment.name
  location         = local.location.name
  project_code     = local.project.code
  workload_name    = local.workload.name
  instance_number  = local.workload.instance_number
  
  resource_prefixes = {
    # Compute
    vm                    = "vm"
    vmss                  = "vmss"
    nic                   = "nic"
    pip                   = "pip"
    
    # Storage
    storage_account       = "st"
    disk                  = "disk"
    
    # Networking
    vnet                  = "vnet"
    subnet                = "snet"
    nsg                   = "nsg"
    route_table           = "rt"
    load_balancer         = "lb"
    application_gateway   = "agw"
    
    # Security
    key_vault             = "kv"
    managed_identity      = "id"
    
    # Monitoring
    log_analytics         = "log"
    application_insights  = "appi"
    action_group          = "ag"
    
    # Resource Group
    resource_group        = "rg"
    
    # VM-specific (legacy compatibility)
    avset                 = "avset"
    ppg                   = "ppg"
  }
  
  resource_suffixes = {
    vm                    = ""
    vmss                  = ""
    nic                   = ""
    pip                   = ""
    storage_account       = ""
    disk                  = ""
    vnet                  = ""
    subnet                = ""
    nsg                   = ""
    route_table           = ""
    load_balancer         = ""
    application_gateway   = ""
    key_vault             = ""
    managed_identity      = ""
    log_analytics         = ""
    application_insights  = ""
    action_group          = ""
    resource_group        = ""
    avset                 = ""
    ppg                   = ""
  }
}

# ============================================================================
# Resource Group
# ============================================================================

resource "azurerm_resource_group" "vm_deployment" {
  count    = local.resource_group.use_existing ? 0 : 1
  provider = azurerm.main
  
  name     = coalesce(local.resource_group.name, module.naming.resource_group_names["compute"])
  location = local.resource_group.location
  tags     = local.resource_group.tags
}

locals {
  resource_group_name = local.resource_group.use_existing ? (
    data.azurerm_resource_group.existing[0].name
  ) : (
    azurerm_resource_group.vm_deployment[0].name
  )
  
  resource_group_location = local.resource_group.use_existing ? (
    data.azurerm_resource_group.existing[0].location
  ) : (
    azurerm_resource_group.vm_deployment[0].location
  )
}

# ============================================================================
# Proximity Placement Group (Optional)
# ============================================================================

resource "azurerm_proximity_placement_group" "vm_deployment" {
  count               = local.computed.create_proximity_group ? 1 : 0
  provider            = azurerm.main
  
  name                = "${module.naming.resource_group_names["compute"]}-ppg"
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  
  tags = local.availability.tags
  
  depends_on = [azurerm_resource_group.vm_deployment]
}

# ============================================================================
# Availability Set (Optional)
# ============================================================================

resource "azurerm_availability_set" "vm_deployment" {
  count                        = local.computed.create_availability_set ? 1 : 0
  provider                     = azurerm.main
  
  name                         = "${module.naming.resource_group_names["compute"]}-avset"
  resource_group_name          = local.resource_group_name
  location                     = local.resource_group_location
  platform_fault_domain_count  = local.availability.availability_set.platform_fault_domain_count
  platform_update_domain_count = local.availability.availability_set.platform_update_domain_count
  managed                      = local.availability.availability_set.managed
  proximity_placement_group_id = local.computed.create_proximity_group ? azurerm_proximity_placement_group.vm_deployment[0].id : null
  
  tags = local.availability.tags
  
  depends_on = [
    azurerm_resource_group.vm_deployment,
    azurerm_proximity_placement_group.vm_deployment
  ]
}

# ============================================================================
# Public IPs (Optional)
# ============================================================================

resource "azurerm_public_ip" "linux_vms" {
  for_each = local.public_ip.enabled ? local.linux_vms : {}
  provider = azurerm.main
  
  name                = "${module.naming.vm_names["linux"][0]}-${each.key}-pip"
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  allocation_method   = local.public_ip.sku == "Standard" ? "Static" : "Dynamic"
  sku                 = local.public_ip.sku
  zones               = each.value.zone != null ? [each.value.zone] : null
  
  tags = local.public_ip.tags
  
  depends_on = [azurerm_resource_group.vm_deployment]
}

resource "azurerm_public_ip" "windows_vms" {
  for_each = local.public_ip.enabled ? local.windows_vms : {}
  provider = azurerm.main
  
  name                = "${module.naming.vm_names["windows"][0]}-${each.key}-pip"
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  allocation_method   = local.public_ip.sku == "Standard" ? "Static" : "Dynamic"
  sku                 = local.public_ip.sku
  zones               = each.value.zone != null ? [each.value.zone] : null
  
  tags = local.public_ip.tags
  
  depends_on = [azurerm_resource_group.vm_deployment]
}

# ============================================================================
# Network Interfaces - Linux VMs
# ============================================================================

resource "azurerm_network_interface" "linux_vms" {
  for_each = local.linux_vms
  provider = azurerm.main
  
  name                             = "${module.naming.vm_names["linux"][0]}-${each.key}-nic"
  resource_group_name              = local.resource_group_name
  location                         = local.resource_group_location
  accelerated_networking_enabled   = each.value.enable_accelerated_networking
  
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = local.subnet_id_map[each.value.subnet_key]
    private_ip_address_allocation = local.network.enable_private_ip_allocation && contains(keys(local.network.private_ip_addresses), each.key) ? "Static" : "Dynamic"
    private_ip_address            = local.network.enable_private_ip_allocation && contains(keys(local.network.private_ip_addresses), each.key) ? local.network.private_ip_addresses[each.key] : null
    public_ip_address_id          = local.public_ip.enabled ? azurerm_public_ip.linux_vms[each.key].id : null
  }
  
  tags = merge(
    local.common_tags,
    { VMName = each.key, OSType = "Linux" }
  )
  
  depends_on = [
    azurerm_resource_group.vm_deployment,
    azurerm_public_ip.linux_vms
  ]
}

# ============================================================================
# Network Interfaces - Windows VMs
# ============================================================================

resource "azurerm_network_interface" "windows_vms" {
  for_each = local.windows_vms
  provider = azurerm.main
  
  name                             = "${module.naming.vm_names["windows"][0]}-${each.key}-nic"
  resource_group_name              = local.resource_group_name
  location                         = local.resource_group_location
  accelerated_networking_enabled   = each.value.enable_accelerated_networking
  
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = local.subnet_id_map[each.value.subnet_key]
    private_ip_address_allocation = local.network.enable_private_ip_allocation && contains(keys(local.network.private_ip_addresses), each.key) ? "Static" : "Dynamic"
    private_ip_address            = local.network.enable_private_ip_allocation && contains(keys(local.network.private_ip_addresses), each.key) ? local.network.private_ip_addresses[each.key] : null
    public_ip_address_id          = local.public_ip.enabled ? azurerm_public_ip.windows_vms[each.key].id : null
  }
  
  tags = merge(
    local.common_tags,
    { VMName = each.key, OSType = "Windows" }
  )
  
  depends_on = [
    azurerm_resource_group.vm_deployment,
    azurerm_public_ip.windows_vms
  ]
}

# ============================================================================
# Linux Virtual Machines
# ============================================================================

resource "azurerm_linux_virtual_machine" "vms" {
  for_each = local.linux_vms
  provider = azurerm.main
  
  name                = "${module.naming.vm_names["linux"][0]}-${each.key}"
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  size                = each.value.size
  zone                = each.value.zone
  
  admin_username                  = each.value.admin_username
  admin_password                  = each.value.disable_password_auth ? null : each.value.admin_password
  disable_password_authentication = each.value.disable_password_auth
  
  network_interface_ids = [
    azurerm_network_interface.linux_vms[each.key].id
  ]
  
  availability_set_id          = local.computed.create_availability_set && each.value.zone == null ? azurerm_availability_set.vm_deployment[0].id : null
  proximity_placement_group_id = local.computed.create_proximity_group ? azurerm_proximity_placement_group.vm_deployment[0].id : null
  
  # SSH Key (if provided)
  dynamic "admin_ssh_key" {
    for_each = each.value.ssh_public_key != null ? [each.value.ssh_public_key] : []
    content {
      username   = each.value.admin_username
      public_key = admin_ssh_key.value
    }
  }
  
  # OS Disk
  os_disk {
    name                 = "${module.naming.vm_names["linux"][0]}-${each.key}-osdisk"
    caching              = each.value.os_disk.caching
    storage_account_type = each.value.os_disk.storage_account_type
    disk_size_gb         = each.value.os_disk.disk_size_gb
  }
  
  # Source Image
  source_image_reference {
    publisher = each.value.source_image.publisher
    offer     = each.value.source_image.offer
    sku       = each.value.source_image.sku
    version   = each.value.source_image.version
  }
  
  # Boot Diagnostics
  dynamic "boot_diagnostics" {
    for_each = each.value.enable_boot_diagnostics ? [1] : []
    content {
      storage_account_uri = null # Use managed storage account
    }
  }

  # Managed Identity for Azure AD authentication
  identity {
    type = "SystemAssigned"
  }
  
  tags = merge(
    local.common_tags,
    {
      VMName  = each.key
      OSType  = "Linux"
      Size    = each.value.size
      Zone    = each.value.zone != null ? each.value.zone : "None"
    }
  )
  
  depends_on = [
    azurerm_network_interface.linux_vms,
    azurerm_availability_set.vm_deployment,
    azurerm_proximity_placement_group.vm_deployment
  ]
}

# ============================================================================
# Windows Virtual Machines
# ============================================================================

resource "azurerm_windows_virtual_machine" "vms" {
  for_each = local.windows_vms
  provider = azurerm.main
  
  name                = "${module.naming.vm_names["windows"][0]}-${each.key}"
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  size                = each.value.size
  zone                = each.value.zone
  computer_name       = substr("${each.key}", 0, 15)  # Limit to 15 chars for Windows
  
  admin_username = each.value.admin_username
  admin_password = each.value.admin_password
  license_type   = each.value.license_type
  
  network_interface_ids = [
    azurerm_network_interface.windows_vms[each.key].id
  ]
  
  availability_set_id          = local.computed.create_availability_set && each.value.zone == null ? azurerm_availability_set.vm_deployment[0].id : null
  proximity_placement_group_id = local.computed.create_proximity_group ? azurerm_proximity_placement_group.vm_deployment[0].id : null
  
  # OS Disk
  os_disk {
    name                 = "${module.naming.vm_names["windows"][0]}-${each.key}-osdisk"
    caching              = each.value.os_disk.caching
    storage_account_type = each.value.os_disk.storage_account_type
    disk_size_gb         = each.value.os_disk.disk_size_gb
  }
  
  # Source Image
  source_image_reference {
    publisher = each.value.source_image.publisher
    offer     = each.value.source_image.offer
    sku       = each.value.source_image.sku
    version   = each.value.source_image.version
  }
  
  # Boot Diagnostics
  dynamic "boot_diagnostics" {
    for_each = each.value.enable_boot_diagnostics ? [1] : []
    content {
      storage_account_uri = null # Use managed storage account
    }
  }

  # Managed Identity for Azure AD authentication
  identity {
    type = "SystemAssigned"
  }
  
  tags = merge(
    local.common_tags,
    {
      VMName  = each.key
      OSType  = "Windows"
      Size    = each.value.size
      Zone    = each.value.zone != null ? each.value.zone : "None"
    }
  )
  
  depends_on = [
    azurerm_network_interface.windows_vms,
    azurerm_availability_set.vm_deployment,
    azurerm_proximity_placement_group.vm_deployment
  ]
}

# ============================================================================
# Data Disks - Linux VMs
# ============================================================================

resource "azurerm_managed_disk" "linux_data_disks" {
  for_each = {
    for disk in flatten([
      for vm_name, vm_config in local.linux_vms : [
        for data_disk in vm_config.data_disks : {
          key                  = "${vm_name}-${data_disk.name}"
          vm_name              = vm_name
          name                 = data_disk.name
          disk_size_gb         = data_disk.disk_size_gb
          storage_account_type = data_disk.storage_account_type
          zone                 = vm_config.zone
        }
      ]
    ]) : disk.key => disk
  }
  
  provider = azurerm.main
  
  name                 = "${module.naming.vm_names["linux"][0]}-${each.value.key}"
  resource_group_name  = local.resource_group_name
  location             = local.resource_group_location
  storage_account_type = each.value.storage_account_type
  create_option        = "Empty"
  disk_size_gb         = each.value.disk_size_gb
  zone                 = each.value.zone
  
  tags = merge(
    local.common_tags,
    {
      VMName   = each.value.vm_name
      DiskName = each.value.name
      OSType   = "Linux"
    }
  )
  
  depends_on = [azurerm_resource_group.vm_deployment]
}

resource "azurerm_virtual_machine_data_disk_attachment" "linux_data_disks" {
  for_each = {
    for disk in flatten([
      for vm_name, vm_config in local.linux_vms : [
        for data_disk in vm_config.data_disks : {
          key        = "${vm_name}-${data_disk.name}"
          vm_name    = vm_name
          lun        = data_disk.lun
          caching    = data_disk.caching
        }
      ]
    ]) : disk.key => disk
  }
  
  provider = azurerm.main
  
  managed_disk_id    = azurerm_managed_disk.linux_data_disks[each.key].id
  virtual_machine_id = azurerm_linux_virtual_machine.vms[each.value.vm_name].id
  lun                = each.value.lun
  caching            = each.value.caching
  
  depends_on = [
    azurerm_linux_virtual_machine.vms,
    azurerm_managed_disk.linux_data_disks
  ]
}

# ============================================================================
# Data Disks - Windows VMs
# ============================================================================

resource "azurerm_managed_disk" "windows_data_disks" {
  for_each = {
    for disk in flatten([
      for vm_name, vm_config in local.windows_vms : [
        for data_disk in vm_config.data_disks : {
          key                  = "${vm_name}-${data_disk.name}"
          vm_name              = vm_name
          name                 = data_disk.name
          disk_size_gb         = data_disk.disk_size_gb
          storage_account_type = data_disk.storage_account_type
          zone                 = vm_config.zone
        }
      ]
    ]) : disk.key => disk
  }
  
  provider = azurerm.main
  
  name                 = "${module.naming.vm_names["windows"][0]}-${each.value.key}"
  resource_group_name  = local.resource_group_name
  location             = local.resource_group_location
  storage_account_type = each.value.storage_account_type
  create_option        = "Empty"
  disk_size_gb         = each.value.disk_size_gb
  zone                 = each.value.zone
  
  tags = merge(
    local.common_tags,
    {
      VMName   = each.value.vm_name
      DiskName = each.value.name
      OSType   = "Windows"
    }
  )
  
  depends_on = [azurerm_resource_group.vm_deployment]
}

resource "azurerm_virtual_machine_data_disk_attachment" "windows_data_disks" {
  for_each = {
    for disk in flatten([
      for vm_name, vm_config in local.windows_vms : [
        for data_disk in vm_config.data_disks : {
          key        = "${vm_name}-${data_disk.name}"
          vm_name    = vm_name
          lun        = data_disk.lun
          caching    = data_disk.caching
        }
      ]
    ]) : disk.key => disk
  }
  
  provider = azurerm.main
  
  managed_disk_id    = azurerm_managed_disk.windows_data_disks[each.key].id
  virtual_machine_id = azurerm_windows_virtual_machine.vms[each.value.vm_name].id
  lun                = each.value.lun
  caching            = each.value.caching
  
  depends_on = [
    azurerm_windows_virtual_machine.vms,
    azurerm_managed_disk.windows_data_disks
  ]
}

# ============================================================================
# ARM Deployment Tracking (for Azure Portal visibility)
# ============================================================================

resource "azurerm_resource_group_template_deployment" "vm_deployment" {
  count               = local.computed.create_arm_tracking ? 1 : 0
  provider            = azurerm.main
  
  name                = "vm-automation-vm-deployment-${local.deployment.id}"
  resource_group_name = local.resource_group_name
  deployment_mode     = "Incremental"
  
  template_content = jsonencode({
    "$schema"      = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
    contentVersion = "1.0.0.0"
    resources      = []
    outputs = {
      deploymentType = {
        type  = "string"
        value = local.deployment.type
      }
      frameworkVersion = {
        type  = "string"
        value = local.deployment.framework_version
      }
      linuxVMCount = {
        type  = "int"
        value = local.computed.linux_vm_count
      }
      windowsVMCount = {
        type  = "int"
        value = local.computed.windows_vm_count
      }
      totalVMCount = {
        type  = "int"
        value = local.computed.total_vm_count
      }
    }
  })
  
  tags = merge(
    local.common_tags,
    {
      DeploymentTracking = "ARM"
    }
  )
  
  depends_on = [
    azurerm_linux_virtual_machine.vms,
    azurerm_windows_virtual_machine.vms
  ]
}
