#!/bin/bash

################################################################################
# Deploy Workload Zone Script
# 
# Purpose: Deploy network infrastructure (VNet, subnets, NSGs, routes) for a 
#          specific environment using remote state backend configured by the
#          control plane.
#
# Usage: ./deploy_workload_zone.sh -e <environment> -r <region> [options]
#
# Prerequisites:
#   1. Control plane must be deployed first (deploy_control_plane.sh)
#   2. Azure CLI authenticated (az login)
#   3. Terraform >= 1.5.0 installed
#   4. Workspace configuration in boilerplate/WORKSPACES/WORKLOAD-ZONE/
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

ENVIRONMENT=""
REGION=""
PROJECT_CODE=""
SUBSCRIPTION_ID=""
CONTROL_PLANE_RG=""
DRY_RUN=false
AUTO_APPROVE=false
DESTROY=false
WORKSPACE_PATH=""
TERRAFORM_MODULE_PATH="${PROJECT_ROOT}/deploy/terraform/run/workload-zone"
CONFIG_DIR="${PROJECT_ROOT}/.vm_deployment_automation"

################################################################################
# Functions
################################################################################

function usage() {
    cat << EOF
Usage: $(basename "$0") -e <environment> -r <region> [options]

Deploy network infrastructure (Workload Zone) for a specific environment.

Required Arguments:
  -e, --environment ENV         Environment name (dev, uat, prod)
  -r, --region REGION          Azure region (eastus, westeurope, etc.)

Optional Arguments:
  -p, --project-code CODE      Project code (default: from saved config)
  -s, --subscription ID        Azure subscription ID (default: current)
  -c, --control-plane-rg RG    Control plane resource group name
  -w, --workspace PATH         Path to workspace configuration directory
  -d, --dry-run                Run terraform plan only (no apply)
  -y, --auto-approve           Skip interactive approval (terraform apply -auto-approve)
  --destroy                    Destroy the workload zone infrastructure
  -h, --help                   Show this help message

Examples:
  # Deploy development workload zone in East US
  $(basename "$0") -e dev -r eastus

  # Deploy production workload zone with custom workspace
  $(basename "$0") -e prod -r westeurope -w /path/to/workspace

  # Dry run (plan only)
  $(basename "$0") -e uat -r eastus2 -d

  # Destroy workload zone
  $(basename "$0") -e dev -r eastus --destroy

Environment Variables:
  ARM_SUBSCRIPTION_ID          Azure subscription ID
  TF_VAR_environment           Terraform environment variable
  TF_VAR_location              Terraform location variable

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
    
    # Validate environment
    if [[ -z "${ENVIRONMENT}" ]]; then
        print_error "Environment (-e) is required"
        usage
    fi
    
    if ! validate_environment "${ENVIRONMENT}"; then
        print_error "Invalid environment: ${ENVIRONMENT}"
        print_info "Valid environments: dev, development, uat, staging, prod, production"
        exit 1
    fi
    
    # Validate region
    if [[ -z "${REGION}" ]]; then
        print_error "Region (-r) is required"
        usage
    fi
    
    if ! validate_azure_region "${REGION}"; then
        print_error "Invalid Azure region: ${REGION}"
        exit 1
    fi
    
    # Get region code
    local region_code
    region_code=$(get_region_code "${REGION}")
    print_info "Region code: ${region_code}"
    
    # Load or validate project code
    if [[ -z "${PROJECT_CODE}" ]]; then
        PROJECT_CODE=$(load_config_var "project_code" "")
        if [[ -z "${PROJECT_CODE}" ]]; then
            print_error "Project code not found. Please provide -p or deploy control plane first"
            exit 1
        fi
        print_info "Using saved project code: ${PROJECT_CODE}"
    else
        save_config_var "project_code" "${PROJECT_CODE}"
        print_info "Project code: ${PROJECT_CODE}"
    fi
    
    print_success "All inputs validated"
}

function load_control_plane_config() {
    print_banner "Loading Control Plane Configuration"
    
    # Load control plane resource group
    if [[ -z "${CONTROL_PLANE_RG}" ]]; then
        CONTROL_PLANE_RG=$(load_config_var "control_plane_resource_group" "")
        if [[ -z "${CONTROL_PLANE_RG}" ]]; then
            print_error "Control plane resource group not found"
            print_info "Please deploy control plane first or provide -c option"
            exit 1
        fi
    fi
    
    print_info "Control plane resource group: ${CONTROL_PLANE_RG}"
    
    # Verify control plane resource group exists
    if ! az group show --name "${CONTROL_PLANE_RG}" &> /dev/null; then
        print_error "Control plane resource group '${CONTROL_PLANE_RG}' not found"
        print_info "Please deploy control plane first: deploy_control_plane.sh"
        exit 1
    fi
    
    print_success "Control plane configuration loaded"
}

