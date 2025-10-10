#!/bin/bash

################################################################################
# Migrate State to Remote Backend Script
# 
# Purpose: Migrate Terraform state from local backend (bootstrap) to remote
#          backend (Azure Storage Account) for production use. This enables
#          team collaboration, state locking, and centralized state management.
#
# Usage: ./migrate_state_to_remote.sh -m <module> [options]
#
# Prerequisites:
#   1. Bootstrap control plane deployed (local state exists)
#   2. Run control plane deployed (remote backend configured)
#   3. Azure CLI authenticated (az login)
#   4. Terraform >= 1.5.0 installed
#
# Supported Modules:
#   - control-plane: Migrate bootstrap control plane to remote backend
#   - workload-zone: Migrate workload zone to remote backend
#   - vm-deployment: Migrate VM deployment to remote backend
#
################################################################################

set -euo pipefail

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source helper functions
if [[ -f "${SCRIPT_DIR}/helpers/vm_helpers.sh" ]]; then
    source "${SCRIPT_DIR}/helpers/vm_helpers.sh"
else
    echo "ERROR: Cannot find vm_helpers.sh in ${SCRIPT_DIR}/helpers/"
    exit 1
fi

################################################################################
# Variables
################################################################################

MODULE=""
ENVIRONMENT=""
REGION=""
WORKLOAD_NAME=""
SUBSCRIPTION_ID=""
BACKUP_STATE=true
AUTO_APPROVE=false
CONFIG_DIR="${PROJECT_ROOT}/.vm_deployment_automation"

################################################################################
# Functions
################################################################################

function usage() {
    cat << EOF
Usage: $(basename "$0") -m <module> [options]

Migrate Terraform state from local to remote backend (Azure Storage).

Required Arguments:
  -m, --module MODULE          Module to migrate (control-plane, workload-zone, vm-deployment)

Optional Arguments (for workload-zone and vm-deployment):
  -e, --environment ENV        Environment name (dev, uat, prod)
  -r, --region REGION         Azure region (eastus, westeurope, etc.)
  -n, --name WORKLOAD         Workload name (required for vm-deployment)

Optional Arguments (all modules):
  -s, --subscription ID       Azure subscription ID (default: current)
  --no-backup                 Skip state backup (not recommended)
  -y, --auto-approve          Skip interactive approval
  -h, --help                  Show this help message

Examples:
  # Migrate control plane from bootstrap to run
  $(basename "$0") -m control-plane

  # Migrate workload zone
  $(basename "$0") -m workload-zone -e dev -r eastus

  # Migrate VM deployment
  $(basename "$0") -m vm-deployment -e dev -r eastus -n web

  # Auto-approve migration
  $(basename "$0") -m control-plane -y

Migration Process:
  1. Validates prerequisites (source and target backends)
  2. Backs up current local state
  3. Initializes remote backend configuration
  4. Migrates state using 'terraform init -migrate-state'
  5. Verifies migration success
  6. Cleans up local state files (optional)

EOF
    exit 0
}

function validate_prerequisites() {
    print_banner "Validating Prerequisites"
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform not found. Please install Terraform >= 1.5.0"
        exit 1
    fi
    
    local tf_version
    tf_version=$(terraform version -json | jq -r '.terraform_version')
    print_info "Terraform version: ${tf_version}"
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI not found. Please install Azure CLI"
        exit 1
    fi
    
    # Check Azure authentication
    if ! az account show &> /dev/null; then
        print_error "Not authenticated to Azure. Please run 'az login'"
        exit 1
    fi
    
    # Get current subscription if not provided
    if [[ -z "${SUBSCRIPTION_ID}" ]]; then
        SUBSCRIPTION_ID=$(az account show --query id -o tsv)
        print_info "Using current subscription: ${SUBSCRIPTION_ID}"
    else
        az account set --subscription "${SUBSCRIPTION_ID}"
        print_info "Switched to subscription: ${SUBSCRIPTION_ID}"
    fi
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        print_error "jq not found. Please install jq for JSON parsing"
        exit 1
    fi
    
    print_success "All prerequisites validated"
}

