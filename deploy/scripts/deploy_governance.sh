#!/bin/bash

# Deploy Governance Policies
# Deploys Azure Policy definitions and initiative to subscription
# Part of Phase 4: Governance Integration

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/../terraform/run/governance"

# Default values
ENVIRONMENT="dev"
ACTION="deploy"
AUTO_APPROVE=false
ASSIGN_TO_SUBSCRIPTION=true

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy Azure Governance Policies

OPTIONS:
    -e, --environment ENV       Environment (dev|uat|prod) [default: dev]
    -a, --action ACTION         Action (deploy|destroy|validate) [default: deploy]
    --auto-approve              Skip approval prompts
    --no-subscription-assign    Don't assign policies to subscription
    -h, --help                  Display this help message

EXAMPLES:
    # Deploy governance policies to dev
    $0 -e dev

    # Deploy to production with auto-approve
    $0 -e prod --auto-approve

    # Validate policies without deploying
    $0 -e prod -a validate

    # Destroy governance policies
    $0 -e dev -a destroy

DESCRIPTION:
    This script deploys Azure Policy definitions and initiative for VM governance:
    - Encryption at host requirement
    - Mandatory tags (Environment, CostCenter, Owner, Application)
    - Naming convention enforcement
    - Azure Backup requirement
    - VM SKU size restrictions

    Policies are deployed to the subscription and can be assigned automatically.

EOF
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -a|--action)
            ACTION="$2"
            shift 2
            ;;
        --auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        --no-subscription-assign)
            ASSIGN_TO_SUBSCRIPTION=false
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|uat|prod)$ ]]; then
    log_error "Invalid environment: $ENVIRONMENT. Must be dev, uat, or prod"
    exit 1
fi

# Validate action
if [[ ! "$ACTION" =~ ^(deploy|destroy|validate)$ ]]; then
    log_error "Invalid action: $ACTION. Must be deploy, destroy, or validate"
    exit 1
fi

log_info "=============================================="
log_info "Governance Deployment Script"
log_info "=============================================="
log_info "Environment: $ENVIRONMENT"
log_info "Action: $ACTION"
log_info "Auto-approve: $AUTO_APPROVE"
log_info "Assign to subscription: $ASSIGN_TO_SUBSCRIPTION"
log_info "=============================================="

# Check prerequisites
log_info "Checking prerequisites..."

# Check Azure CLI
if ! command -v az &> /dev/null; then
    log_error "Azure CLI not found. Please install it first."
    exit 1
fi

# Check Terraform
if ! command -v terraform &> /dev/null; then
    log_error "Terraform not found. Please install it first."
    exit 1
fi

# Check Azure authentication
if ! az account show &> /dev/null; then
    log_error "Not logged in to Azure. Run 'az login' first."
    exit 1
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
log_info "Using subscription: $SUBSCRIPTION_ID"

# Navigate to Terraform directory
cd "$TERRAFORM_DIR"

log_info "Working directory: $(pwd)"

# Create tfvars file for environment
TFVARS_FILE="$ENVIRONMENT.tfvars"

log_info "Creating tfvars file: $TFVARS_FILE"

# Policy effects based on environment
if [ "$ENVIRONMENT" == "prod" ]; then
    ENCRYPTION_EFFECT="Deny"
    TAGS_EFFECT="Deny"
    NAMING_EFFECT="Deny"
    BACKUP_EFFECT="Deny"
    SKU_EFFECT="Deny"
else
    ENCRYPTION_EFFECT="Audit"
    TAGS_EFFECT="Audit"
    NAMING_EFFECT="Audit"
    BACKUP_EFFECT="Audit"
    SKU_EFFECT="Audit"
fi

cat > "$TFVARS_FILE" << EOF
# Governance policies configuration for $ENVIRONMENT

assign_to_subscription = $ASSIGN_TO_SUBSCRIPTION
location              = "eastus"

# Policy effects (Audit for dev/uat, Deny for prod)
encryption_effect = "$ENCRYPTION_EFFECT"
tags_effect       = "$TAGS_EFFECT"
naming_effect     = "$NAMING_EFFECT"
backup_effect     = "$BACKUP_EFFECT"
sku_effect        = "$SKU_EFFECT"

# Naming pattern (environment-based)
naming_pattern = "^($ENVIRONMENT)-vm-[a-z0-9]+-[a-z]+-[0-9]{3}$"

# Allowed VM SKUs
allowed_skus = [
  "Standard_B2s",
  "Standard_B2ms",
  "Standard_D2s_v3",
  "Standard_D4s_v3",
  "Standard_D8s_v3",
  "Standard_E2s_v3",
  "Standard_E4s_v3",
  "Standard_F2s_v2",
  "Standard_F4s_v2"
]
EOF

