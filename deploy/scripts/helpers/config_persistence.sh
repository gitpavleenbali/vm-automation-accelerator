#!/bin/bash
###############################################################################
# Configuration Persistence Helper
# Based on SAP .sap_deployment_automation pattern
# Stores configuration between script executions
###############################################################################

# Configuration directory
VM_AUTOMATION_CONFIG_DIR="${CONFIG_REPO_PATH:-.}/.vm_deployment_automation"
GENERIC_CONFIG="${VM_AUTOMATION_CONFIG_DIR}/config"

###############################################################################
# Initialize configuration directory
###############################################################################
function init_config_dir() {
    local environment="${1:-}"
    local region="${2:-}"
    
    mkdir -p "$VM_AUTOMATION_CONFIG_DIR"
    
    # Create generic config if it doesn't exist
    if [ ! -f "$GENERIC_CONFIG" ]; then
        touch "$GENERIC_CONFIG"
        print_info "Created generic configuration file: $GENERIC_CONFIG"
    fi
    
    # Create environment-specific config if parameters provided
    if [ -n "$environment" ] && [ -n "$region" ]; then
        local region_code=$(get_region_code "$region")
        local env_config="${VM_AUTOMATION_CONFIG_DIR}/${environment}-${region_code}"
        
        if [ ! -f "$env_config" ]; then
            touch "$env_config"
            print_info "Created environment configuration file: $env_config"
        fi
        
        echo "$env_config"
    else
        echo "$GENERIC_CONFIG"
    fi
}

###############################################################################
# Save configuration variable
###############################################################################
function save_config_var() {
    local var_name="$1"
    local config_file="$2"
    local var_value="${!var_name:-}"  # Indirect variable reference
    
    # Ensure directory exists
    mkdir -p "$(dirname "$config_file")"
    
    # Create file if it doesn't exist
    if [ ! -f "$config_file" ]; then
        touch "$config_file"
    fi
    
    if grep -q "^${var_name}=" "$config_file" 2>/dev/null; then
        # Update existing variable
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS sed syntax
            sed -i '' "s|^${var_name}=.*|${var_name}=${var_value}|" "$config_file"
        else
            # Linux sed syntax
            sed -i "s|^${var_name}=.*|${var_name}=${var_value}|" "$config_file"
        fi
        print_info "Updated ${var_name} in ${config_file}"
    else
        # Add new variable
        echo "${var_name}=${var_value}" >> "$config_file"
        print_info "Added ${var_name} to ${config_file}"
    fi
}

