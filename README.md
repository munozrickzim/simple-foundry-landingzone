
# Azure Terraform: Foundry-first (creates Foundry + uses its Managed Identity)

This is a micro-landing-zone for setting up a resource group and enough resources to start development on Foundry. This is loosely based on the formal "chat" landing zone published by Microsoft: https://learn.microsoft.com/en-us/azure/architecture/ai-ml/architecture/baseline-microsoft-foundry-landing-zone 

This terraform module  **creates the Foundry resource first** (as a `Microsoft.CognitiveServices/accounts` with `kind = "AIServices"`) **with a system-assigned managed identity**, then provisions your dependencies and **binds RBAC to that identity** — no secrets required.

## What it creates
- Foundry (AIServices) account + **system-assigned identity** (AzAPI)
- Storage Account (V2, LRS)
- Azure Monitor: Log Analytics + Application Insights
- Key Vault (no secrets needed for Foundry)
- Cosmos DB (Core/NoSQL)
- Azure AI Search (S1)
- App Service Plans (optional): Functions Premium EP1 & App Service S3 (Linux) - Default is NOT to create them (lowest cost option)
- Azure AI Services: Content Safety, Document Intelligence, Language, Speech
- RBAC so the **Foundry identity** can access Search, Storage, Cosmos, and the four AI services

## Why AzAPI for Foundry?
The Foundry resource is an Azure Cognitive Services account of kind **AIServices**. The `azurerm_cognitive_account` resource may not yet expose this kind, so we use **AzAPI** to call the ARM/Resource Provider directly.

## Quick start (Cloud Shell)
```bash
terraform init
terraform plan -out tf.plan
terraform apply tf.plan
```

After apply, in **Azure AI Foundry → Project → AI Services → Add**, select the four services. RBAC is already granted to the Foundry identity.

## Inputs
See `variables.tf`. Minimal inputs in `terraform.tfvars`:
```hcl
resource_group_name      = "rg-mlapps-dev"
name_prefix              = "contoso"
environment              = "dev"
location                 = "eastus"
foundry_sku_name         = "S0"                  # default
create_app_service_plans = true                  # default; set to false to skip App Service Plans
```

## Notes
- This requires Owner or Contributor role for the target subscription
- The easiest way to deploy this is using Azure Cloud Shell (terraform already installed)
- Names follow service-specific constraints (storage/cosmos no hyphens; others allow hyphens)
- The `depends_on` on role assignments ensures they **wait for the Foundry identity** to exist before binding RBAC
- You can later add Diagnostic Settings and Private Endpoints as needed
- This does not deploy any Models (as that's up to you)