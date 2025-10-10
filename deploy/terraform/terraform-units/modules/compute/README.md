# Reusable Compute Module

This module provides reusable patterns for deploying Azure Virtual Machines with comprehensive configuration options.

## Features

- ✅ **Multi-OS Support** - Linux and Windows VMs in a single module
- ✅ **Flexible Authentication** - SSH keys for Linux, passwords for Windows
- ✅ **High Availability** - Availability sets and proximity placement groups
- ✅ **Data Disks** - Multiple data disks per VM with custom configuration
- ✅ **Networking** - Static/dynamic IPs, public IPs, accelerated networking
- ✅ **Smart Defaults** - Sensible defaults for common configurations
- ✅ **Transform Layer** - Input normalization for flexible usage

## Usage

### Basic Linux VM

```hcl
module "web_vms" {
  source = "../../terraform-units/modules/compute"
  
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  vms = {
    web01 = {
      vm_name        = "vm-web01"
      os_type        = "linux"
      vm_size        = "Standard_D2s_v3"
      subnet_id      = azurerm_subnet.web.id
      admin_username = "azureuser"
      ssh_public_key = file("~/.ssh/id_rsa.pub")
    }
  }
  
  tags = {
    environment = "dev"
    project     = "webapp"
  }
}
```

### Windows VM with Data Disks

```hcl
module "app_vms" {
  source = "../../terraform-units/modules/compute"
  
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  vms = {
    app01 = {
      vm_name        = "vm-app01"
      os_type        = "windows"
      vm_size        = "Standard_D4s_v3"
      subnet_id      = azurerm_subnet.app.id
      admin_username = "azureadmin"
      admin_password = "P@ssw0rd123!"
      enable_public_ip = true
      
      data_disks = {
        data01 = {
          size_gb = 256
          type    = "Premium_LRS"
          caching = "ReadWrite"
        }
        data02 = {
          size_gb = 512
          type    = "Premium_LRS"
          caching = "ReadOnly"
        }
      }
    }
  }
}
```

### High Availability Cluster

