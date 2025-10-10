#=============================================================================
# REQUIRED VARIABLES
#=============================================================================

variable "vm_id" {
  description = "Azure resource ID of the virtual machine to monitor"
  type        = string
}

variable "vm_name" {
  description = "Name of the virtual machine (used for naming DCR resources)"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where monitoring resources will be created"
  type        = string
}

variable "location" {
  description = "Azure region where monitoring resources will be created"
  type        = string
}

variable "os_type" {
  description = "Operating system type: 'Windows' or 'Linux'"
  type        = string
  
  validation {
    condition     = contains(["Windows", "Linux"], var.os_type)
    error_message = "OS type must be either 'Windows' or 'Linux'."
  }
}

variable "log_analytics_workspace_id" {
  description = "Azure resource ID of the Log Analytics workspace"
  type        = string
}

variable "log_analytics_workspace_key" {
  description = "Primary shared key of the Log Analytics workspace"
  type        = string
  sensitive   = true
}

#=============================================================================
# OPTIONAL VARIABLES
#=============================================================================

variable "enable_performance_counters" {
  description = "Enable collection of performance counters (CPU, memory, disk, network)"
  type        = bool
  default     = true
}

variable "enable_event_logs" {
  description = "Enable collection of event logs (Windows Event Logs or Linux Syslog)"
  type        = bool
  default     = true
}

variable "enable_vm_insights" {
  description = "Enable VM Insights by installing Dependency Agent (provides service map and connection monitoring)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all monitoring resources"
  type        = map(string)
  default     = {}
}
