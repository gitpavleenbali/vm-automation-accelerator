# Production Backend Configuration
# Usage: terraform init -backend-config="backend-config/prod.hcl"

resource_group_name  = "rg-terraform-state-prod"
storage_account_name = "stuniptertfstateprod"
container_name       = "tfstate"
key                  = "vm-automation/prod/terraform.tfstate"
use_azuread_auth     = true
