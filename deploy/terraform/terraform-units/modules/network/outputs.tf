#=============================================================================
# VIRTUAL NETWORK OUTPUTS
#=============================================================================

output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.vnet.id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.vnet.name
}

output "vnet_address_space" {
  description = "Address space of the virtual network"
  value       = azurerm_virtual_network.vnet.address_space
}

output "vnet_location" {
  description = "Location of the virtual network"
  value       = azurerm_virtual_network.vnet.location
}

output "vnet_resource_group_name" {
  description = "Resource group name of the virtual network"
  value       = azurerm_virtual_network.vnet.resource_group_name
}

#=============================================================================
# SUBNET OUTPUTS
#=============================================================================

output "subnet_ids" {
  description = "Map of subnet keys to their IDs"
  value = {
    for subnet_key, subnet in azurerm_subnet.subnet : subnet_key => subnet.id
  }
}

output "subnet_names" {
  description = "Map of subnet keys to their names"
  value = {
    for subnet_key, subnet in azurerm_subnet.subnet : subnet_key => subnet.name
  }
}

output "subnet_address_prefixes" {
  description = "Map of subnet keys to their address prefixes"
  value = {
    for subnet_key, subnet in azurerm_subnet.subnet : subnet_key => subnet.address_prefixes
  }
}

output "subnets" {
  description = "Complete subnet information"
  value = {
    for subnet_key, subnet in azurerm_subnet.subnet : subnet_key => {
      id               = subnet.id
      name             = subnet.name
      address_prefixes = subnet.address_prefixes
    }
  }
}

#=============================================================================
# NETWORK SECURITY GROUP OUTPUTS
#=============================================================================

output "nsg_ids" {
  description = "Map of subnet keys to their NSG IDs"
  value = {
    for subnet_key, nsg in azurerm_network_security_group.nsg : subnet_key => nsg.id
  }
}

output "nsg_names" {
  description = "Map of subnet keys to their NSG names"
  value = {
    for subnet_key, nsg in azurerm_network_security_group.nsg : subnet_key => nsg.name
  }
}

#=============================================================================
# ROUTE TABLE OUTPUTS
#=============================================================================

output "route_table_ids" {
  description = "Map of subnet keys to their route table IDs"
  value = {
    for subnet_key, rt in azurerm_route_table.rt : subnet_key => rt.id
  }
}

output "route_table_names" {
  description = "Map of subnet keys to their route table names"
  value = {
    for subnet_key, rt in azurerm_route_table.rt : subnet_key => rt.name
  }
}

#=============================================================================
# VNET PEERING OUTPUTS
#=============================================================================

output "vnet_peering_ids" {
  description = "Map of peering keys to their IDs"
  value = {
    for peering_key, peering in azurerm_virtual_network_peering.peering : peering_key => peering.id
  }
}

output "vnet_peering_names" {
  description = "Map of peering keys to their names"
  value = {
    for peering_key, peering in azurerm_virtual_network_peering.peering : peering_key => peering.name
  }
}

#=============================================================================
# PRIVATE DNS ZONE OUTPUTS
#=============================================================================

output "private_dns_zone_ids" {
  description = "Map of DNS zone keys to their IDs"
  value = {
    for zone_key, zone in azurerm_private_dns_zone.dns_zone : zone_key => zone.id
  }
}

output "private_dns_zone_names" {
  description = "Map of DNS zone keys to their names"
  value = {
    for zone_key, zone in azurerm_private_dns_zone.dns_zone : zone_key => zone.name
  }
}

#=============================================================================
# SUMMARY OUTPUTS
#=============================================================================

output "summary" {
  description = "Summary of all network resources created"
  value = {
    vnet = {
      id            = azurerm_virtual_network.vnet.id
      name          = azurerm_virtual_network.vnet.name
      address_space = azurerm_virtual_network.vnet.address_space
      location      = azurerm_virtual_network.vnet.location
    }
    subnets = {
      count = length(azurerm_subnet.subnet)
      names = [for subnet in azurerm_subnet.subnet : subnet.name]
    }
    nsgs = {
      count = length(azurerm_network_security_group.nsg)
      names = [for nsg in azurerm_network_security_group.nsg : nsg.name]
    }
    route_tables = {
      count = length(azurerm_route_table.rt)
      names = [for rt in azurerm_route_table.rt : rt.name]
    }
    peerings = {
      count = length(azurerm_virtual_network_peering.peering)
      names = [for peering in azurerm_virtual_network_peering.peering : peering.name]
    }
    private_dns_zones = {
      count = length(azurerm_private_dns_zone.dns_zone)
      names = [for zone in azurerm_private_dns_zone.dns_zone : zone.name]
    }
  }
}

#=============================================================================
# CONVENIENCE OUTPUTS
#=============================================================================

output "subnet_id_map" {
  description = "Flat map of subnet names to IDs for easy lookup"
  value = {
    for subnet_key, subnet in azurerm_subnet.subnet : subnet.name => subnet.id
  }
}

output "nsg_id_map" {
  description = "Flat map of NSG names to IDs for easy lookup"
  value = {
    for subnet_key, nsg in azurerm_network_security_group.nsg : nsg.name => nsg.id
  }
}
