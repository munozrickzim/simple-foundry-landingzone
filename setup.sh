
#!/usr/bin/env bash
set -euo pipefail

echo "[1/4] Verifying Azure login/subscription..."
az account show >/dev/null || az login

echo "[2/4] Initializing Terraform..."
terraform init

echo "[3/4] Planning..."
terraform plan -out tf.plan

echo "[4/4] Applying..."
terraform apply tf.plan

echo "Done. Next: In Azure AI Foundry → Project → AI Services → Add the four services."
