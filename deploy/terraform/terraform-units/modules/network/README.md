# Reusable Network Module

This module provides reusable patterns for deploying Azure Virtual Networks with comprehensive networking features.

## Features

- ✅ **Virtual Network** - Configurable address space and DNS servers
- ✅ **Multiple Subnets** - Create multiple subnets with custom configuration
- ✅ **Network Security Groups** - Auto-created NSGs with customizable rules
- ✅ **Route Tables** - User-defined routes with multiple next hop types
- ✅ **VNet Peering** - Bi-directional or uni-directional peering
- ✅ **Private DNS Zones** - Private DNS zones with VNet linkage
- ✅ **Service Endpoints** - Configure service endpoints per subnet
- ✅ **Subnet Delegation** - Support for delegated subnets
- ✅ **DDoS Protection** - Optional DDoS protection plan
- ✅ **Transform Layer** - Input normalization for flexible usage

## Usage

### Basic Network with Subnets

```hcl
module "network" {
  source = "../../terraform-units/modules/network"
  
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  vnet_name          = "vnet-dev-eastus"
  vnet_address_space = ["10.0.0.0/16"]
  
  subnets = {
    web = {
      name             = "snet-web"
      address_prefixes = ["10.0.1.0/24"]
    }
    app = {
      name             = "snet-app"
      address_prefixes = ["10.0.2.0/24"]
    }
    db = {
      name             = "snet-db"
      address_prefixes = ["10.0.3.0/24"]
    }
  }
  
  tags = {
    environment = "dev"
    project     = "webapp"
  }
}
```

### Network with NSG Rules

```hcl
module "network" {
  source = "../../terraform-units/modules/network"
  
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  vnet_name          = "vnet-prod-eastus"
  vnet_address_space = ["10.100.0.0/16"]
  
  subnets = {
    web = {
      name             = "snet-web"
      address_prefixes = ["10.100.1.0/24"]
      
      nsg_rules = {
        allow_http = {
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "80"
          source_address_prefix      = "*"
          destination_address_prefix = "*"
          description                = "Allow HTTP traffic"
        }
        allow_https = {
          priority                   = 110
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "443"
          source_address_prefix      = "*"
          destination_address_prefix = "*"
          description                = "Allow HTTPS traffic"
        }
        deny_all = {
          priority                   = 4096
          direction                  = "Inbound"
          access                     = "Deny"
          protocol                   = "*"
          source_port_range          = "*"
          destination_port_range     = "*"
          source_address_prefix      = "*"
          destination_address_prefix = "*"
          description                = "Deny all other traffic"
        }
      }
    }
  }
}
```

### Network with Route Tables

```hcl
module "network" {
  source = "../../terraform-units/modules/network"
  
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  vnet_name          = "vnet-hub-eastus"
  vnet_address_space = ["10.200.0.0/16"]
  
  subnets = {
    firewall = {
      name             = "AzureFirewallSubnet"
      address_prefixes = ["10.200.1.0/24"]
      create_nsg       = false  # Firewall subnet doesn't need NSG
    }
    app = {
      name               = "snet-app"
      address_prefixes   = ["10.200.2.0/24"]
      create_route_table = true
      
      routes = {
        default_route = {
          name                   = "route-to-firewall"
          address_prefix         = "0.0.0.0/0"
          next_hop_type          = "VirtualAppliance"
          next_hop_in_ip_address = "10.200.1.4"
        }
        to_onprem = {
          name           = "route-to-onprem"
          address_prefix = "192.168.0.0/16"
          next_hop_type  = "VirtualNetworkGateway"
        }
      }
    }
  }
}
```

### Hub-Spoke Topology with Peering

```hcl
# Hub VNet
module "hub_network" {
  source = "../../terraform-units/modules/network"
  
  resource_group_name = azurerm_resource_group.hub.name
  location            = "eastus"
  
  vnet_name          = "vnet-hub-eastus"
  vnet_address_space = ["10.0.0.0/16"]
  
  subnets = {
    gateway = {
      name             = "GatewaySubnet"
      address_prefixes = ["10.0.1.0/24"]
      create_nsg       = false
    }
    firewall = {
      name             = "AzureFirewallSubnet"
      address_prefixes = ["10.0.2.0/24"]
      create_nsg       = false
    }
  }
}

# Spoke VNet with peering to hub
module "spoke_network" {
  source = "../../terraform-units/modules/network"
  
  resource_group_name = azurerm_resource_group.spoke.name
  location            = "eastus"
  
  vnet_name          = "vnet-spoke-eastus"
  vnet_address_space = ["10.1.0.0/16"]
  
  subnets = {
    web = {
      name             = "snet-web"
      address_prefixes = ["10.1.1.0/24"]
    }
  }
  
  vnet_peerings = {
    to_hub = {
      name                    = "peer-spoke-to-hub"
      remote_vnet_id          = module.hub_network.vnet_id
      allow_forwarded_traffic = true
      use_remote_gateways     = true
    }
  }
}
```

### Network with Private DNS Zones