function prepare_workspace() {
    print_banner "Preparing Workspace"
    
    # Determine workspace path
    if [[ -z "${WORKSPACE_PATH}" ]]; then
        WORKSPACE_PATH="${PROJECT_ROOT}/boilerplate/WORKSPACES/WORKLOAD-ZONE/${ENVIRONMENT}"
    fi
    
    if [[ ! -d "${WORKSPACE_PATH}" ]]; then
        print_error "Workspace not found: ${WORKSPACE_PATH}"
        print_info "Available workspaces:"
        find "${PROJECT_ROOT}/boilerplate/WORKSPACES/WORKLOAD-ZONE" -type d -mindepth 1 -maxdepth 1 2>/dev/null || true
        exit 1
    fi
    
    print_info "Using workspace: ${WORKSPACE_PATH}"
    
    # Check for terraform.tfvars or .tfvars file
    local tfvars_file=""
    if [[ -f "${WORKSPACE_PATH}/terraform.tfvars" ]]; then
        tfvars_file="${WORKSPACE_PATH}/terraform.tfvars"
    elif [[ -f "${WORKSPACE_PATH}/${ENVIRONMENT}.tfvars" ]]; then
        tfvars_file="${WORKSPACE_PATH}/${ENVIRONMENT}.tfvars"
    fi
    
    if [[ -n "${tfvars_file}" ]]; then
        print_info "Found tfvars file: $(basename "${tfvars_file}")"
    else
        print_warning "No terraform.tfvars file found in workspace"
    fi
    
    print_success "Workspace prepared"
}

function initialize_terraform() {
    print_banner "Initializing Terraform"
    
    cd "${TERRAFORM_MODULE_PATH}"
    
    # Get backend configuration from control plane state
    local backend_config_file="${CONFIG_DIR}/backend-config-${ENVIRONMENT}-${REGION}.tfbackend"
    
    if [[ -f "${backend_config_file}" ]]; then
        print_info "Using saved backend configuration: ${backend_config_file}"
    else
        print_info "Generating backend configuration from control plane..."
        
        # Query control plane for backend config
        local control_plane_state="${PROJECT_ROOT}/deploy/terraform/bootstrap/control-plane/terraform.tfstate"
        
        if [[ ! -f "${control_plane_state}" ]]; then
            print_error "Control plane state not found: ${control_plane_state}"
            exit 1
        fi
        
        # Extract backend configuration
        local storage_account
        local container_name
        local resource_group
        
        storage_account=$(jq -r '.outputs.state_storage_account_name.value // empty' "${control_plane_state}")
        container_name=$(jq -r '.outputs.state_container_name.value // "tfstate"' "${control_plane_state}")
        resource_group="${CONTROL_PLANE_RG}"
        
        if [[ -z "${storage_account}" ]]; then
            print_error "Could not extract storage account from control plane state"
            exit 1
        fi
        
        # Create backend config file
        mkdir -p "${CONFIG_DIR}"
        cat > "${backend_config_file}" << EOF
resource_group_name  = "${resource_group}"
storage_account_name = "${storage_account}"
container_name       = "${container_name}"
key                  = "workload-zone-${ENVIRONMENT}-${REGION}.tfstate"
EOF
        
        print_success "Generated backend configuration"
    fi
    
    # Initialize Terraform with backend config
    print_info "Running terraform init..."
    if terraform init -backend-config="${backend_config_file}" -reconfigure; then
        print_success "Terraform initialized successfully"
    else
        print_error "Terraform initialization failed"
        exit 1
    fi
}

function plan_deployment() {
    print_banner "Planning Deployment"
    
    cd "${TERRAFORM_MODULE_PATH}"
    
    # Build terraform plan command
    local plan_args=()
    
    # Add var-file if exists
    if [[ -f "${WORKSPACE_PATH}/terraform.tfvars" ]]; then
        plan_args+=("-var-file=${WORKSPACE_PATH}/terraform.tfvars")
    elif [[ -f "${WORKSPACE_PATH}/${ENVIRONMENT}.tfvars" ]]; then
        plan_args+=("-var-file=${WORKSPACE_PATH}/${ENVIRONMENT}.tfvars")
    fi
    
    # Add command-line variables
    plan_args+=(
        "-var=environment=${ENVIRONMENT}"
        "-var=location=${REGION}"
        "-var=project_code=${PROJECT_CODE}"
    )
    
    # Add destroy flag if needed
    if [[ "${DESTROY}" == "true" ]]; then
        plan_args+=("-destroy")
    fi
    
    # Run terraform plan
    print_info "Running terraform plan..."
    if terraform plan "${plan_args[@]}" -out=tfplan; then
        print_success "Terraform plan completed successfully"
    else
        print_error "Terraform plan failed"
        exit 1
    fi
    
    # Show plan summary
    print_info "Plan saved to: tfplan"
}

