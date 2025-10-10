#!/bin/bash

################################################################################
# Full Deployment Integration Test
# 
# Purpose: Test complete end-to-end deployment workflow from bootstrap to VMs.
#          This validates all scripts and modules work together correctly.
#
# Usage: ./test_full_deployment.sh -e <environment> -r <region> [options]
#
# Test Flow:
#   1. Deploy bootstrap control plane (local state)
#   2. Migrate to remote state backend
#   3. Deploy workload zone (network)
#   4. Deploy VM workload (web tier)
#   5. Verify all outputs and connections
#   6. Optional: Cleanup (destroy resources)
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

ENVIRONMENT="${ENVIRONMENT:-test}"
REGION="${REGION:-eastus}"
PROJECT_CODE="${PROJECT_CODE:-integtest}"
WORKLOAD_NAME="web"
CLEANUP=false
SKIP_DESTROY=false
TEST_START_TIME=""
TEST_RESULTS=()

################################################################################
# Functions
################################################################################

function usage() {
    cat << EOF
Usage: $(basename "$0") [options]

Run full deployment integration test from bootstrap to VM deployment.

Optional Arguments:
  -e, --environment ENV    Environment name (default: test)
  -r, --region REGION     Azure region (default: eastus)
  -p, --project-code CODE Project code (default: integtest)
  -n, --workload NAME     Workload name (default: web)
  --cleanup               Destroy all resources after test
  --skip-destroy          Skip destroy tests
  -h, --help              Show this help message

Examples:
  # Run full test with default settings
  $(basename "$0")

  # Run test in specific environment
  $(basename "$0") -e test -r eastus -p mytest

  # Run test and cleanup
  $(basename "$0") --cleanup

  # Skip destroy tests
  $(basename "$0") --skip-destroy

Environment Variables:
  ENVIRONMENT    Test environment name (default: test)
  REGION         Azure region (default: eastus)
  PROJECT_CODE   Project code (default: integtest)

EOF
    exit 0
}

function print_test_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║         Full Deployment Integration Test                      ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Environment: ${ENVIRONMENT}"
    echo "Region:      ${REGION}"
    echo "Project:     ${PROJECT_CODE}"
    echo "Workload:    ${WORKLOAD_NAME}"
    echo ""
}

function start_test() {
    local test_name="$1"
    TEST_START_TIME=$(date +%s)
    print_banner "TEST: ${test_name}"
}

function pass_test() {
    local test_name="$1"
    local duration=$(($(date +%s) - TEST_START_TIME))
    print_success "✓ PASSED: ${test_name} (${duration}s)"
    TEST_RESULTS+=("✓ ${test_name} - PASSED (${duration}s)")
    echo ""
}

function fail_test() {
    local test_name="$1"
    local error_msg="$2"
    local duration=$(($(date +%s) - TEST_START_TIME))
    print_error "✗ FAILED: ${test_name} (${duration}s)"
    print_error "Error: ${error_msg}"
    TEST_RESULTS+=("✗ ${test_name} - FAILED (${duration}s): ${error_msg}")
    echo ""
    return 1
}

