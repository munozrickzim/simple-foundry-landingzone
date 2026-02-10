
// Current tenant info (used by Key Vault)
data "azurerm_client_config" "current" {}

locals {
  prefix = lower(var.name_prefix)
  env    = lower(var.environment)

  base_hyphen = "${local.prefix}-${local.env}"
  base_nodash = "${local.prefix}${local.env}"

  suffix = {
    rg    = "rg"
    st    = "st"
    law   = "law"
    appi  = "appi"
    kv    = "kv"
    cos   = "cos"
    srch  = "srch"
    asp   = "asp"
    aspfn = "aspfn"
    aif   = "aif"   // Foundry (AIServices) account
    cs    = "cs"    // Content Safety
    di    = "di"    // Document Intelligence
    lang  = "lang"  // Language
    spch  = "spch"  // Speech
  }

  // Names per resource constraints
  storage_account_name = substr("${local.base_nodash}${local.suffix.st}", 0, 24)
  key_vault_name       = substr("${local.base_hyphen}-${local.suffix.kv}", 0, 24)
  cosmos_account_name  = substr("${local.base_nodash}${local.suffix.cos}", 0, 44)
  search_service_name  = substr("${local.base_hyphen}-${local.suffix.srch}", 0, 60)

  appi_name = "${local.base_hyphen}-${local.suffix.appi}"
  law_name  = "${local.base_hyphen}-${local.suffix.law}"

  plan_func_name = "${local.base_hyphen}-${local.suffix.aspfn}"
  plan_web_name  = "${local.base_hyphen}-${local.suffix.asp}"

  // Cognitive Services: prefer lowercase, no hyphens
  cog_cs_name   = substr("${local.base_nodash}${local.suffix.cs}",   0, 64)
  cog_di_name   = substr("${local.base_nodash}${local.suffix.di}",   0, 64)
  cog_lang_name = substr("${local.base_nodash}${local.suffix.lang}", 0, 64)
  cog_spch_name = substr("${local.base_nodash}${local.suffix.spch}", 0, 64)

  // Foundry (AIServices) account allows hyphens
  foundry_name  = "${local.base_hyphen}-${local.suffix.aif}"
}

// ------------------------
// Resource Group
// ------------------------
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = merge(var.tags, { env = local.env, prefix = local.prefix, role = "landing" })
}

// ------------------------
// Foundry (AIServices) account with System-Assigned Managed Identity
// ------------------------
resource "azapi_resource" "foundry" {
  type      = "Microsoft.CognitiveServices/accounts@2025-09-01"
  name      = local.foundry_name
  location  = azurerm_resource_group.rg.location
  parent_id = azurerm_resource_group.rg.id

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
// Storage Account (V2, LRS)
// ------------------------
resource "azurerm_storage_account" "st" {
  name                            = local.storage_account_name
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
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
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_application_insights" "appi" {
  name                = local.appi_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.law.id
  tags                = var.tags
}

// ------------------------
// Key Vault (present, but no secrets needed for Foundry MI)
// ------------------------
resource "azurerm_key_vault" "kv" {
  name                       = local.key_vault_name
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
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
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  offer_type                    = "Standard"
  kind                          = "GlobalDocumentDB"
  local_authentication_disabled = true

  consistency_policy { consistency_level = "Session" }
  geo_location {
    location          = azurerm_resource_group.rg.location
    failover_priority = 0
  }

  tags = var.tags
}

// ------------------------
// Azure AI Search (S1)
// ------------------------
resource "azurerm_search_service" "srch" {
  name                         = local.search_service_name
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
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
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "EP1"         // Functions Premium
  tags                = var.tags
}

resource "azurerm_service_plan" "web" {
  count               = var.create_app_service_plans ? 1 : 0
  name                = local.plan_web_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "S3"          // App Service Standard S3
  tags                = var.tags
}

// ------------------------
// Azure AI Services (backing services for Foundry projects)
// ------------------------
resource "azurerm_cognitive_account" "content_safety" {
  name                  = local.cog_cs_name
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  kind                  = "ContentSafety"
  sku_name              = "S0"
  custom_subdomain_name = local.cog_cs_name
  tags                  = var.tags
}

resource "azurerm_cognitive_account" "document_intelligence" {
  name                  = local.cog_di_name
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  kind                  = "FormRecognizer"
  sku_name              = "S0"
  custom_subdomain_name = local.cog_di_name
  tags                  = var.tags
}

resource "azurerm_cognitive_account" "language" {
  name                  = local.cog_lang_name
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  kind                  = "TextAnalytics"
  sku_name              = "S0"
  custom_subdomain_name = local.cog_lang_name
  tags                  = var.tags
}

resource "azurerm_cognitive_account" "speech" {
  name                  = local.cog_spch_name
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
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

// AI Search -> Search Index Data Contributor
resource "azurerm_role_assignment" "foundry_search_index_contrib" {
  depends_on          = [azapi_resource.foundry]
  scope                = azurerm_search_service.srch.id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = local.foundry_principal_id
}

// Storage (Blob) -> Storage Blob Data Contributor
resource "azurerm_role_assignment" "foundry_storage_blob_contrib" {
  depends_on          = [azapi_resource.foundry]
  scope                = azurerm_storage_account.st.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = local.foundry_principal_id
}

// Cosmos DB (NoSQL) -> Cosmos DB Built-in Data Contributor
resource "azurerm_cosmosdb_sql_role_assignment" "foundry_cosmos_data_contrib" {
  depends_on          = [azapi_resource.foundry]
  resource_group_name = azurerm_resource_group.rg.name
  account_name        = azurerm_cosmosdb_account.cos.name
  role_definition_id  = "${azurerm_cosmosdb_account.cos.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = local.foundry_principal_id
  scope               = azurerm_cosmosdb_account.cos.id
}
