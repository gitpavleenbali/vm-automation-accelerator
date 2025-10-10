# Development Backend Configuration
# Usage: terraform init -backend-config="backend-config/dev.hcl"

resource_group_name  = "rg-terraform-state-dev"
storage_account_name = "stuniptertfstatedev"
container_name       = "tfstate"
key                  = "vm-automation/dev/terraform.tfstate"
use_azuread_auth     = true