function test_prerequisites() {
    start_test "Prerequisites Check"
    
    local errors=0
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform not found"
        ((errors++))
    else
        print_info "✓ Terraform: $(terraform version -json | jq -r '.terraform_version')"
    fi
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI not found"
        ((errors++))
    else
        print_info "✓ Azure CLI: $(az version --query '\"azure-cli\"' -o tsv)"
    fi
    
    # Check authentication
    if ! az account show &> /dev/null; then
        print_error "Not authenticated to Azure"
        ((errors++))
    else
        local sub_name
        sub_name=$(az account show --query name -o tsv)
        print_info "✓ Azure Auth: ${sub_name}"
    fi
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        print_error "jq not found"
        ((errors++))
    else
        print_info "✓ jq: $(jq --version)"
    fi
    
    # Check scripts exist
    local scripts=(
        "deploy_control_plane.sh"
        "migrate_state_to_remote.sh"
        "deploy_workload_zone.sh"
        "deploy_vm.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ ! -f "${SCRIPT_DIR}/${script}" ]]; then
            print_error "Script not found: ${script}"
            ((errors++))
        else
            print_info "✓ Script: ${script}"
        fi
    done
    
    if [[ ${errors} -gt 0 ]]; then
        fail_test "Prerequisites Check" "${errors} errors found"
        return 1
    fi
    
    pass_test "Prerequisites Check"
}

function test_bootstrap_control_plane() {
    start_test "Bootstrap Control Plane Deployment"
    
    cd "${SCRIPT_DIR}"
    
    if ./deploy_control_plane.sh -e "${ENVIRONMENT}" -r "${REGION}" -p "${PROJECT_CODE}" -y; then
        pass_test "Bootstrap Control Plane Deployment"
    else
        fail_test "Bootstrap Control Plane Deployment" "Script failed with exit code $?"
        return 1
    fi
}

function test_state_migration() {
    start_test "State Migration to Remote Backend"
    
    cd "${SCRIPT_DIR}"
    
    if ./migrate_state_to_remote.sh -m control-plane -y; then
        pass_test "State Migration to Remote Backend"
    else
        fail_test "State Migration to Remote Backend" "Migration failed with exit code $?"
        return 1
    fi
    
    # Verify remote state exists
    start_test "Verify Remote State"
    
    local control_plane_state="${PROJECT_ROOT}/deploy/terraform/bootstrap/control-plane/terraform.tfstate"
    
    if [[ ! -f "${control_plane_state}" ]]; then
        fail_test "Verify Remote State" "State file not found"
        return 1
    fi
    
    local storage_account
    storage_account=$(jq -r '.outputs.state_storage_account_name.value // empty' "${control_plane_state}")
    
    if [[ -z "${storage_account}" ]]; then
        fail_test "Verify Remote State" "Storage account not found in outputs"
        return 1
    fi
    
    print_info "Storage Account: ${storage_account}"
    
    # Check if blob exists
    local resource_group
    resource_group=$(jq -r '.outputs.control_plane_resource_group_name.value // empty' "${control_plane_state}")
    
    if az storage blob exists \
        --account-name "${storage_account}" \
        --container-name tfstate \
        --name control-plane.tfstate \
        --auth-mode login &> /dev/null; then
        print_info "✓ Remote state blob exists"
        pass_test "Verify Remote State"
    else
        fail_test "Verify Remote State" "Remote state blob not found"
        return 1
    fi
}

function test_workload_zone_deployment() {
    start_test "Workload Zone Deployment"
    
    cd "${SCRIPT_DIR}"
    
    if ./deploy_workload_zone.sh -e "${ENVIRONMENT}" -r "${REGION}" -y; then
        pass_test "Workload Zone Deployment"
    else
        fail_test "Workload Zone Deployment" "Script failed with exit code $?"
        return 1
    fi
    
    # Verify outputs
    start_test "Verify Workload Zone Outputs"
    
    local outputs_file="${PROJECT_ROOT}/.vm_deployment_automation/workload-zone-${ENVIRONMENT}-${REGION}-outputs.json"
    
    if [[ ! -f "${outputs_file}" ]]; then
        fail_test "Verify Workload Zone Outputs" "Outputs file not found"
        return 1
    fi
    
    local vnet_id
    local subnet_count
    
    vnet_id=$(jq -r '.vnet_id.value // empty' "${outputs_file}")
    subnet_count=$(jq -r '.subnet_ids.value | length // 0' "${outputs_file}")
    
    if [[ -z "${vnet_id}" ]]; then
        fail_test "Verify Workload Zone Outputs" "VNet ID not found"
        return 1
    fi
    
    if [[ ${subnet_count} -eq 0 ]]; then
        fail_test "Verify Workload Zone Outputs" "No subnets found"
        return 1
    fi
    
    print_info "✓ VNet ID: ${vnet_id}"
    print_info "✓ Subnets: ${subnet_count}"
    
    pass_test "Verify Workload Zone Outputs"
}

function test_vm_deployment() {
    start_test "VM Deployment"
    
    cd "${SCRIPT_DIR}"
    
    if ./deploy_vm.sh -e "${ENVIRONMENT}" -r "${REGION}" -n "${WORKLOAD_NAME}" -y; then
        pass_test "VM Deployment"
    else
        fail_test "VM Deployment" "Script failed with exit code $?"
        return 1
    fi
    
    # Verify outputs
    start_test "Verify VM Deployment Outputs"
    
    local outputs_file="${PROJECT_ROOT}/.vm_deployment_automation/vm-deployment-${ENVIRONMENT}-${REGION}-${WORKLOAD_NAME}-outputs.json"
    
    if [[ ! -f "${outputs_file}" ]]; then
        fail_test "Verify VM Deployment Outputs" "Outputs file not found"
        return 1
    fi
    
    local linux_count
    local windows_count
    
    linux_count=$(jq -r '.linux_vm_ids.value // {} | length' "${outputs_file}")
    windows_count=$(jq -r '.windows_vm_ids.value // {} | length' "${outputs_file}")
    
    print_info "✓ Linux VMs: ${linux_count}"
    print_info "✓ Windows VMs: ${windows_count}"
    
    if [[ $((linux_count + windows_count)) -eq 0 ]]; then
        fail_test "Verify VM Deployment Outputs" "No VMs deployed"
        return 1
    fi
    
    pass_test "Verify VM Deployment Outputs"
}

function test_cross_module_state_references() {
    start_test "Cross-Module State References"
    
    # Check that VM deployment can read workload zone state
    cd "${PROJECT_ROOT}/deploy/terraform/run/vm-deployment"
    
    if ! terraform init -reconfigure &> /dev/null; then
        fail_test "Cross-Module State References" "Terraform init failed"
        return 1
    fi
    
    # Try to read remote state
    if terraform state list &> /dev/null; then
        print_info "✓ VM deployment state accessible"
    else
        fail_test "Cross-Module State References" "Cannot access VM deployment state"
        return 1
    fi
    
    pass_test "Cross-Module State References"
}

function test_destroy_vm() {
    if [[ "${SKIP_DESTROY}" == "true" ]]; then
        print_warning "Skipping VM destroy test"
        return 0
    fi
    
    start_test "VM Destroy"
    
    cd "${SCRIPT_DIR}"
    
    if ./deploy_vm.sh -e "${ENVIRONMENT}" -r "${REGION}" -n "${WORKLOAD_NAME}" --destroy -y; then
        pass_test "VM Destroy"
    else
        fail_test "VM Destroy" "Script failed with exit code $?"
        return 1
    fi
}

function test_destroy_workload_zone() {
    if [[ "${SKIP_DESTROY}" == "true" ]]; then
        print_warning "Skipping workload zone destroy test"
        return 0
    fi
    
    start_test "Workload Zone Destroy"
    
    cd "${SCRIPT_DIR}"
    
    if ./deploy_workload_zone.sh -e "${ENVIRONMENT}" -r "${REGION}" --destroy -y; then
        pass_test "Workload Zone Destroy"
    else
        fail_test "Workload Zone Destroy" "Script failed with exit code $?"
        return 1
    fi
}

function cleanup_test_resources() {
    if [[ "${CLEANUP}" != "true" ]]; then
        print_warning "Cleanup not requested (use --cleanup to destroy resources)"
        return 0
    fi
    
    print_banner "Cleaning Up Test Resources"
    
    # Destroy VM if still exists
    print_info "Destroying VM deployment..."
    cd "${SCRIPT_DIR}"
    ./deploy_vm.sh -e "${ENVIRONMENT}" -r "${REGION}" -n "${WORKLOAD_NAME}" --destroy -y 2>/dev/null || true
    
    # Destroy workload zone
    print_info "Destroying workload zone..."
    ./deploy_workload_zone.sh -e "${ENVIRONMENT}" -r "${REGION}" --destroy -y 2>/dev/null || true
    
    # Destroy control plane (manually via Azure)
    print_info "Manual cleanup required for control plane:"
    print_info "  Resource Group: rg-controlplane-${ENVIRONMENT}-${REGION}"
    
    print_success "Cleanup completed"
}

function print_test_summary() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                    TEST SUMMARY                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    local passed=0
    local failed=0
    
    for result in "${TEST_RESULTS[@]}"; do
        echo "${result}"
        if [[ "${result}" == ✓* ]]; then
            ((passed++))
        else
            ((failed++))
        fi
    done
    
    echo ""
    echo "────────────────────────────────────────────────────────────────"
    echo "Total Tests: $((passed + failed))"
    print_success "Passed: ${passed}"
    if [[ ${failed} -gt 0 ]]; then
        print_error "Failed: ${failed}"
    else
        print_info "Failed: ${failed}"
    fi
    echo "────────────────────────────────────────────────────────────────"
    echo ""
    
    if [[ ${failed} -eq 0 ]]; then
        print_success "✓ ALL TESTS PASSED"
        return 0
    else
        print_error "✗ SOME TESTS FAILED"
        return 1
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
            -n|--workload)
                WORKLOAD_NAME="$2"
                shift 2
                ;;
            --cleanup)
                CLEANUP=true
                shift
                ;;
            --skip-destroy)
                SKIP_DESTROY=true
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
    
    # Print test header
    print_test_header
    
    # Run tests
    test_prerequisites || exit 1
    test_bootstrap_control_plane || exit 1
    test_state_migration || exit 1
    test_workload_zone_deployment || exit 1
    test_vm_deployment || exit 1
    test_cross_module_state_references || exit 1
    test_destroy_vm || exit 1
    test_destroy_workload_zone || exit 1
    
    # Cleanup if requested
    cleanup_test_resources
    
    # Print summary
    print_test_summary
}

# Run main function
main "$@"
