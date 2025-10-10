#!/bin/bash
###############################################################################
# VM Automation Accelerator - Helper Functions Library
# Based on Microsoft SAP Automation Framework patterns
# Version: 1.0.0
###############################################################################

set -o errexit  # Exit on error
set -o pipefail # Exit on pipe failure
set -o nounset  # Exit on unset variable

# Color codes for output
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;36m'
readonly COLOR_RESET='\033[0m'

# Exit codes (from /usr/include/sysexits.h)
readonly EX_OK=0
readonly EX_USAGE=64
readonly EX_DATAERR=65
readonly EX_NOINPUT=66
readonly EX_SOFTWARE=70
readonly EX_CONFIG=78

###############################################################################
# Print colored message
###############################################################################
function print_message() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${COLOR_RESET}"
}

function print_info() {
    print_message "$COLOR_BLUE" "ℹ️  INFO: $1"
}

function print_success() {
    print_message "$COLOR_GREEN" "✅ SUCCESS: $1"
}

function print_warning() {
    print_message "$COLOR_YELLOW" "⚠️  WARNING: $1"
}

function print_error() {
    print_message "$COLOR_RED" "❌ ERROR: $1"
}

###############################################################################
# Print banner
###############################################################################
function print_banner() {
    local title="$1"
    local message="${2:-}"
    local type="${3:-info}"
    
    local color
    case "$type" in
        "success") color="$COLOR_GREEN" ;;
        "warning") color="$COLOR_YELLOW" ;;
        "error")   color="$COLOR_RED" ;;
        *)         color="$COLOR_BLUE" ;;
    esac
    
    echo ""
    echo -e "${color}#########################################################################################"
    echo "#"
    echo "#  $title"
    if [ -n "$message" ]; then
        echo "#"
        echo "#  $message"
    fi
    echo "#"
    echo -e "#########################################################################################${COLOR_RESET}"
    echo ""
}

###############################################################################
# Validate environment exports
###############################################################################
function validate_exports() {
    local return_code=0
    
    if [ -z "${ARM_SUBSCRIPTION_ID:-}" ]; then
        print_error "ARM_SUBSCRIPTION_ID not set"
        print_info "Run: export ARM_SUBSCRIPTION_ID=<subscription-id>"
        return_code=1
    fi
    
    if [ -z "${VM_AUTOMATION_REPO_PATH:-}" ]; then
        print_error "VM_AUTOMATION_REPO_PATH not set"
        print_info "Run: export VM_AUTOMATION_REPO_PATH=<path-to-repo>"
        return_code=2
    fi
    
    return $return_code
}

###############################################################################
# Validate dependencies
###############################################################################
function validate_dependencies() {
    local return_code=0
    
    print_info "Validating dependencies..."
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform not found"
        print_info "Install from: https://www.terraform.io/downloads"
        return_code=1
    else
        local tf_version=$(terraform version -json | jq -r '.terraform_version')
        print_success "Terraform found: v${tf_version}"
    fi
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI not found"
        print_info "Install from: https://docs.microsoft.com/cli/azure/install-azure-cli"
        return_code=2
    else
        local az_version=$(az version --output json | jq -r '."azure-cli"')
        print_success "Azure CLI found: v${az_version}"
    fi
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        print_error "jq not found (required for JSON parsing)"
        print_info "Install: apt-get install jq (Linux) or brew install jq (macOS)"
        return_code=3
    else
        print_success "jq found"
    fi
    
    # Check Azure CLI login status
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure CLI"
        print_info "Run: az login"
        return_code=4
    else
        local account_name=$(az account show --query name -o tsv)
        print_success "Logged in to Azure: ${account_name}"
    fi
    
    return $return_code
}

###############################################################################
# Validate parameter file
###############################################################################
function validate_parameter_file() {
    local param_file="$1"
    
    if [ ! -f "$param_file" ]; then
        print_error "Parameter file not found: $param_file"
        return $EX_NOINPUT
    fi
    
    print_info "Validating parameter file: $param_file"
    
    # Check for required parameters
    local environment=$(grep -m1 "^environment" "$param_file" | sed 's/.*=\s*"\?\([^"]*\)"\?.*/\1/' | tr -d ' \t\n\r\f')
    local location=$(grep -m1 "^location" "$param_file" | sed 's/.*=\s*"\?\([^"]*\)"\?.*/\1/' | tr -d ' \t\n\r\f')
    
    if [ -z "$environment" ]; then
        print_error "Required parameter 'environment' not found in $param_file"
        return $EX_DATAERR
    fi
    
    if [ -z "$location" ]; then
        print_error "Required parameter 'location' not found in $param_file"
        return $EX_DATAERR
    fi
    
    print_success "Parameter file validation passed"
    print_info "Environment: $environment"
    print_info "Location: $location"
    
    return 0
}

