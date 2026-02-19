
variable "workload" {
  description = "Letters-only prefix used to name resources (will be lowercased)."
  type        = string
  validation {
    condition     = can(regex("^[A-Za-z]+$", var.workload))
    error_message = "workload must contain letters only (A–Z)."
  }
}

variable "environment" {
  description = "Environment short name appended to resources."
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "test", "stage", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, stage, or prod."
  }
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "eastus"
  validation {
    condition = contains([
      "eastus", "eastus2", "westus", "westus2", "westus3", "centralus", "northcentralus", 
      "southcentralus", "westcentralus", "canadacentral", "canadaeast", "brazilsouth", 
      "brazilsoutheast", "mexicocentral", "chilecentral", "northeurope", "westeurope", 
      "uksouth", "ukwest", "francecentral", "francesouth", "germanywestcentral", 
      "germanynorth", "switzerlandnorth", "switzerlandwest", "norwayeast", "norwaywest", 
      "swedencentral", "polandcentral", "spaincentral", "italynorth", "belgiumcentral", 
      "austriaeast", "denmarkeast", "uaenorth", "uaecentral", "israelcentral", 
      "qatarcentral", "southafricanorth", "southafricawest", "eastasia", "southeastasia", 
      "japaneast", "japanwest", "koreacentral", "koreasouth", "centralindia", 
      "southindia", "westindia", "australiaeast", "australiasoutheast", "australiacentral", 
      "australiacentral2", "indonesiacentral", "malaysiawest", "newzealandnorth"
    ], var.location)
    error_message = "location must be a valid Azure region."
  }
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

variable "openai_sku_name" {
  description = "SKU for the Azure OpenAI Service account; typically S0."
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
