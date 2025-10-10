# Network Security Module Variables

variable "nsg_name" {
  description = "Name of the network security group"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "enable_ad_rules" {
  description = "Enable Active Directory NSG rules"
  type        = bool
  default     = true
}

variable "enable_dns_rules" {
  description = "Enable DNS NSG rules"
  type        = bool
  default     = true
}

variable "custom_rules" {
  description = "List of custom NSG rules"
  type = list(object({
    name                       = string
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = string
    destination_address_prefix = string
  }))
  default = []
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
}
