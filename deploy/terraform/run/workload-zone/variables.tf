###############################################################################
# Run Workload Zone - Variables
# Network infrastructure for workload deployment
###############################################################################

# ============================================================================
# Authentication Variables (for Azure DevOps Service Principal)
# ============================================================================

variable "arm_client_id" {
  description = "Azure Service Principal Client ID (set via ARM_CLIENT_ID env var in pipeline)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "arm_client_secret" {
  description = "Azure Service Principal Client Secret (set via ARM_CLIENT_SECRET env var in pipeline)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "arm_tenant_id" {
  description = "Azure Tenant ID (set via ARM_TENANT_ID env var in pipeline)"
  type        = string
  default     = ""
  sensitive   = true
}

# ============================================================================
# Core Configuration Variables
# ============================================================================

variable "environment" {
  description = "Environment name (dev, uat, prod, shared)"
  type        = string
  
  validation {
    condition     = can(regex("^(dev|development|uat|test|prod|production|shared)$", lower(var.environment)))
    error_message = "Environment must be one of: dev, uat, prod, shared"
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "project_code" {
  description = "Project code for naming (3-8 alphanumeric characters)"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9]{3,8}$", lower(var.project_code)))
    error_message = "Project code must be 3-8 alphanumeric characters"
  }
}

variable "workload_name" {
  description = "Workload name (e.g., 'net', 'network', 'hub')"
  type        = string
  default     = "net"
}

variable "instance_number" {
  description = "Instance number for naming (e.g., '01', '02')"
  type        = string
  default     = "01"
  
  validation {
    condition     = can(regex("^[0-9]{2}$", var.instance_number))
    error_message = "Instance number must be 2 digits (e.g., '01', '02')"
  }
}

# ============================================================================
# Control Plane Backend Configuration
# ============================================================================

variable "control_plane_subscription_id" {
  description = "Subscription ID where control plane is deployed"
  type        = string
}

variable "control_plane_resource_group" {
  description = "Resource group containing control plane"
  type        = string
}

variable "control_plane_storage_account" {
  description = "Storage account for Terraform state"
  type        = string
}

variable "control_plane_container_name" {
  description = "Container name for Terraform state"
  type        = string
  default     = "tfstate"
}

# ============================================================================
# Resource Group Configuration (Optional)
# ============================================================================

variable "resource_group_name" {
  description = "Name of existing resource group (optional, creates new if not specified)"
  type        = string
  default     = null
}

# ============================================================================
# Virtual Network Configuration
# ============================================================================

variable "vnet_address_space" {
  description = "Address space for virtual network (CIDR notation)"
  type        = list(string)
  
  validation {
    condition     = length(var.vnet_address_space) > 0
    error_message = "At least one address space must be specified"
  }
}

variable "dns_servers" {
  description = "Custom DNS servers for virtual network (empty for Azure default)"
  type        = list(string)
  default     = []
}

# ============================================================================
# Subnet Configuration
# ============================================================================

variable "subnets" {
  description = "Map of subnets to create"
  type = map(object({
    address_prefix       = string
    service_endpoints    = optional(list(string), [])
    delegation           = optional(object({
      name               = string
      service_delegation = object({
        name    = string
        actions = list(string)
      })
    }), null)
    private_endpoint_network_policies_enabled = optional(bool, true)
    private_link_service_network_policies_enabled = optional(bool, true)
  }))
  
  default = {}
}

# Example subnets configuration:
# subnets = {
#   web = {
#     address_prefix = "10.0.1.0/24"
#     service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
#   }
#   app = {
#     address_prefix = "10.0.2.0/24"
#     service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.Sql"]
#   }
#   data = {
#     address_prefix = "10.0.3.0/24"
#     service_endpoints = ["Microsoft.Storage", "Microsoft.Sql"]
#   }
# }

# ============================================================================
# Network Security Group Configuration
# ============================================================================

variable "enable_nsg" {
  description = "Create NSGs for subnets"
  type        = bool
  default     = true
}

variable "nsg_rules" {
  description = "Custom NSG rules to apply"
  type = map(list(object({
    name                       = string
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = string
    destination_address_prefix = string
  })))
  default = {}
}

# ============================================================================
# Route Table Configuration
# ============================================================================

variable "enable_route_table" {
  description = "Create route tables for subnets"
  type        = bool
  default     = false
}

variable "routes" {
  description = "Custom routes to add"
  type = map(list(object({
    name                   = string
    address_prefix         = string
    next_hop_type          = string
    next_hop_in_ip_address = optional(string, null)
  })))
  default = {}
}

# ============================================================================
# VNet Peering Configuration
# ============================================================================

variable "enable_vnet_peering" {
  description = "Enable VNet peering to hub or other networks"
  type        = bool
  default     = false
}

variable "peering_config" {
  description = "VNet peering configuration"
  type = object({
    remote_vnet_id                   = string
    allow_virtual_network_access     = optional(bool, true)
    allow_forwarded_traffic          = optional(bool, true)
    allow_gateway_transit            = optional(bool, false)
    use_remote_gateways              = optional(bool, false)
  })
  default = null
}

# ============================================================================
# DDoS Protection Configuration
# ============================================================================

variable "enable_ddos_protection" {
  description = "Enable DDoS protection plan (recommended for production)"
  type        = bool
  default     = false
}

variable "ddos_protection_plan_id" {
  description = "ID of existing DDoS protection plan (optional)"
  type        = string
  default     = null
}

# ============================================================================
# Private DNS Zone Configuration
# ============================================================================

variable "enable_private_dns_zones" {
  description = "Create private DNS zones for private endpoints"
  type        = bool
  default     = false
}

variable "private_dns_zones" {
  description = "List of private DNS zones to create"
  type        = list(string)
  default     = []
}

# Example: ["privatelink.blob.core.windows.net", "privatelink.vaultcore.azure.net"]

# ============================================================================
# Network Watcher Configuration
# ============================================================================

variable "enable_network_watcher" {
  description = "Enable Network Watcher for the region"
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Enable NSG flow logs"
  type        = bool
  default     = false
}

variable "flow_logs_retention_days" {
  description = "Number of days to retain flow logs"
  type        = number
  default     = 30
  
  validation {
    condition     = var.flow_logs_retention_days >= 0 && var.flow_logs_retention_days <= 365
    error_message = "Flow logs retention must be between 0 and 365 days"
  }
}

# ============================================================================
# Deployment Metadata (Optional)
# ============================================================================

variable "automation_version" {
  description = "Version of the VM automation framework"
  type        = string
  default     = "1.0.0"
}

variable "deployed_by" {
  description = "Identity that deployed the infrastructure"
  type        = string
  default     = ""
}

variable "deployment_id" {
  description = "Unique deployment identifier"
  type        = string
  default     = ""
}

variable "enable_arm_deployment_tracking" {
  description = "Enable ARM deployment tracking for Azure Portal visibility"
  type        = bool
  default     = true
}

# ============================================================================
# Tagging (Optional)
# ============================================================================

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ============================================================================
# Authentication Variables (for Azure DevOps Pipeline Support)
# ============================================================================

variable "arm_client_id" {
  description = "Azure Client ID for Service Principal authentication (pipeline mode)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "arm_client_secret" {
  description = "Azure Client Secret for Service Principal authentication (pipeline mode)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "arm_tenant_id" {
  description = "Azure Tenant ID for Service Principal authentication (pipeline mode)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "arm_subscription_id" {
  description = "Azure Subscription ID for authentication (pipeline mode)"
  type        = string
  default     = ""
  sensitive   = true
}