function validate_inputs() {
    print_banner "Validating Inputs"
    
    # Validate module
    if [[ -z "${MODULE}" ]]; then
        print_error "Module (-m) is required"
        usage
    fi
    
    case "${MODULE}" in
        control-plane)
            print_info "Migrating control plane module"
            ;;
        workload-zone)
            print_info "Migrating workload zone module"
            if [[ -z "${ENVIRONMENT}" || -z "${REGION}" ]]; then
                print_error "Environment (-e) and Region (-r) are required for workload-zone"
                usage
            fi
            ;;
        vm-deployment)
            print_info "Migrating VM deployment module"
            if [[ -z "${ENVIRONMENT}" || -z "${REGION}" || -z "${WORKLOAD_NAME}" ]]; then
                print_error "Environment (-e), Region (-r), and Workload Name (-n) are required for vm-deployment"
                usage
            fi
            ;;
        *)
            print_error "Invalid module: ${MODULE}"
            print_info "Valid modules: control-plane, workload-zone, vm-deployment"
            exit 1
            ;;
    esac
    
    print_success "All inputs validated"
}

function get_module_path() {
    local module_type="$1"
    
    case "${module_type}" in
        control-plane)
            echo "${PROJECT_ROOT}/deploy/terraform/bootstrap/control-plane"
            ;;
        workload-zone)
            echo "${PROJECT_ROOT}/deploy/terraform/run/workload-zone"
            ;;
        vm-deployment)
            echo "${PROJECT_ROOT}/deploy/terraform/run/vm-deployment"
            ;;
        *)
            print_error "Unknown module type: ${module_type}"
            exit 1
            ;;
    esac
}

function get_state_key() {
    local module_type="$1"
    
    case "${module_type}" in
        control-plane)
            echo "control-plane.tfstate"
            ;;
        workload-zone)
            echo "workload-zone-${ENVIRONMENT}-${REGION}.tfstate"
            ;;
        vm-deployment)
            echo "vm-deployment-${ENVIRONMENT}-${REGION}-${WORKLOAD_NAME}.tfstate"
            ;;
        *)
            print_error "Unknown module type: ${module_type}"
            exit 1
            ;;
    esac
}

function verify_local_state() {
    print_banner "Verifying Local State"
    
    local module_path
    module_path=$(get_module_path "${MODULE}")
    
    local state_file="${module_path}/terraform.tfstate"
    
    if [[ ! -f "${state_file}" ]]; then
        print_error "Local state file not found: ${state_file}"
        print_info "Module may not be deployed or already migrated"
        exit 1
    fi
    
    # Check if state is empty
    local resource_count
    resource_count=$(jq '.resources | length' "${state_file}")
    
    if [[ ${resource_count} -eq 0 ]]; then
        print_warning "Local state file is empty (no resources)"
        print_info "Nothing to migrate"
        exit 0
    fi
    
    print_info "Found local state with ${resource_count} resources"
    print_success "Local state verified"
}

function get_backend_config() {
    print_banner "Getting Backend Configuration"
    
    # Read control plane state for backend info
    local control_plane_state="${PROJECT_ROOT}/deploy/terraform/bootstrap/control-plane/terraform.tfstate"
    
    if [[ ! -f "${control_plane_state}" ]]; then
        print_error "Control plane state not found: ${control_plane_state}"
        print_info "Please deploy control plane first"
        exit 1
    fi
    
    # Extract backend configuration
    local storage_account
    local container_name
    local resource_group
    local state_key
    
    storage_account=$(jq -r '.outputs.state_storage_account_name.value // empty' "${control_plane_state}")
    container_name=$(jq -r '.outputs.state_container_name.value // "tfstate"' "${control_plane_state}")
    resource_group=$(jq -r '.outputs.control_plane_resource_group_name.value // empty' "${control_plane_state}")
    state_key=$(get_state_key "${MODULE}")
    
    if [[ -z "${storage_account}" ]]; then
        print_error "Could not extract storage account from control plane state"
        exit 1
    fi
    
    if [[ -z "${resource_group}" ]]; then
        print_error "Could not extract resource group from control plane state"
        exit 1
    fi
    
    print_info "Storage Account: ${storage_account}"
    print_info "Container: ${container_name}"
    print_info "Resource Group: ${resource_group}"
    print_info "State Key: ${state_key}"
    
    # Verify storage account exists
    if ! az storage account show --name "${storage_account}" --resource-group "${resource_group}" &> /dev/null; then
        print_error "Storage account '${storage_account}' not found in resource group '${resource_group}'"
        exit 1
    fi
    
    print_success "Backend configuration retrieved"
    
    # Return values via global variables
    BACKEND_STORAGE_ACCOUNT="${storage_account}"
    BACKEND_CONTAINER="${container_name}"
    BACKEND_RESOURCE_GROUP="${resource_group}"
    BACKEND_STATE_KEY="${state_key}"
}