log_info "Terraform variables configured"

# Initialize Terraform
log_info "Initializing Terraform..."
terraform init

# Validate Terraform configuration
log_info "Validating Terraform configuration..."
terraform validate

if [ $? -ne 0 ]; then
    log_error "Terraform validation failed"
    exit 1
fi

log_info "Terraform validation passed"

# If validate action, stop here
if [ "$ACTION" == "validate" ]; then
    log_info "Validation complete. Exiting."
    exit 0
fi

# Terraform plan
log_info "Running Terraform plan..."

if [ "$ACTION" == "destroy" ]; then
    terraform plan -destroy -var-file="$TFVARS_FILE" -out=tfplan
else
    terraform plan -var-file="$TFVARS_FILE" -out=tfplan
fi

if [ $? -ne 0 ]; then
    log_error "Terraform plan failed"
    exit 1
fi

log_info "Terraform plan completed successfully"

# Show plan summary
log_info "=============================================="
log_info "Plan Summary:"
terraform show -json tfplan | jq -r '.resource_changes[] | "\(.change.actions[0]) \(.type) \(.name)"' 2>/dev/null || true
log_info "=============================================="

# Approval prompt
if [ "$AUTO_APPROVE" == false ]; then
    if [ "$ACTION" == "destroy" ]; then
        log_warn "⚠️  WARNING: You are about to DESTROY governance policies ⚠️"
        log_warn "This will remove all policy definitions and assignments"
    fi
    
    echo -n "Do you want to proceed with $ACTION? (yes/no): "
    read -r APPROVAL
    
    if [[ ! "$APPROVAL" =~ ^[Yy][Ee][Ss]$ ]]; then
        log_warn "Operation cancelled by user"
        exit 0
    fi
fi

# Apply Terraform
log_info "Applying Terraform changes..."

if [ "$AUTO_APPROVE" == true ]; then
    terraform apply -auto-approve tfplan
else
    terraform apply tfplan
fi

if [ $? -ne 0 ]; then
    log_error "Terraform apply failed"
    exit 1
fi

log_info "=============================================="
log_info "Governance deployment completed successfully!"
log_info "=============================================="

# Display outputs
if [ "$ACTION" == "deploy" ]; then
    log_info "Policy Definitions:"
    az policy definition list --query "[?policyType=='Custom'].{Name:name, DisplayName:displayName}" -o table
    
    log_info ""
    log_info "Policy Initiatives:"
    az policy set-definition list --query "[?policyType=='Custom'].{Name:name, DisplayName:displayName}" -o table
    
    if [ "$ASSIGN_TO_SUBSCRIPTION" == true ]; then
        log_info ""
        log_info "Policy Assignments:"
        az policy assignment list --query "[].{Name:name, DisplayName:displayName, Scope:scope}" -o table
    fi
fi

# Create deployment record
DEPLOYMENT_RECORD="${SCRIPT_DIR}/../docs/deployments/governance-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S).md"
mkdir -p "$(dirname "$DEPLOYMENT_RECORD")"

cat > "$DEPLOYMENT_RECORD" << EOF
# Governance Deployment Record

**Deployment ID**: governance-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S)
**Environment**: $ENVIRONMENT
**Action**: $ACTION
**Timestamp**: $(date -Iseconds)
**Subscription**: $SUBSCRIPTION_ID

## Configuration

- **Encryption Effect**: $ENCRYPTION_EFFECT
- **Tags Effect**: $TAGS_EFFECT
- **Naming Effect**: $NAMING_EFFECT
- **Backup Effect**: $BACKUP_EFFECT
- **SKU Effect**: $SKU_EFFECT
- **Assigned to Subscription**: $ASSIGN_TO_SUBSCRIPTION

## Policies Deployed

1. Require Encryption at Host ($ENCRYPTION_EFFECT)
2. Require Mandatory Tags ($TAGS_EFFECT)
3. Enforce Naming Convention ($NAMING_EFFECT)
4. Require Azure Backup ($BACKUP_EFFECT)
5. Restrict VM SKU Sizes ($SKU_EFFECT)

## Policy Initiative

- VM Governance Initiative (combines all 5 policies)

## Status

✅ Deployment completed successfully

---
*Auto-generated deployment record*
EOF

log_info "Deployment record created: $DEPLOYMENT_RECORD"

log_info "=============================================="
log_info "Governance deployment script completed!"
log_info "=============================================="

exit 0