```hcl
module "db_cluster" {
  source = "../../terraform-units/modules/compute"
  
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  vms = {
    db01 = {
      vm_name               = "vm-db01"
      os_type               = "linux"
      vm_size               = "Standard_E8s_v3"
      subnet_id             = azurerm_subnet.db.id
      admin_username        = "azureuser"
      ssh_public_key        = file("~/.ssh/id_rsa.pub")
      availability_set_name = "avset-db"
      proximity_placement_group_name = "ppg-db"
      
      data_disks = {
        data = { size_gb = 1024, type = "Premium_LRS" }
        log  = { size_gb = 512,  type = "Premium_LRS" }
      }
    }
    db02 = {
      vm_name               = "vm-db02"
      os_type               = "linux"
      vm_size               = "Standard_E8s_v3"
      subnet_id             = azurerm_subnet.db.id
      admin_username        = "azureuser"
      ssh_public_key        = file("~/.ssh/id_rsa.pub")
      availability_set_name = "avset-db"
      proximity_placement_group_name = "ppg-db"
      
      data_disks = {
        data = { size_gb = 1024, type = "Premium_LRS" }
        log  = { size_gb = 512,  type = "Premium_LRS" }
      }
    }
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| resource_group_name | Resource group name | `string` | n/a | yes |
| location | Azure region | `string` | n/a | yes |
| vms | Map of VM configurations | `map(object)` | n/a | yes |
| tags | Common tags for all resources | `map(string)` | `{}` | no |
| availability_set_fault_domains | Fault domains for avsets | `number` | `2` | no |
| availability_set_update_domains | Update domains for avsets | `number` | `5` | no |

### VM Configuration Object

Each VM in the `vms` map can have:

| Property | Description | Type | Default |
|----------|-------------|------|---------|
| vm_name | VM name | `string` | **required** |
| subnet_id | Subnet ID | `string` | **required** |
| os_type | OS type (linux/windows) | `string` | `"linux"` |
| vm_size | Azure VM size | `string` | `"Standard_D2s_v3"` |
| admin_username | Admin username | `string` | `"azureuser"` (Linux) / `"azureadmin"` (Windows) |
| admin_password | Admin password | `string` | `null` |
| ssh_public_key | SSH public key (Linux only) | `string` | `null` |
| enable_public_ip | Enable public IP | `bool` | `false` |
| enable_accelerated_networking | Enable accelerated networking | `bool` | `true` |
| private_ip_address | Static private IP | `string` | `null` (dynamic) |
| os_disk_size_gb | OS disk size in GB | `number` | `128` |
| os_disk_type | OS disk type | `string` | `"Premium_LRS"` |
| os_disk_caching | OS disk caching | `string` | `"ReadWrite"` |
| data_disks | Map of data disks | `map(object)` | `{}` |
| availability_set_name | Availability set name | `string` | `null` |
| proximity_placement_group_name | PPG name | `string` | `null` |
| zone | Availability zone | `string` | `null` |
| source_image_reference | Custom image | `object` | Ubuntu 22.04 / Win Server 2022 |
| tags | VM-specific tags | `map(string)` | `{}` |

### Data Disk Configuration

Each data disk can have:

| Property | Description | Type | Default |
|----------|-------------|------|---------|
| name | Disk name | `string` | `"{vm_name}-disk-{key}"` |
| size_gb | Disk size in GB | `number` | `128` |
| type | Disk type | `string` | `"Premium_LRS"` |
| caching | Disk caching | `string` | `"ReadWrite"` |
| lun | Logical Unit Number | `number` | `disk index` |
| create_option | Create option | `string` | `"Empty"` |

## Outputs

| Name | Description |
|------|-------------|
| linux_vm_ids | Map of Linux VM IDs |
| windows_vm_ids | Map of Windows VM IDs |
| all_vm_ids | Map of all VM IDs |
| linux_vm_names | Map of Linux VM names |
| windows_vm_names | Map of Windows VM names |
| all_vm_names | Map of all VM names |
| nic_ids | Map of NIC IDs |
| private_ip_addresses | Map of private IPs |
| public_ip_addresses | Map of public IPs |
| availability_set_ids | Map of availability set IDs |
| proximity_placement_group_ids | Map of PPG IDs |
| data_disk_ids | Map of data disk IDs |
| connection_info | Connection commands (SSH/RDP) |
| vm_count | VM count summary |
| summary | Complete resource summary |

## Examples

### Multi-Tier Application

```hcl
# Web tier (3 VMs with availability set)
module "web_tier" {
  source = "../../terraform-units/modules/compute"
  
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  vms = {
    web01 = {
      vm_name               = "vm-web01"
      os_type               = "linux"
      vm_size               = "Standard_D2s_v3"
      subnet_id             = azurerm_subnet.web.id
      admin_username        = "azureuser"
      ssh_public_key        = file("~/.ssh/id_rsa.pub")
      availability_set_name = "avset-web"
    }
    web02 = {
      vm_name               = "vm-web02"
      os_type               = "linux"
      vm_size               = "Standard_D2s_v3"
      subnet_id             = azurerm_subnet.web.id
      admin_username        = "azureuser"
      ssh_public_key        = file("~/.ssh/id_rsa.pub")
      availability_set_name = "avset-web"
    }
    web03 = {
      vm_name               = "vm-web03"
      os_type               = "linux"
      vm_size               = "Standard_D2s_v3"
      subnet_id             = azurerm_subnet.web.id
      admin_username        = "azureuser"
      ssh_public_key        = file("~/.ssh/id_rsa.pub")
      availability_set_name = "avset-web"
    }
  }
}

# App tier (2 Windows VMs)
module "app_tier" {
  source = "../../terraform-units/modules/compute"
  
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  vms = {
    app01 = {
      vm_name               = "vm-app01"
      os_type               = "windows"
      vm_size               = "Standard_D4s_v3"
      subnet_id             = azurerm_subnet.app.id
      admin_username        = "azureadmin"
      admin_password        = var.admin_password
      availability_set_name = "avset-app"
    }
    app02 = {
      vm_name               = "vm-app02"
      os_type               = "windows"
      vm_size               = "Standard_D4s_v3"
      subnet_id             = azurerm_subnet.app.id
      admin_username        = "azureadmin"
      admin_password        = var.admin_password
      availability_set_name = "avset-app"
    }
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| azurerm | ~> 3.80 |
| random | ~> 3.5 |

## Resources Created

- `azurerm_linux_virtual_machine` - Linux VMs
- `azurerm_windows_virtual_machine` - Windows VMs
- `azurerm_network_interface` - Network interfaces
- `azurerm_public_ip` - Public IP addresses (if enabled)
- `azurerm_managed_disk` - Data disks
- `azurerm_virtual_machine_data_disk_attachment` - Disk attachments
- `azurerm_availability_set` - Availability sets (auto-created)
- `azurerm_proximity_placement_group` - Proximity placement groups (auto-created)

## Notes

- **Authentication**: Linux VMs prefer SSH keys but fallback to passwords if no key provided
- **Windows VMs**: Require `admin_password` to be set
- **Availability Sets**: Automatically created when referenced by VMs
- **Proximity Placement Groups**: Automatically created and linked to availability sets
- **Public IPs**: Only created when `enable_public_ip = true`
- **Data Disks**: LUN is automatically assigned if not specified
- **Accelerated Networking**: Enabled by default for improved performance
- **Boot Diagnostics**: Uses managed storage (no storage account required)

## License

MIT