function backup_local_state() {
    if [[ "${BACKUP_STATE}" != "true" ]]; then
        print_warning "Skipping state backup (--no-backup specified)"
        return
    fi
    
    print_banner "Backing Up Local State"
    
    local module_path
    module_path=$(get_module_path "${MODULE}")
    
    local state_file="${module_path}/terraform.tfstate"
    local backup_dir="${module_path}/.state-backups"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${backup_dir}/terraform.tfstate.backup.${timestamp}"
    
    # Create backup directory
    mkdir -p "${backup_dir}"
    
    # Copy state file
    cp "${state_file}" "${backup_file}"
    
    print_success "State backed up to: ${backup_file}"
    
    # Also backup .terraform directory
    if [[ -d "${module_path}/.terraform" ]]; then
        local terraform_backup="${backup_dir}/.terraform.backup.${timestamp}"
        cp -r "${module_path}/.terraform" "${terraform_backup}"
        print_success "Terraform directory backed up to: ${terraform_backup}"
    fi
}

function create_backend_config_file() {
    print_banner "Creating Backend Configuration"
    
    local module_path
    module_path=$(get_module_path "${MODULE}")
    
    local backend_config_file="${module_path}/backend.tfbackend"
    
    cat > "${backend_config_file}" << EOF
resource_group_name  = "${BACKEND_RESOURCE_GROUP}"
storage_account_name = "${BACKEND_STORAGE_ACCOUNT}"
container_name       = "${BACKEND_CONTAINER}"
key                  = "${BACKEND_STATE_KEY}"
EOF
    
    print_success "Backend configuration file created: ${backend_config_file}"
    
    # Display configuration
    echo ""
    print_info "Backend Configuration:"
    cat "${backend_config_file}" | sed 's/^/  /'
    echo ""
}

function update_backend_block() {
    print_banner "Updating Backend Block"
    
    local module_path
    module_path=$(get_module_path "${MODULE}")
    
    local versions_file="${module_path}/versions.tf"
    
    if [[ ! -f "${versions_file}" ]]; then
        print_warning "versions.tf not found, creating new file"
        versions_file="${module_path}/backend.tf"
    fi
    
    # Check if backend block already exists
    if grep -q "backend \"azurerm\"" "${versions_file}" 2>/dev/null; then
        print_info "Backend block already exists in ${versions_file}"
    else
        print_info "Adding backend block to ${versions_file}"
        
        # Backup original file
        cp "${versions_file}" "${versions_file}.backup"
        
        # Add backend block (this is a simplified version, adjust as needed)
        cat >> "${versions_file}" << 'EOF'

# Remote state backend configuration
terraform {
  backend "azurerm" {
    # Configuration provided via backend.tfbackend file
    # during terraform init -backend-config=backend.tfbackend
  }
}
EOF
        
        print_success "Backend block added to ${versions_file}"
    fi
}

function migrate_state() {
    print_banner "Migrating State to Remote Backend"
    
    local module_path
    module_path=$(get_module_path "${MODULE}")
    
    cd "${module_path}"
    
    # Confirm migration
    if [[ "${AUTO_APPROVE}" != "true" ]]; then
        echo ""
        print_warning "About to migrate state from local to remote backend"
        print_warning "This will:"
        echo "  1. Upload local state to Azure Storage: ${BACKEND_STORAGE_ACCOUNT}/${BACKEND_CONTAINER}/${BACKEND_STATE_KEY}"
        echo "  2. Configure Terraform to use remote backend"
        echo "  3. Remove local state files (after successful migration)"
        echo ""
        read -p "Do you want to proceed? (yes/no): " confirm
        if [[ "${confirm}" != "yes" ]]; then
            print_info "Migration cancelled by user"
            exit 0
        fi
    fi
    
    # Run terraform init with migrate-state
    print_info "Running terraform init -migrate-state..."
    echo ""
    
    if terraform init -backend-config=backend.tfbackend -migrate-state -force-copy; then
        print_success "State migration completed successfully"
    else
        print_error "State migration failed"
        print_info "Local state backup available in: ${module_path}/.state-backups/"
        exit 1
    fi
}

