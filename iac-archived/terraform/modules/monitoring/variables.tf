# Monitoring Module Variables

variable "vm_id" {
  description = "VM resource ID"
  type        = string
}

variable "vm_name" {
  description = "VM name"
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

variable "os_type" {
  description = "OS type (Windows or Linux)"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID"
  type        = string
}

variable "log_analytics_workspace_key" {
  description = "Log Analytics workspace key"
  type        = string
  sensitive   = true
}

variable "enable_performance_counters" {
  description = "Enable performance counter collection"
  type        = bool
  default     = true
}

variable "enable_event_logs" {
  description = "Enable event log collection"
  type        = bool
  default     = true
}

variable "enable_vm_insights" {
  description = "Enable VM Insights (installs Dependency Agent)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
}