```hcl
module "network" {
  source = "../../terraform-units/modules/network"
  
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  vnet_name          = "vnet-prod-eastus"
  vnet_address_space = ["10.100.0.0/16"]
  
  subnets = {
    app = {
      name              = "snet-app"
      address_prefixes  = ["10.100.1.0/24"]
      service_endpoints = ["Microsoft.Storage", "Microsoft.Sql", "Microsoft.KeyVault"]
    }
  }
  
  private_dns_zones = {
    blob = {
      name = "privatelink.blob.core.windows.net"
    }
    sql = {
      name = "privatelink.database.windows.net"
    }
    keyvault = {
      name = "privatelink.vaultcore.azure.net"
    }
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| resource_group_name | Resource group name | `string` | n/a | yes |
| location | Azure region | `string` | n/a | yes |
| vnet_name | VNet name | `string` | n/a | yes |
| vnet_address_space | VNet address space (CIDR) | `list(string)` | n/a | yes |
| subnets | Map of subnet configurations | `map(object)` | n/a | yes |
| tags | Common tags for all resources | `map(string)` | `{}` | no |
| vnet_dns_servers | Custom DNS servers | `list(string)` | `[]` | no |
| ddos_protection_plan_id | DDoS protection plan ID | `string` | `null` | no |
| disable_bgp_route_propagation | Disable BGP route propagation | `bool` | `false` | no |
| vnet_peerings | Map of VNet peerings | `map(object)` | `{}` | no |
| private_dns_zones | Map of private DNS zones | `map(object)` | `{}` | no |

### Subnet Configuration Object

Each subnet in the `subnets` map can have:

| Property | Description | Type | Default |
|----------|-------------|------|---------|
| name | Subnet name | `string` | **required** |
| address_prefixes | Address prefixes (CIDR) | `list(string)` | **required** |
| service_endpoints | Service endpoints | `list(string)` | `[]` |
| delegation | Service delegation | `object` | `null` |
| private_endpoint_network_policies_enabled | Enable PE policies | `bool` | `true` |
| private_link_service_network_policies_enabled | Enable PLS policies | `bool` | `true` |
| create_nsg | Create NSG | `bool` | `true` |
| nsg_name | NSG name | `string` | `"{name}-nsg"` |
| nsg_rules | Map of NSG rules | `map(object)` | `{}` |
| create_route_table | Create route table | `bool` | `false` |
| route_table_name | Route table name | `string` | `"{name}-rt"` |
| routes | Map of routes | `map(object)` | `{}` |
| tags | Subnet-specific tags | `map(string)` | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| vnet_id | Virtual network ID |
| vnet_name | Virtual network name |
| vnet_address_space | VNet address space |
| subnet_ids | Map of subnet IDs |
| subnet_names | Map of subnet names |
| subnet_address_prefixes | Map of subnet address prefixes |
| subnets | Complete subnet information |
| nsg_ids | Map of NSG IDs |
| nsg_names | Map of NSG names |
| route_table_ids | Map of route table IDs |
| route_table_names | Map of route table names |
| vnet_peering_ids | Map of peering IDs |
| private_dns_zone_ids | Map of DNS zone IDs |
| summary | Complete resource summary |
| subnet_id_map | Flat map of subnet names to IDs |
| nsg_id_map | Flat map of NSG names to IDs |

## Common Patterns

### Three-Tier Application Network

```hcl
module "app_network" {
  source = "../../terraform-units/modules/network"
  
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  vnet_name          = "vnet-app-prod"
  vnet_address_space = ["10.100.0.0/16"]
  
  subnets = {
    web = {
      name             = "snet-web"
      address_prefixes = ["10.100.1.0/24"]
      nsg_rules = {
        allow_http  = { priority = 100, direction = "Inbound", access = "Allow", protocol = "Tcp", source_port_range = "*", destination_port_range = "80", source_address_prefix = "*", destination_address_prefix = "*" }
        allow_https = { priority = 110, direction = "Inbound", access = "Allow", protocol = "Tcp", source_port_range = "*", destination_port_range = "443", source_address_prefix = "*", destination_address_prefix = "*" }
      }
    }
    app = {
      name             = "snet-app"
      address_prefixes = ["10.100.2.0/24"]
      nsg_rules = {
        allow_from_web = { priority = 100, direction = "Inbound", access = "Allow", protocol = "Tcp", source_port_range = "*", destination_port_range = "8080", source_address_prefix = "10.100.1.0/24", destination_address_prefix = "*" }
      }
    }
    db = {
      name             = "snet-db"
      address_prefixes = ["10.100.3.0/24"]
      service_endpoints = ["Microsoft.Sql"]
      nsg_rules = {
        allow_from_app = { priority = 100, direction = "Inbound", access = "Allow", protocol = "Tcp", source_port_range = "*", destination_port_range = "1433", source_address_prefix = "10.100.2.0/24", destination_address_prefix = "*" }
      }
    }
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| azurerm | ~> 3.80 |

## Resources Created

- `azurerm_virtual_network` - Virtual network
- `azurerm_subnet` - Subnets
- `azurerm_network_security_group` - NSGs
- `azurerm_network_security_rule` - NSG rules
- `azurerm_route_table` - Route tables
- `azurerm_route` - Routes
- `azurerm_subnet_network_security_group_association` - NSG associations
- `azurerm_subnet_route_table_association` - Route table associations
- `azurerm_virtual_network_peering` - VNet peerings
- `azurerm_private_dns_zone` - Private DNS zones
- `azurerm_private_dns_zone_virtual_network_link` - DNS zone links

## Notes

- **NSGs**: Created automatically for each subnet unless `create_nsg = false`
- **Route Tables**: Only created when `create_route_table = true`
- **Service Endpoints**: Commonly used endpoints include `Microsoft.Storage`, `Microsoft.Sql`, `Microsoft.KeyVault`
- **Special Subnets**: `GatewaySubnet` and `AzureFirewallSubnet` should have `create_nsg = false`
- **VNet Peering**: Remember to create reciprocal peering from remote VNet
- **Private DNS**: Automatically linked to the VNet
- **Address Spacing**: Ensure address prefixes don't overlap between subnets

## License

MIT