function verify_migration() {
    print_banner "Verifying Migration"
    
    local module_path
    module_path=$(get_module_path "${MODULE}")
    
    cd "${module_path}"
    
    # Run terraform state list to verify
    print_info "Verifying remote state..."
    
    local resource_count
    resource_count=$(terraform state list 2>/dev/null | wc -l)
    
    if [[ ${resource_count} -gt 0 ]]; then
        print_success "Remote state verified: ${resource_count} resources found"
    else
        print_error "Remote state verification failed: no resources found"
        exit 1
    fi
    
    # Check if local state file is gone or updated
    if [[ -f "${module_path}/terraform.tfstate" ]]; then
        local backend_type
        backend_type=$(jq -r '.backend.type // "local"' "${module_path}/terraform.tfstate")
        
        if [[ "${backend_type}" == "azurerm" ]]; then
            print_success "Local state file updated to use azurerm backend"
        else
            print_warning "Local state file still exists (backend type: ${backend_type})"
        fi
    fi
    
    print_success "Migration verification completed"
}

function cleanup_local_state() {
    print_banner "Cleaning Up Local State"
    
    local module_path
    module_path=$(get_module_path "${MODULE}")
    
    # Ask user if they want to delete local state files
    if [[ "${AUTO_APPROVE}" != "true" ]]; then
        echo ""
        print_warning "Local state files are no longer needed after successful migration"
        print_info "Backup is available in: ${module_path}/.state-backups/"
        read -p "Do you want to delete local state files? (yes/no): " confirm
        if [[ "${confirm}" != "yes" ]]; then
            print_info "Local state files kept"
            return
        fi
    fi
    
    # Remove local state files
    if [[ -f "${module_path}/terraform.tfstate" ]]; then
        rm -f "${module_path}/terraform.tfstate"
        print_success "Removed terraform.tfstate"
    fi
    
    if [[ -f "${module_path}/terraform.tfstate.backup" ]]; then
        rm -f "${module_path}/terraform.tfstate.backup"
        print_success "Removed terraform.tfstate.backup"
    fi
    
    print_success "Local state cleanup completed"
}

function main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--module)
                MODULE="$2"
                shift 2
                ;;
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -r|--region)
                REGION="$2"
                shift 2
                ;;
            -n|--name)
                WORKLOAD_NAME="$2"
                shift 2
                ;;
            -s|--subscription)
                SUBSCRIPTION_ID="$2"
                shift 2
                ;;
            --no-backup)
                BACKUP_STATE=false
                shift
                ;;
            -y|--auto-approve)
                AUTO_APPROVE=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    # Print header
    print_header "State Migration to Remote Backend"
    
    # Execute migration steps
    validate_prerequisites
    validate_inputs
    verify_local_state
    get_backend_config
    backup_local_state
    create_backend_config_file
    update_backend_block
    migrate_state
    verify_migration
    cleanup_local_state
    
    # Print completion message
    echo ""
    print_success "======================================"
    print_success "State Migration Completed Successfully"
    print_success "======================================"
    echo ""
    print_info "Module: ${MODULE}"
    print_info "Backend: Azure Storage (${BACKEND_STORAGE_ACCOUNT})"
    print_info "State Key: ${BACKEND_STATE_KEY}"
    echo ""
    print_info "Next Steps:"
    echo "  1. Verify state in Azure Portal: Storage Account > ${BACKEND_STORAGE_ACCOUNT} > Containers > ${BACKEND_CONTAINER}"
    echo "  2. Team members can now use the same remote state"
    echo "  3. State locking is automatically enabled (Azure Storage lease)"
    echo "  4. Local state backup available in: $(get_module_path "${MODULE}")/.state-backups/"
    echo ""
}

# Run main function
main "$@"
