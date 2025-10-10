#!/bin/bash
###############################################################################
# Bootstrap Control Plane Deployment Script
# Creates foundational infrastructure with local state backend
###############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load helper functions
source "$SCRIPT_DIR/helpers/vm_helpers.sh"
source "$SCRIPT_DIR/helpers/config_persistence.sh"

###############################################################################
# Main function
###############################################################################
function main() {
    print_banner "VM Automation Accelerator - Bootstrap Control Plane" \
                 "Creating foundational infrastructure" \
                 "info"
    
    # Validate dependencies
    validate_dependencies || exit $?
    
    # Validate environment variables
    validate_exports || exit $?
    
    # Get parameters
    local param_file="${1:-}"
    if [ -z "$param_file" ]; then
        print_error "Parameter file not provided"
        print_info "Usage: $0 <parameter-file.tfvars>"
        exit $EX_USAGE
    fi
    
    validate_parameter_file "$param_file" || exit $?
    
    # Extract parameters
    local environment=$(grep -m1 "^environment" "$param_file" | sed 's/.*=\s*"\?\([^"]*\)"\?.*/\1/' | tr -d ' \t\n\r\f')
    local location=$(grep -m1 "^location" "$param_file" | sed 's/.*=\s*"\?\([^"]*\)"\?.*/\1/' | tr -d ' \t\n\r\f')
    local project_code=$(grep -m1 "^project_code" "$param_file" | sed 's/.*=\s*"\?\([^"]*\)"\?.*/\1/' | tr -d ' \t\n\r\f')
    
    local region_code=$(get_region_code "$location")
    
    print_info "Environment: $environment"
    print_info "Location: $location ($region_code)"
    print_info "Project Code: $project_code"
    
    # Initialize configuration directory
    local config_file=$(init_config_dir "$environment" "$location")
    print_success "Configuration file: $config_file"
    
    # Terraform directory
    local tf_dir="$REPO_ROOT/deploy/terraform/bootstrap/control-plane"
    cd "$tf_dir"
    
    print_banner "Step 1: Terraform Initialize" \
                 "Initializing with local backend" \
                 "info"
    
    terraform init -upgrade
    
    print_banner "Step 2: Terraform Plan" \
                 "Planning control plane infrastructure" \
                 "info"
    
    terraform plan \
        -var-file="$param_file" \
        -out=tfplan
    
    read -p "Do you want to apply this plan? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        print_warning "Deployment cancelled by user"
        exit 0
    fi
    
    print_banner "Step 3: Terraform Apply" \
                 "Creating control plane infrastructure" \
                 "info"
    
    terraform apply tfplan
    
    print_banner "Step 4: Extract Outputs" \
                 "Saving configuration for future deployments" \
                 "info"
    
    # Extract outputs
    local tfstate_rg=$(get_terraform_output "tfstate_resource_group_name" "$tf_dir")
    local tfstate_sa=$(get_terraform_output "tfstate_storage_account_name" "$tf_dir")
    local tfstate_container=$(get_terraform_output "tfstate_container_name" "$tf_dir")
    local keyvault_name=$(get_terraform_output "key_vault_name" "$tf_dir")
    local keyvault_id=$(get_terraform_output "key_vault_id" "$tf_dir")
    local random_id=$(get_terraform_output "random_id" "$tf_dir")
    
    print_success "Terraform State Storage: $tfstate_sa"
    print_success "Container: $tfstate_container"
    print_success "Key Vault: $keyvault_name"
    
    # Save configuration
    print_banner "Step 5: Save Configuration" \
                 "Persisting state for future deployments" \
                 "info"
    
    save_backend_config "$config_file" \
        "$ARM_SUBSCRIPTION_ID" \
        "$tfstate_rg" \
        "$tfstate_sa" \
        "$tfstate_container"
    
    if [ -n "$keyvault_name" ]; then
        save_keyvault_config "$config_file" "$keyvault_name" "$keyvault_id"
    fi
    
    # Save additional variables
    RANDOM_ID="$random_id"
    ENVIRONMENT="$environment"
    LOCATION="$location"
    REGION_CODE="$region_code"
    PROJECT_CODE="$project_code"
    
    save_config_var "RANDOM_ID" "$config_file"
    save_config_var "ENVIRONMENT" "$config_file"
    save_config_var "LOCATION" "$config_file"
    save_config_var "REGION_CODE" "$config_file"
    save_config_var "PROJECT_CODE" "$config_file"
    
    save_deployment_state "$config_file" "bootstrap-control-plane" "$(get_deployment_id)"
    
    print_banner "Bootstrap Complete!" \
                 "Control plane created successfully" \
                 "success"
    
    print_info ""
    print_info "Next steps:"
    print_info "1. Migrate local state to remote backend (optional):"
    print_info "   ./deploy/scripts/migrate_state_to_remote.sh $param_file"
    print_info ""
    print_info "2. Deploy workload zone:"
    print_info "   ./deploy/scripts/deploy_workload_zone.sh <workload-zone.tfvars>"
    print_info ""
    print_info "3. Deploy VMs:"
    print_info "   ./deploy/scripts/deploy_vm.sh <vm-deployment.tfvars>"
    print_info ""
    
    print_info "Configuration saved to: $config_file"
    print_info "Backend config: ${tfstate_sa}/${tfstate_container}"
}

# Run main function
main "$@"
