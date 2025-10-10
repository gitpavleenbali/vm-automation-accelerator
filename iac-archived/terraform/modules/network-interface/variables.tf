# Network Interface Module Variables

variable "nic_name" {
  description = "Name of the network interface"
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

variable "subnet_id" {
  description = "Subnet resource ID"
  type        = string
}

variable "network_security_group_id" {
  description = "NSG resource ID"
  type        = string
}

variable "private_ip_address_allocation" {
  description = "IP allocation method (Dynamic or Static)"
  type        = string
  default     = "Dynamic"
}

variable "private_ip_address" {
  description = "Static private IP address"
  type        = string
  default     = null
}

variable "enable_public_ip" {
  description = "Enable public IP address"
  type        = bool
  default     = false
}

variable "public_ip_name" {
  description = "Public IP name"
  type        = string
  default     = null
}

variable "enable_accelerated_networking" {
  description = "Enable accelerated networking"
  type        = bool
  default     = true
}

variable "enable_ip_forwarding" {
  description = "Enable IP forwarding"
  type        = bool
  default     = false
}

variable "availability_zones" {
  description = "Availability zones for public IP"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
}
