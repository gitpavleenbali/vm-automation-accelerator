###############################################################################
# Naming Module - Variables
# Based on Microsoft SAP Automation Framework naming patterns
# Provides centralized, consistent naming for all Azure resources
###############################################################################

variable "environment" {
  description = "Environment name (dev, uat, prod)"
  type        = string
  validation {
    condition     = can(regex("^(dev|uat|prod|test|staging|mgmt)$", var.environment))
    error_message = "Environment must be dev, uat, prod, test, staging, or mgmt."
  }
}

variable "location" {
  description = "Azure region for resource deployment"
  type        = string
}

variable "project_code" {
  description = "Project code or identifier (3-5 characters)"
  type        = string
  validation {
    condition     = length(var.project_code) >= 3 && length(var.project_code) <= 5
    error_message = "Project code must be between 3-5 characters."
  }
}

variable "workload_name" {
  description = "Workload or application name"
  type        = string
  default     = ""
}

variable "instance_number" {
  description = "Instance number (01, 02, etc.)"
  type        = string
  default     = "01"
  validation {
    condition     = can(regex("^[0-9]{2}$", var.instance_number))
    error_message = "Instance number must be 2 digits (01, 02, etc.)."
  }
}

variable "random_id" {
  description = "Random ID for globally unique resources"
  type        = string
  default     = ""
}

variable "use_random_suffix" {
  description = "Whether to append random suffix to globally unique resource names"
  type        = bool
  default     = true
}

variable "naming_convention" {
  description = "Naming convention to use (azure_caf, custom)"
  type        = string
  default     = "azure_caf"
  validation {
    condition     = contains(["azure_caf", "custom"], var.naming_convention)
    error_message = "Naming convention must be azure_caf or custom."
  }
}

variable "resource_prefixes" {
  description = "Map of resource type prefixes"
  type        = map(string)
  default = {
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
  }
}

variable "resource_suffixes" {
  description = "Map of resource type suffixes"
  type        = map(string)
  default = {
    vm                    = "-vm"
    vmss                  = "-vmss"
    nic                   = "-nic"
    pip                   = "-pip"
    storage_account       = ""
    disk                  = "-disk"
    vnet                  = "-vnet"
    subnet                = "-subnet"
    nsg                   = "-nsg"
    route_table           = "-rt"
    load_balancer         = "-lb"
    application_gateway   = "-agw"
    key_vault             = "-kv"
    managed_identity      = "-id"
    log_analytics         = "-log"
    application_insights  = "-appi"
    action_group          = "-ag"
    resource_group        = "-rg"
  }
}

variable "custom_names" {
  description = "Override specific resource names with custom values"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