function apply_deployment() {
    print_banner "Applying Deployment"
    
    cd "${TERRAFORM_MODULE_PATH}"
    
    # Confirm before applying (unless auto-approve)
    if [[ "${AUTO_APPROVE}" != "true" && "${DESTROY}" != "true" ]]; then
        echo ""
        print_warning "Ready to apply workload zone deployment"
        read -p "Do you want to proceed? (yes/no): " confirm
        if [[ "${confirm}" != "yes" ]]; then
            print_info "Deployment cancelled by user"
            exit 0
        fi
    fi
    
    # Run terraform apply
    local apply_args=()
    if [[ "${AUTO_APPROVE}" == "true" ]]; then
        apply_args+=("-auto-approve")
    fi
    
    print_info "Running terraform apply..."
    if terraform apply "${apply_args[@]}" tfplan; then
        print_success "Deployment completed successfully"
    else
        print_error "Deployment failed"
        exit 1
    fi
    
    # Clean up plan file
    rm -f tfplan
}

function save_outputs() {
    print_banner "Saving Deployment Outputs"
    
    cd "${TERRAFORM_MODULE_PATH}"
    
    # Get outputs
    local outputs_file="${CONFIG_DIR}/workload-zone-${ENVIRONMENT}-${REGION}-outputs.json"
    
    if terraform output -json > "${outputs_file}"; then
        print_success "Outputs saved to: ${outputs_file}"
        
        # Display key outputs
        echo ""
        print_info "Key Outputs:"
        
        if command -v jq &> /dev/null; then
            echo "  VNet Name: $(jq -r '.vnet_name.value // "N/A"' "${outputs_file}")"
            echo "  VNet ID: $(jq -r '.vnet_id.value // "N/A"' "${outputs_file}")"
            echo "  Subnet Count: $(jq -r '.subnet_ids.value | length // 0' "${outputs_file}")"
            echo ""
            echo "Subnets:"
            jq -r '.subnet_names.value // {} | to_entries[] | "  - \(.key): \(.value)"' "${outputs_file}"
        fi
    else
        print_warning "Could not save outputs (this is normal if destroying)"
    fi
}

function main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -r|--region)
                REGION="$2"
                shift 2
                ;;
            -p|--project-code)
                PROJECT_CODE="$2"
                shift 2
                ;;
            -s|--subscription)
                SUBSCRIPTION_ID="$2"
                shift 2
                ;;
            -c|--control-plane-rg)
                CONTROL_PLANE_RG="$2"
                shift 2
                ;;
            -w|--workspace)
                WORKSPACE_PATH="$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -y|--auto-approve)
                AUTO_APPROVE=true
                shift
                ;;
            --destroy)
                DESTROY=true
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
    print_header "Workload Zone Deployment"
    
    # Execute deployment steps
    validate_prerequisites
    validate_inputs
    load_control_plane_config
    prepare_workspace
    initialize_terraform
    plan_deployment
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        print_info "Dry run mode - skipping apply"
        print_success "Plan completed successfully (no changes applied)"
        exit 0
    fi
    
    apply_deployment
    
    if [[ "${DESTROY}" != "true" ]]; then
        save_outputs
    fi
    
    # Print completion message
    echo ""
    print_success "======================================"
    if [[ "${DESTROY}" == "true" ]]; then
        print_success "Workload Zone Destroyed Successfully"
    else
        print_success "Workload Zone Deployed Successfully"
    fi
    print_success "======================================"
    echo ""
    print_info "Environment: ${ENVIRONMENT}"
    print_info "Region: ${REGION}"
    print_info "Project: ${PROJECT_CODE}"
    echo ""
    
    if [[ "${DESTROY}" != "true" ]]; then
        print_info "Next Steps:"
        echo "  1. Review outputs: terraform output (in ${TERRAFORM_MODULE_PATH})"
        echo "  2. Deploy VMs: deploy_vm.sh -e ${ENVIRONMENT} -r ${REGION}"
        echo "  3. Check Azure Portal for deployed resources"
    fi
    echo ""
}

# Run main function
main "$@"
