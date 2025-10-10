#=============================================================================
# REQUIRED VARIABLES
#=============================================================================

variable "resource_group_name" {
  description = "Name of the resource group where network resources will be deployed"
  type        = string
}

variable "location" {
  description = "Azure region where network resources will be deployed"
  type        = string
}

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
}

variable "vnet_address_space" {
  description = "Address space for the virtual network (CIDR notation)"
  type        = list(string)
  
  validation {
    condition     = length(var.vnet_address_space) > 0
    error_message = "At least one address space must be specified."
  }
}

variable "subnets" {
  description = <<-EOT
    Map of subnets to create within the VNet. Each subnet can have the following properties:
    
    Required:
      - name: Subnet name
      - address_prefixes: List of address prefixes (CIDR notation)
      
    Optional:
      - service_endpoints: List of service endpoints (e.g., ["Microsoft.Storage", "Microsoft.Sql"])
      - delegation: Service delegation configuration
      - private_endpoint_network_policies_enabled: Enable private endpoint policies (default: true)
      - private_link_service_network_policies_enabled: Enable private link service policies (default: true)
      - create_nsg: Create NSG for this subnet (default: true)
      - nsg_name: Name of the NSG (default: "{subnet_name}-nsg")
      - nsg_rules: Map of NSG rules (see below)
      - create_route_table: Create route table for this subnet (default: false)
      - route_table_name: Name of the route table (default: "{subnet_name}-rt")
      - routes: Map of routes (see below)
      - tags: Additional tags for this subnet
    
    NSG Rule properties:
      - name: Rule name (default: rule key)
      - priority: Rule priority (100-4096)
      - direction: "Inbound" or "Outbound"
      - access: "Allow" or "Deny"
      - protocol: "Tcp", "Udp", "Icmp", or "*"
      - source_port_range: Source port or range (e.g., "*", "80", "1024-65535")
      - source_port_ranges: List of source port ranges (mutually exclusive with source_port_range)
      - destination_port_range: Destination port or range
      - destination_port_ranges: List of destination port ranges
      - source_address_prefix: Source address prefix (e.g., "*", "10.0.0.0/24", "Internet")
      - source_address_prefixes: List of source address prefixes
      - destination_address_prefix: Destination address prefix
      - destination_address_prefixes: List of destination address prefixes
      - description: Rule description
    
    Route properties:
      - name: Route name (default: route key)
      - address_prefix: Destination address prefix (CIDR notation)
      - next_hop_type: "VirtualNetworkGateway", "VnetLocal", "Internet", "VirtualAppliance", "None"
      - next_hop_in_ip_address: Next hop IP address (required for VirtualAppliance)
    
    Example:
      subnets = {
        web = {
          name             = "snet-web"
          address_prefixes = ["10.0.1.0/24"]
          service_endpoints = ["Microsoft.Storage"]
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
            }
          }
        }
        app = {
          name             = "snet-app"
          address_prefixes = ["10.0.2.0/24"]
          create_route_table = true
          routes = {
            to_firewall = {
              address_prefix         = "0.0.0.0/0"
              next_hop_type          = "VirtualAppliance"
              next_hop_in_ip_address = "10.0.100.4"
            }
          }
        }
      }
  EOT
  type = map(object({
    name             = string
    address_prefixes = list(string)
    service_endpoints = optional(list(string), [])
    delegation = optional(object({
      name = string
      service_delegation = object({
        name    = string
        actions = list(string)
      })
    }))
    private_endpoint_network_policies_enabled     = optional(bool, true)
    private_link_service_network_policies_enabled = optional(bool, true)
    create_nsg       = optional(bool, true)
    nsg_name         = optional(string)
    nsg_rules        = optional(map(object({
      name                         = optional(string)
      priority                     = number
      direction                    = string
      access                       = string
      protocol                     = string
      source_port_range            = optional(string)
      source_port_ranges           = optional(list(string))
      destination_port_range       = optional(string)
      destination_port_ranges      = optional(list(string))
      source_address_prefix        = optional(string)
      source_address_prefixes      = optional(list(string))
      destination_address_prefix   = optional(string)
      destination_address_prefixes = optional(list(string))
      description                  = optional(string)
    })), {})
    create_route_table = optional(bool, false)
    route_table_name   = optional(string)
    routes             = optional(map(object({
      name                   = optional(string)
      address_prefix         = string
      next_hop_type          = string
      next_hop_in_ip_address = optional(string)
    })), {})
    tags = optional(map(string), {})
  }))
}

#=============================================================================
# OPTIONAL VARIABLES
#=============================================================================

variable "tags" {
  description = "Common tags to apply to all network resources"
  type        = map(string)
  default     = {}
}

variable "vnet_dns_servers" {
  description = "List of custom DNS servers for the VNet"
  type        = list(string)
  default     = []
}

variable "ddos_protection_plan_id" {
  description = "ID of the DDoS Protection Plan to associate with the VNet"
  type        = string
  default     = null
}

variable "disable_bgp_route_propagation" {
  description = "Disable BGP route propagation on route tables"
  type        = bool
  default     = false
}

variable "vnet_peerings" {
  description = <<-EOT
    Map of VNet peerings to create. Each peering can have:
      - name: Peering name
      - remote_vnet_id: ID of the remote VNet
      - allow_virtual_network_access: Allow access to remote VNet (default: true)
      - allow_forwarded_traffic: Allow forwarded traffic (default: false)
      - allow_gateway_transit: Allow gateway transit (default: false)
      - use_remote_gateways: Use remote gateways (default: false)
    
    Example:
      vnet_peerings = {
        to_hub = {
          name              = "peer-to-hub"
          remote_vnet_id    = "/subscriptions/.../virtualNetworks/vnet-hub"
          allow_forwarded_traffic = true
          use_remote_gateways     = true
        }
      }
  EOT
  type = map(object({
    name                         = string
    remote_vnet_id               = string
    allow_virtual_network_access = optional(bool, true)
    allow_forwarded_traffic      = optional(bool, false)
    allow_gateway_transit        = optional(bool, false)
    use_remote_gateways          = optional(bool, false)
  }))
  default = {}
}

variable "private_dns_zones" {
  description = <<-EOT
    Map of Private DNS zones to create and link to the VNet. Each zone can have:
      - name: DNS zone name (e.g., "privatelink.blob.core.windows.net")
      - registration_enabled: Enable auto-registration (default: false)
    
    Example:
      private_dns_zones = {
        blob = {
          name = "privatelink.blob.core.windows.net"
        }
        sql = {
          name = "privatelink.database.windows.net"
        }
      }
  EOT
  type = map(object({
    name                 = string
    registration_enabled = optional(bool, false)
  }))
  default = {}
}
