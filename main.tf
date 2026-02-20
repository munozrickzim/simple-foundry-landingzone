
// Current tenant info (used by Key Vault)
data "azurerm_client_config" "current" {}

locals {
  workload = lower(var.workload)
  env      = lower(var.environment)

  base_hyphen  = "${local.env}-${local.regions[var.location]}-${local.workload}"
  basenohyphen = "${local.env}${local.regions[var.location]}${local.workload}"

  // Names per resource constraints
  storage_account_name = substr("${local.resource_abbreviations.storage_account}${local.basenohyphen}1", 0, 24)
  key_vault_name       = substr("${local.resource_abbreviations.key_vault}-${local.base_hyphen}-1", 0, 24)
  cosmos_account_name  = substr("${local.resource_abbreviations.azure_cosmos_db_database}${local.basenohyphen}-1", 0, 44)
  search_service_name  = substr("${local.resource_abbreviations.ai_search}-${local.base_hyphen}-1", 0, 60)

  appi_name = "${local.resource_abbreviations.application_insights}-${local.base_hyphen}-1"
  law_name  = "${local.resource_abbreviations.log_analytics_workspace}-${local.base_hyphen}-1"

  plan_func_name = "${local.resource_abbreviations.app_service_plan}-${local.base_hyphen}-func-1"
  plan_web_name  = "${local.resource_abbreviations.app_service_plan}-${local.base_hyphen}-web-1"

  // Cognitive Services: prefer lowercase, no hyphens
  cog_cs_name   = substr("${local.resource_abbreviations.content_safety}${local.basenohyphen}-1",   0, 64)
  cog_di_name   = substr("${local.resource_abbreviations.document_intelligence}${local.basenohyphen}-1",   0, 64)
  cog_lang_name = substr("${local.resource_abbreviations.language_service}${local.basenohyphen}-1", 0, 64)
  cog_spch_name = substr("${local.resource_abbreviations.speech_service}${local.basenohyphen}-1", 0, 64)

  // Foundry (AIServices) account allows hyphens
  foundry_name  = "${local.resource_abbreviations.foundry_account}-${local.base_hyphen}-1"
  openai_name   = "${local.resource_abbreviations.azure_openai_service}-${local.base_hyphen}-1"

  resource_group_name_generated = "${local.resource_abbreviations.resource_group}-${local.base_hyphen}"
  resource_group_name_effective = length(trimspace(var.resource_group_name)) > 0 ? var.resource_group_name : local.resource_group_name_generated
}

// ------------------------
// Existing Resource Group (must already exist)
// ------------------------
data "azurerm_resource_group" "rg" {
  name = local.resource_group_name_effective
}

locals {
  resource_group_location = data.azurerm_resource_group.rg.location
}

// ------------------------
// Foundry (AIServices) account with System-Assigned Managed Identity
// ------------------------
resource "azapi_resource" "foundry" {
  type      = "Microsoft.CognitiveServices/accounts@2025-09-01"
  name      = local.foundry_name
  location  = local.resource_group_location
  parent_id = data.azurerm_resource_group.rg.id

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind = "AIServices"
    sku  = { name = var.foundry_sku_name }
    properties = {
      publicNetworkAccess = "Enabled"
      disableLocalAuth    = true
    }
  }

  tags = var.tags
}

// Capture the Foundry principalId for RBAC
locals {
  foundry_principal_id = azapi_resource.foundry.identity[0].principal_id
}

// ------------------------
// Azure OpenAI Service with System-Assigned Managed Identity
// ------------------------
resource "azapi_resource" "openai" {
  type      = "Microsoft.CognitiveServices/accounts@2025-09-01"
  name      = local.openai_name
  location  = local.resource_group_location
  parent_id = data.azurerm_resource_group.rg.id

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind = "OpenAI"
    sku  = { name = var.openai_sku_name }
    properties = {
      publicNetworkAccess = "Enabled"
      disableLocalAuth    = true
    }
  }

  tags = var.tags
}

// ------------------------
// Storage Account (V2, LRS)
// ------------------------
resource "azurerm_storage_account" "st" {
  name                            = local.storage_account_name
  resource_group_name             = local.resource_group_name_effective
  location                        = local.resource_group_location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = var.tags
}

// ------------------------
// Azure Monitor (LAW + App Insights)
// ------------------------
resource "azurerm_log_analytics_workspace" "law" {
  name                = local.law_name
  resource_group_name = local.resource_group_name_effective
  location            = local.resource_group_location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_application_insights" "appi" {
  name                = local.appi_name
  resource_group_name = local.resource_group_name_effective
  location            = local.resource_group_location
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.law.id
  tags                = var.tags
}

// ------------------------
// Key Vault (present, but no secrets needed for Foundry MI)
// ------------------------
resource "azurerm_key_vault" "kv" {
  name                       = local.key_vault_name
  resource_group_name        = local.resource_group_name_effective
  location                   = local.resource_group_location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = true
  rbac_authorization_enabled = true
  tags                       = var.tags
}

// ------------------------
// Cosmos DB (Core API)
// ------------------------
resource "azurerm_cosmosdb_account" "cos" {
  name                          = local.cosmos_account_name
  resource_group_name           = local.resource_group_name_effective
  location                      = local.resource_group_location
  offer_type                    = "Standard"
  kind                          = "GlobalDocumentDB"
  local_authentication_disabled = true

  consistency_policy { consistency_level = "Session" }
  geo_location {
    location          = local.resource_group_location
    failover_priority = 0
  }

  tags = var.tags
}

