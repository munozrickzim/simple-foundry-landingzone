
# Azure Terraform: Foundry-first (creates Foundry + uses its Managed Identity)

This is a micro-landing-zone for setting up a resource group and enough resources to start development on Foundry. This is loosely based on the formal "chat" landing zone published by Microsoft: https://learn.microsoft.com/en-us/azure/architecture/ai-ml/architecture/baseline-microsoft-foundry-landing-zone 

This terraform module  **creates the Foundry resource first** (as a `Microsoft.CognitiveServices/accounts` with `kind = "AIServices"`) **with a system-assigned managed identity**, then provisions your dependencies and **binds RBAC to that identity** — no secrets required.

## What it creates
- Foundry (AIServices) account + **system-assigned identity** (AzAPI)
- Azure OpenAI Service + **system-assigned identity** (AzAPI)
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
workload                 = "contoso"             # letters only, creates unique resource names
environment              = "dev"                 # must be: dev, test, stage, or prod
location                 = "eastus"              # Azure region (validated against supported regions)
foundry_sku_name         = "S0"                  # default
openai_sku_name          = "S0"                  # default
create_app_service_plans = false                 # default; set to true to create App Service Plans
```

**Important:** The `workload` name becomes part of all resource names, including the resource group. Choose a unique workload name to avoid conflicts with existing resources in your subscription. For example:
- `workload = "contoso"` creates resource group: `rg-dev-eastus-contoso-1`
- `workload = "fabrikam"` creates resource group: `rg-dev-eastus-fabrikam-1`

## Naming Convention
Resource names follow the pattern:
- **With hyphens**: `{abbreviation}-{env}-{region}-{workload}-{instance}` (e.g., `oai-dev-eastus-contoso-1`)
- **Without hyphens**: `{abbreviation}{env}{region}{workload}{instance}` (e.g., `stdeveastuscontoso1`)

Region abbreviations are based on Azure's standard short names (e.g., eastus, westus2, etc.). Resource type abbreviations follow Microsoft Cloud Adoption Framework conventions.

## Notes
- This requires Owner or Contributor role for the target subscription
- The easiest way to deploy this is using Azure Cloud Shell (terraform already installed)
- Names follow service-specific constraints (storage/cosmos use no hyphens; others use hyphens)
- The `depends_on` on role assignments ensures they **wait for the Foundry identity** to exist before binding RBAC
- You can later add Diagnostic Settings and Private Endpoints as needed
- This does not deploy any Models (as that's up to you)
- All resource abbreviations and region mappings are defined in `abbreviations.tf`