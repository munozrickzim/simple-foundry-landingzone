
output "foundry_account_name" {
  description = "Foundry (AIServices) account name."
  value       = azapi_resource.foundry.name
}

output "foundry_principal_id" {
  description = "System-assigned Managed Identity principalId of the Foundry account."
  value       = azapi_resource.foundry.identity[0].principal_id
}

output "ai_services" {
  value = {
    content_safety        = azurerm_cognitive_account.content_safety.name
    document_intelligence = azurerm_cognitive_account.document_intelligence.name
    language              = azurerm_cognitive_account.language.name
    speech                = azurerm_cognitive_account.speech.name
  }
}

output "data_plane_resources" {
  value = {
    storage_account = azurerm_storage_account.st.name
    search_service  = azurerm_search_service.srch.name
    cosmosdb        = azurerm_cosmosdb_account.cos.name
  }
}

output "app_service_plans" {
  description = "App Service Plan names (if created)."
  value = {
    functions_plan = length(azurerm_service_plan.func) > 0 ? azurerm_service_plan.func[0].name : null
    web_plan       = length(azurerm_service_plan.web) > 0 ? azurerm_service_plan.web[0].name : null
  }
}