###############################################################################
# Load configuration variables
###############################################################################
function load_config_vars() {
    local config_file="$1"
    shift
    local vars_to_load=("$@")
    
    if [ ! -f "$config_file" ]; then
        print_warning "Configuration file not found: $config_file"
        return 1
    fi
    
    print_info "Loading configuration from: $config_file"
    
    if [ ${#vars_to_load[@]} -eq 0 ]; then
        # Load all variables
        set -a  # Automatically export all variables
        source "$config_file"
        set +a
        print_success "Loaded all variables from $config_file"
    else
        # Load specific variables
        for var_name in "${vars_to_load[@]}"; do
            local var_value=$(grep "^${var_name}=" "$config_file" 2>/dev/null | cut -d'=' -f2-)
            if [ -n "$var_value" ]; then
                export "${var_name}=${var_value}"
                print_info "Loaded ${var_name}=${var_value}"
            else
                print_warning "Variable ${var_name} not found in $config_file"
            fi
        done
    fi
    
    return 0
}

###############################################################################
# Get configuration variable
###############################################################################
function get_config_var() {
    local var_name="$1"
    local config_file="$2"
    local default_value="${3:-}"
    
    if [ ! -f "$config_file" ]; then
        echo "$default_value"
        return 1
    fi
    
    local var_value=$(grep "^${var_name}=" "$config_file" 2>/dev/null | cut -d'=' -f2-)
    
    if [ -n "$var_value" ]; then
        echo "$var_value"
    else
        echo "$default_value"
    fi
}

###############################################################################
# Remove configuration variable
###############################################################################
function remove_config_var() {
    local var_name="$1"
    local config_file="$2"
    
    if [ ! -f "$config_file" ]; then
        print_warning "Configuration file not found: $config_file"
        return 1
    fi
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS sed syntax
        sed -i '' "/^${var_name}=/d" "$config_file"
    else
        # Linux sed syntax
        sed -i "/^${var_name}=/d" "$config_file"
    fi
    
    print_info "Removed ${var_name} from ${config_file}"
}

###############################################################################
# List all configuration variables
###############################################################################
function list_config_vars() {
    local config_file="$1"
    
    if [ ! -f "$config_file" ]; then
        print_warning "Configuration file not found: $config_file"
        return 1
    fi
    
    print_info "Configuration variables in $config_file:"
    while IFS='=' read -r var_name var_value; do
        if [ -n "$var_name" ] && [[ ! "$var_name" =~ ^# ]]; then
            echo "  $var_name = $var_value"
        fi
    done < "$config_file"
}

###############################################################################
# Save deployment state
###############################################################################
function save_deployment_state() {
    local config_file="$1"
    local deployment_type="$2"  # control-plane, workload-zone, vm-deployment
    local deployment_id="$3"
    
    save_config_var "DEPLOYMENT_TYPE" "$config_file"
    save_config_var "DEPLOYMENT_ID" "$config_file"
    save_config_var "DEPLOYMENT_TIMESTAMP" "$config_file"
    
    DEPLOYMENT_TYPE="$deployment_type"
    DEPLOYMENT_ID="$deployment_id"
    DEPLOYMENT_TIMESTAMP=$(get_timestamp)
    
    save_config_var "DEPLOYMENT_TYPE" "$config_file"
    save_config_var "DEPLOYMENT_ID" "$config_file"
    save_config_var "DEPLOYMENT_TIMESTAMP" "$config_file"
}

###############################################################################
# Load deployment state
###############################################################################
function load_deployment_state() {
    local config_file="$1"
    
    load_config_vars "$config_file" "DEPLOYMENT_TYPE" "DEPLOYMENT_ID" "DEPLOYMENT_TIMESTAMP"
    
    if [ -n "${DEPLOYMENT_TYPE:-}" ]; then
        print_info "Last deployment type: $DEPLOYMENT_TYPE"
        print_info "Last deployment ID: ${DEPLOYMENT_ID:-unknown}"
        print_info "Last deployment timestamp: ${DEPLOYMENT_TIMESTAMP:-unknown}"
        return 0
    else
        print_warning "No deployment state found in $config_file"
        return 1
    fi
}

###############################################################################
# Save Terraform backend configuration
###############################################################################
function save_backend_config() {
    local config_file="$1"
    local subscription_id="$2"
    local resource_group="$3"
    local storage_account="$4"
    local container_name="$5"
    
    TFSTATE_SUBSCRIPTION_ID="$subscription_id"
    TFSTATE_RESOURCE_GROUP="$resource_group"
    TFSTATE_STORAGE_ACCOUNT="$storage_account"
    TFSTATE_CONTAINER="$container_name"
    
    save_config_var "TFSTATE_SUBSCRIPTION_ID" "$config_file"
    save_config_var "TFSTATE_RESOURCE_GROUP" "$config_file"
    save_config_var "TFSTATE_STORAGE_ACCOUNT" "$config_file"
    save_config_var "TFSTATE_CONTAINER" "$config_file"
    
    print_success "Saved Terraform backend configuration"
}

###############################################################################
# Load Terraform backend configuration
###############################################################################
function load_backend_config() {
    local config_file="$1"
    
    load_config_vars "$config_file" \
        "TFSTATE_SUBSCRIPTION_ID" \
        "TFSTATE_RESOURCE_GROUP" \
        "TFSTATE_STORAGE_ACCOUNT" \
        "TFSTATE_CONTAINER"
    
    if [ -n "${TFSTATE_STORAGE_ACCOUNT:-}" ]; then
        print_success "Loaded Terraform backend configuration"
        print_info "Storage Account: $TFSTATE_STORAGE_ACCOUNT"
        print_info "Container: ${TFSTATE_CONTAINER:-tfstate}"
        return 0
    else
        print_warning "No backend configuration found"
        return 1
    fi
}

###############################################################################
# Save Key Vault information
###############################################################################
function save_keyvault_config() {
    local config_file="$1"
    local keyvault_name="$2"
    local keyvault_id="$3"
    
    KEYVAULT_NAME="$keyvault_name"
    KEYVAULT_ID="$keyvault_id"
    
    save_config_var "KEYVAULT_NAME" "$config_file"
    save_config_var "KEYVAULT_ID" "$config_file"
    
    print_success "Saved Key Vault configuration: $keyvault_name"
}

###############################################################################
# Load Key Vault information
###############################################################################
function load_keyvault_config() {
    local config_file="$1"
    
    load_config_vars "$config_file" "KEYVAULT_NAME" "KEYVAULT_ID"
    
    if [ -n "${KEYVAULT_NAME:-}" ]; then
        print_success "Loaded Key Vault configuration: $KEYVAULT_NAME"
        return 0
    else
        print_warning "No Key Vault configuration found"
        return 1
    fi
}

###############################################################################
# Clear environment configuration
###############################################################################
function clear_environment_config() {
    local environment="$1"
    local region="$2"
    
    local region_code=$(get_region_code "$region")
    local env_config="${VM_AUTOMATION_CONFIG_DIR}/${environment}-${region_code}"
    
    if [ -f "$env_config" ]; then
        rm -f "$env_config"
        print_success "Cleared configuration for ${environment}-${region_code}"
    else
        print_warning "No configuration found for ${environment}-${region_code}"
    fi
}

###############################################################################
# Export functions
###############################################################################
export -f init_config_dir
export -f save_config_var
export -f load_config_vars
export -f get_config_var
export -f remove_config_var
export -f list_config_vars
export -f save_deployment_state
export -f load_deployment_state
export -f save_backend_config
export -f load_backend_config
export -f save_keyvault_config
export -f load_keyvault_config
export -f clear_environment_config

print_info "Configuration Persistence Helper loaded"