// ------------------------
// Azure AI Search (S1)
// ------------------------
resource "azurerm_search_service" "srch" {
  name                         = local.search_service_name
  resource_group_name          = local.resource_group_name_effective
  location                     = local.resource_group_location
  sku                          = "standard"    // S1
  replica_count                = 1
  partition_count              = 1
  hosting_mode                 = "Default"
  local_authentication_enabled = false
  tags                         = var.tags
}

// ------------------------
// App Service Plans (Optional)
// ------------------------
resource "azurerm_service_plan" "func" {
  count               = var.create_app_service_plans ? 1 : 0
  name                = local.plan_func_name
  resource_group_name = local.resource_group_name_effective
  location            = local.resource_group_location
  os_type             = "Linux"
  sku_name            = "EP1"         // Functions Premium
  tags                = var.tags
}

resource "azurerm_service_plan" "web" {
  count               = var.create_app_service_plans ? 1 : 0
  name                = local.plan_web_name
  resource_group_name = local.resource_group_name_effective
  location            = local.resource_group_location
  os_type             = "Linux"
  sku_name            = "S3"          // App Service Standard S3
  tags                = var.tags
}

// ------------------------
// Azure AI Services (backing services for Foundry projects)
// ------------------------
resource "azurerm_cognitive_account" "content_safety" {
  name                  = local.cog_cs_name
  resource_group_name   = local.resource_group_name_effective
  location              = local.resource_group_location
  kind                  = "ContentSafety"
  sku_name              = "S0"
  custom_subdomain_name = local.cog_cs_name
  tags                  = var.tags
}

resource "azurerm_cognitive_account" "document_intelligence" {
  name                  = local.cog_di_name
  resource_group_name   = local.resource_group_name_effective
  location              = local.resource_group_location
  kind                  = "FormRecognizer"
  sku_name              = "S0"
  custom_subdomain_name = local.cog_di_name
  tags                  = var.tags
}

resource "azurerm_cognitive_account" "language" {
  name                  = local.cog_lang_name
  resource_group_name   = local.resource_group_name_effective
  location              = local.resource_group_location
  kind                  = "TextAnalytics"
  sku_name              = "S0"
  custom_subdomain_name = local.cog_lang_name
  tags                  = var.tags
}

resource "azurerm_cognitive_account" "speech" {
  name                  = local.cog_spch_name
  resource_group_name   = local.resource_group_name_effective
  location              = local.resource_group_location
  kind                  = "SpeechServices"
  sku_name              = "S0"
  custom_subdomain_name = local.cog_spch_name
  tags                  = var.tags
}

// -------------------------------------------------------------------
// RBAC: Grant Foundry's Managed Identity access (NO secrets required)
// -------------------------------------------------------------------

// Cognitive Services -> Cognitive Services User
resource "azurerm_role_assignment" "foundry_cs_user_content_safety" {
  depends_on          = [azapi_resource.foundry]
  scope                = azurerm_cognitive_account.content_safety.id
  role_definition_name = "Cognitive Services User"
  principal_id         = local.foundry_principal_id
}

resource "azurerm_role_assignment" "foundry_cs_user_document_intelligence" {
  depends_on          = [azapi_resource.foundry]
  scope                = azurerm_cognitive_account.document_intelligence.id
  role_definition_name = "Cognitive Services User"
  principal_id         = local.foundry_principal_id
}

resource "azurerm_role_assignment" "foundry_cs_user_language" {
  depends_on          = [azapi_resource.foundry]
  scope                = azurerm_cognitive_account.language.id
  role_definition_name = "Cognitive Services User"
  principal_id         = local.foundry_principal_id
}

resource "azurerm_role_assignment" "foundry_cs_user_speech" {
  depends_on          = [azapi_resource.foundry]
  scope                = azurerm_cognitive_account.speech.id
  role_definition_name = "Cognitive Services User"
  principal_id         = local.foundry_principal_id
}

// AI Search -> Search Index Data Contributor (read/write index data)
resource "azurerm_role_assignment" "foundry_search_index_contrib" {
  depends_on           = [azapi_resource.foundry]
  scope                = azurerm_search_service.srch.id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = local.foundry_principal_id
}

// AI Search -> Search Service Contributor (create/manage indexes and service)
resource "azurerm_role_assignment" "foundry_search_service_contrib" {
  depends_on           = [azapi_resource.foundry]
  scope                = azurerm_search_service.srch.id
  role_definition_name = "Search Service Contributor"
  principal_id         = local.foundry_principal_id
}

// Storage (Blob) -> Storage Blob Data Contributor
resource "azurerm_role_assignment" "foundry_storage_blob_contrib" {
  depends_on          = [azapi_resource.foundry]
  scope                = azurerm_storage_account.st.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = local.foundry_principal_id
}

// Azure OpenAI -> Cognitive Services User
resource "azurerm_role_assignment" "foundry_openai_user" {
  depends_on           = [azapi_resource.foundry, azapi_resource.openai]
  scope                = azapi_resource.openai.id
  role_definition_name = "Cognitive Services User"
  principal_id         = local.foundry_principal_id
}

// Cosmos DB (NoSQL) -> Cosmos DB Built-in Data Contributor
resource "azurerm_cosmosdb_sql_role_assignment" "foundry_cosmos_data_contrib" {
  depends_on          = [azapi_resource.foundry]
  resource_group_name = local.resource_group_name_effective
  account_name        = azurerm_cosmosdb_account.cos.name
  role_definition_id  = "${azurerm_cosmosdb_account.cos.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = local.foundry_principal_id
  scope               = azurerm_cosmosdb_account.cos.id
}
