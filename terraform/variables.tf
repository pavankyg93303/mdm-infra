variable "subscription_id" {
  description = "Azure subscription ID to deploy into"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "prefix" {
  description = "Name prefix for all resources (short, lowercase, alphanumeric)"
  type        = string
  default     = "mdm"
}

variable "resource_group_name" {
  description = "Optional explicit resource group name (if empty we'll create one)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {
    environment = "dev"
    owner       = "mdm-team"
  }
}

variable "databricks_sku" {
  description = "Databricks workspace SKU"
  type        = string
  default     = "premium"
}

variable "synapse_sql_admin" {
  description = "Admin username for Synapse SQL"
  type        = string
  default     = "sqladminuser"
}

variable "enable_purge_protection" {
  description = "Enable Key Vault purge protection (requires privileged permissions). Set to false for dev."
  type        = bool
  default     = false
}