###############################################################################
# Get region code from region name
###############################################################################
function get_region_code() {
    local region=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    
    case "$region" in
        "eastus")           echo "eus" ;;
        "eastus2")          echo "eus2" ;;
        "westus")           echo "wus" ;;
        "westus2")          echo "wus2" ;;
        "westus3")          echo "wus3" ;;
        "centralus")        echo "cus" ;;
        "northcentralus")   echo "ncus" ;;
        "southcentralus")   echo "scus" ;;
        "northeurope")      echo "neu" ;;
        "westeurope")       echo "weu" ;;
        "uksouth")          echo "uks" ;;
        "ukwest")           echo "ukw" ;;
        "francecentral")    echo "frc" ;;
        "germanywestcentral") echo "gwc" ;;
        "norwayeast")       echo "noe" ;;
        "swedencentral")    echo "swc" ;;
        "canadacentral")    echo "cac" ;;
        "canadaeast")       echo "cae" ;;
        "brazilsouth")      echo "brs" ;;
        "southafricanorth") echo "san" ;;
        "australiaeast")    echo "aue" ;;
        "australiasoutheast") echo "ase" ;;
        "japaneast")        echo "jpe" ;;
        "japanwest")        echo "jpw" ;;
        "koreacentral")     echo "krc" ;;
        "southeastasia")    echo "sea" ;;
        "eastasia")         echo "eas" ;;
        "southindia")       echo "sin" ;;
        "centralindia")     echo "cin" ;;
        *)                  echo "unknown" ;;
    esac
}

###############################################################################
# Get Terraform output value
###############################################################################
function get_terraform_output() {
    local output_name="$1"
    local terraform_dir="${2:-.}"
    local default_value="${3:-}"
    
    local value
    if value=$(terraform -chdir="$terraform_dir" output -no-color -raw "$output_name" 2>/dev/null); then
        echo "$value"
    else
        echo "$default_value"
    fi
}

###############################################################################
# Get all Terraform outputs as JSON
###############################################################################
function get_terraform_outputs_json() {
    local terraform_dir="${1:-.}"
    
    terraform -chdir="$terraform_dir" output -json 2>/dev/null || echo "{}"
}

###############################################################################
# Check if Terraform resource would be recreated
###############################################################################
function test_if_resource_would_be_recreated() {
    local terraform_dir="$1"
    local resource_address="$2"
    
    print_info "Checking if resource would be recreated: $resource_address"
    
    local plan_output
    plan_output=$(terraform -chdir="$terraform_dir" plan -json 2>/dev/null | jq -r --arg addr "$resource_address" 'select(.type == "planned_change" and .change.resource.addr == $addr) | .change.action')
    
    if [[ "$plan_output" == *"delete"* ]] && [[ "$plan_output" == *"create"* ]]; then
        print_warning "Resource would be RECREATED: $resource_address"
        return 0
    fi
    
    return 1
}

###############################################################################
# Initialize Terraform with backend configuration
###############################################################################
function terraform_init_with_backend() {
    local terraform_dir="$1"
    local subscription_id="$2"
    local resource_group="$3"
    local storage_account="$4"
    local container_name="$5"
    local state_key="$6"
    
    print_info "Initializing Terraform with remote backend..."
    
    terraform -chdir="$terraform_dir" init \
        -backend-config="subscription_id=${subscription_id}" \
        -backend-config="resource_group_name=${resource_group}" \
        -backend-config="storage_account_name=${storage_account}" \
        -backend-config="container_name=${container_name}" \
        -backend-config="key=${state_key}" \
        -reconfigure
    
    local init_status=$?
    if [ $init_status -eq 0 ]; then
        print_success "Terraform initialized successfully"
    else
        print_error "Terraform initialization failed"
    fi
    
    return $init_status
}

