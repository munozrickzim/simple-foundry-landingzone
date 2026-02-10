
variable "resource_group_name" {
  description = "Name of the Azure Resource Group to create/use."
  type        = string
  validation {
    condition     = length(var.resource_group_name) >= 3
    error_message = "resource_group_name must be at least 3 characters."
  }
}

variable "name_prefix" {
  description = "Letters-only prefix used to name resources (will be lowercased)."
  type        = string
  validation {
    condition     = can(regex("^[A-Za-z]+$", var.name_prefix))
    error_message = "name_prefix must contain letters only (A–Z)."
  }
}

variable "environment" {
  description = "Environment short name appended to resources."
  type        = string
  default     = "dev"
  validation {
    condition     = can(regex("^[A-Za-z0-9]+$", var.environment))
    error_message = "environment may contain only letters and digits."
  }
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "eastus"
}

variable "tags" {
  description = "Optional tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "foundry_sku_name" {
  description = "SKU for the Foundry (AIServices) account; typically S0."
  type        = string
  default     = "S0"
}

variable "subscription_id" {
  description = "Azure subscription ID for resource deployment."
  type        = string
}

variable "create_app_service_plans" {
  description = "Whether to create App Service Plans (Functions Premium and Web Standard). Set to false to skip creation."
  type        = bool
  default     = false
}
