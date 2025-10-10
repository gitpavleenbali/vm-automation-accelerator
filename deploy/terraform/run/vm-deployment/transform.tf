/*
  Transform Layer - VM Deployment Input Normalization
  
  Purpose: Normalize VM configuration inputs
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
      { Purpose = "VM Workload" }
    )
  }

  # Linux VM Configuration (normalized)
  linux_vms = {
    for name, config in var.linux_vms : name => {
      name           = name
      size           = config.size
      zone           = config.zone
      admin_username = config.admin_username
      disable_password_auth = config.disable_password_auth
      ssh_public_key = config.ssh_public_key
      
      source_image = config.source_image_reference != null ? config.source_image_reference : {
        publisher = "Canonical"
        offer     = "0001-com-ubuntu-server-jammy"
        sku       = "22_04-lts-gen2"
        version   = "latest"
      }
      
      os_disk = {
        caching              = try(config.os_disk.caching, "ReadWrite")
        storage_account_type = try(config.os_disk.storage_account_type, "Premium_LRS")
        disk_size_gb         = try(config.os_disk.disk_size_gb, 128)
      }
      
      data_disks = config.data_disks
      
      enable_accelerated_networking = config.enable_accelerated_networking
      enable_boot_diagnostics      = config.enable_boot_diagnostics
      subnet_key                   = config.subnet_key
    }
  }

  # Windows VM Configuration (normalized)
  windows_vms = {
    for name, config in var.windows_vms : name => {
      name           = name
      size           = config.size
      zone           = config.zone
      admin_username = config.admin_username
      admin_password = config.admin_password
      license_type   = config.license_type
      
      source_image = config.source_image_reference != null ? config.source_image_reference : {
        publisher = "MicrosoftWindowsServer"
        offer     = "WindowsServer"
        sku       = "2022-Datacenter"
        version   = "latest"
      }
      
      os_disk = {
        caching              = try(config.os_disk.caching, "ReadWrite")
        storage_account_type = try(config.os_disk.storage_account_type, "Premium_LRS")
        disk_size_gb         = try(config.os_disk.disk_size_gb, 128)
      }
      
      data_disks = config.data_disks
      
      enable_accelerated_networking = config.enable_accelerated_networking
      enable_boot_diagnostics      = config.enable_boot_diagnostics
      subnet_key                   = config.subnet_key
    }
  }

  # All VMs combined
  all_vms = merge(
    { for k, v in local.linux_vms : k => merge(v, { os_type = "Linux" }) },
    { for k, v in local.windows_vms : k => merge(v, { os_type = "Windows" }) }
  )

  # Availability Configuration
  availability = {
    enable_availability_set           = var.enable_availability_set
    enable_proximity_placement_group  = var.enable_proximity_placement_group
    
    availability_set = var.enable_availability_set ? {
      platform_fault_domain_count  = var.availability_set_config.platform_fault_domain_count
      platform_update_domain_count = var.availability_set_config.platform_update_domain_count
      managed                      = var.availability_set_config.managed
    } : null
    
    tags = merge(
      local.common_tags,
      { Purpose = "High Availability" }
    )
  }

  # Load Balancer Configuration
  load_balancer = {
    enabled = var.enable_load_balancer
    config  = var.load_balancer_config
    
    tags = merge(
      local.common_tags,
      { Purpose = "Load Balancing" }
    )
  }

  # Public IP Configuration
  public_ip = {
    enabled = var.enable_public_ips
    sku     = var.public_ip_sku
    
    tags = merge(
      local.common_tags,
      { Purpose = "Public Access" }
    )
  }

  # Backup Configuration
  backup = {
    enabled = var.enable_backup
    policy  = var.backup_policy_config
    
    tags = merge(
      local.common_tags,
      { Purpose = "Data Protection" }
    )
  }

  # Disk Encryption Configuration
  disk_encryption = {
    enabled       = var.enable_disk_encryption
    key_vault_id  = var.disk_encryption_key_vault_id
  }

  # Monitoring Configuration
  monitoring = {
    enabled                   = var.enable_monitoring
    log_analytics_workspace_id = var.log_analytics_workspace_id
    enable_azure_defender     = var.enable_azure_defender
    
    tags = merge(
      local.common_tags,
      { Purpose = "Monitoring & Security" }
    )
  }

  # Network Configuration
  network = {
    enable_private_ip_allocation = var.enable_private_ip_allocation
    private_ip_addresses        = var.private_ip_addresses
  }

  # Deployment Metadata
  deployment = {
    type              = "run-vm-deployment"
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
    resource_group_id          = local.resource_group.use_existing ? data.azurerm_resource_group.existing[0].id : azurerm_resource_group.vm_deployment[0].id
    linux_vm_count             = length(local.linux_vms)
    windows_vm_count           = length(local.windows_vms)
    total_vm_count             = length(local.all_vms)
    create_availability_set    = local.availability.enable_availability_set && local.computed.total_vm_count > 1
    create_proximity_group     = local.availability.enable_proximity_placement_group && local.computed.total_vm_count > 1
    create_load_balancer       = local.load_balancer.enabled && local.load_balancer.config != null
    create_backup              = local.backup.enabled
    create_arm_tracking        = var.enable_arm_deployment_tracking
  }
}
