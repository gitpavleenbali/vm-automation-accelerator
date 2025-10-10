# Backend configuration for UAT environment
# Usage: terraform init -backend-config=backend-config/uat.hcl

resource_group_name  = "rg-terraform-state-uat"
storage_account_name = "sttfstateuat001"  # Must be globally unique - update this
container_name       = "tfstate"
key                  = "vm-automation-uat.tfstate"