###############################################################################
# Check if Azure resource exists
###############################################################################
function check_azure_resource_exists() {
    local resource_id="$1"
    
    if az resource show --ids "$resource_id" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

###############################################################################
# Get Azure subscription name
###############################################################################
function get_subscription_name() {
    local subscription_id="$1"
    
    az account show --subscription "$subscription_id" --query name -o tsv 2>/dev/null || echo "Unknown"
}

###############################################################################
# Check VM SKU availability in region
###############################################################################
function check_vm_sku_availability() {
    local vm_size="$1"
    local location="$2"
    
    print_info "Checking VM SKU availability: $vm_size in $location"
    
    local sku_count
    sku_count=$(az vm list-skus --location "$location" --size "$vm_size" --query "length([])" -o tsv 2>/dev/null)
    
    if [ "$sku_count" -gt 0 ]; then
        print_success "VM SKU $vm_size is available in $location"
        return 0
    else
        print_error "VM SKU $vm_size is NOT available in $location"
        return 1
    fi
}

###############################################################################
# Get available VM SKUs in region
###############################################################################
function get_available_vm_skus() {
    local location="$1"
    local vm_family="${2:-Standard_D}"
    
    print_info "Getting available VM SKUs in $location (family: $vm_family)"
    
    az vm list-skus --location "$location" --query "[?contains(name, '$vm_family')].name" -o tsv
}

###############################################################################
# Calculate estimated monthly cost (simplified)
###############################################################################
function estimate_monthly_cost() {
    local vm_size="$1"
    local os_type="${2:-Linux}"
    local count="${3:-1}"
    
    # Simplified cost estimation - in production, use Azure Pricing API
    local base_cost
    case "$vm_size" in
        "Standard_B2s")     base_cost=30 ;;
        "Standard_D2s_v3")  base_cost=70 ;;
        "Standard_D4s_v3")  base_cost=140 ;;
        "Standard_D8s_v3")  base_cost=280 ;;
        "Standard_D16s_v3") base_cost=560 ;;
        "Standard_E2s_v3")  base_cost=100 ;;
        "Standard_E4s_v3")  base_cost=200 ;;
        *)                  base_cost=0 ;;
    esac
    
    if [ "$base_cost" -eq 0 ]; then
        echo "Unknown VM size - check Azure pricing"
    else
        local total_cost=$((base_cost * count))
        echo "\$${total_cost}-$((total_cost + 50))/month (${count} instance(s), $os_type)"
    fi
}

###############################################################################
# Validate JSON file
###############################################################################
function validate_json_file() {
    local json_file="$1"
    
    if [ ! -f "$json_file" ]; then
        print_error "JSON file not found: $json_file"
        return 1
    fi
    
    if jq empty "$json_file" 2>/dev/null; then
        print_success "Valid JSON: $json_file"
        return 0
    else
        print_error "Invalid JSON: $json_file"
        return 1
    fi
}

###############################################################################
# Format JSON output
###############################################################################
function format_json() {
    local json_string="$1"
    
    echo "$json_string" | jq '.' 2>/dev/null || echo "$json_string"
}

###############################################################################
# Get current timestamp
###############################################################################
function get_timestamp() {
    date +"%Y-%m-%d %H:%M:%S"
}

###############################################################################
# Get deployment ID (date-based)
###############################################################################
function get_deployment_id() {
    date +"%Y%m%d-%H%M%S"
}

###############################################################################
# Log message to file
###############################################################################
function log_message() {
    local log_file="${1}"
    local message="${2}"
    local timestamp=$(get_timestamp)
    
    echo "[${timestamp}] ${message}" >> "$log_file"
}

###############################################################################
# Export function for use in other scripts
###############################################################################
export -f print_message
export -f print_info
export -f print_success
export -f print_warning
export -f print_error
export -f print_banner
export -f validate_exports
export -f validate_dependencies
export -f validate_parameter_file
export -f get_region_code
export -f get_terraform_output
export -f get_terraform_outputs_json
export -f test_if_resource_would_be_recreated
export -f terraform_init_with_backend
export -f check_azure_resource_exists
export -f get_subscription_name
export -f check_vm_sku_availability
export -f get_available_vm_skus
export -f estimate_monthly_cost
export -f validate_json_file
export -f format_json
export -f get_timestamp
export -f get_deployment_id
export -f log_message

print_info "VM Automation Helper Functions Library loaded (v1.0.0)"
