#!/bin/bash

################################################################################
# Multi-Environment Deployment Test
# 
# Purpose: Test parallel deployment across multiple environments (dev/uat/prod)
#          to validate state isolation and environment-specific configurations.
#
# Usage: ./test_multi_environment.sh [options]
#
# Test Flow:
#   1. Deploy workload zones for dev, uat, prod in parallel
#   2. Deploy VM workloads in each environment
#   3. Verify state isolation (no cross-environment pollution)
#   4. Verify environment-specific configurations
#   5. Optional: Cleanup all environments
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

ENVIRONMENTS=("dev" "uat" "prod")
REGIONS=("eastus" "eastus2" "westeurope")
PROJECT_CODE="${PROJECT_CODE:-multitest}"
WORKLOAD_NAME="web"
CLEANUP=false
PARALLEL=false
TEST_RESULTS=()

################################################################################
# Functions
################################################################################

function usage() {
    cat << EOF
Usage: $(basename "$0") [options]

Test multi-environment deployment with state isolation.

Optional Arguments:
  -p, --project-code CODE  Project code (default: multitest)
  -n, --workload NAME      Workload name (default: web)
  --parallel               Deploy environments in parallel
  --cleanup                Destroy all environments after test
  -h, --help               Show this help message

Examples:
  # Run sequential deployment
  $(basename "$0")

  # Run parallel deployment
  $(basename "$0") --parallel

  # Run test and cleanup
  $(basename "$0") --cleanup

Environment Configuration:
  Dev:  eastus
  UAT:  eastus2
  Prod: westeurope

EOF
    exit 0
}

function print_test_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║       Multi-Environment Deployment Test                       ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Environments: ${ENVIRONMENTS[*]}"
    echo "Regions:      ${REGIONS[*]}"
    echo "Project:      ${PROJECT_CODE}"
    echo "Mode:         $([ "${PARALLEL}" == "true" ] && echo "Parallel" || echo "Sequential")"
    echo ""
}

function test_workload_zone_deployment() {
    local env="$1"
    local region="$2"
    
    print_banner "Deploy Workload Zone: ${env} (${region})"
    
    cd "${SCRIPT_DIR}"
    
    if ./deploy_workload_zone.sh -e "${env}" -r "${region}" -p "${PROJECT_CODE}" -y; then
        print_success "✓ Workload zone deployed: ${env}"
        TEST_RESULTS+=("✓ Workload Zone ${env} - PASSED")
        return 0
    else
        print_error "✗ Workload zone failed: ${env}"
        TEST_RESULTS+=("✗ Workload Zone ${env} - FAILED")
        return 1
    fi
}

function test_vm_deployment() {
    local env="$1"
    local region="$2"
    
    print_banner "Deploy VMs: ${env} (${region})"
    
    cd "${SCRIPT_DIR}"
    
    if ./deploy_vm.sh -e "${env}" -r "${region}" -n "${WORKLOAD_NAME}" -p "${PROJECT_CODE}" -y; then
        print_success "✓ VMs deployed: ${env}"
        TEST_RESULTS+=("✓ VM Deployment ${env} - PASSED")
        return 0
    else
        print_error "✗ VMs failed: ${env}"
        TEST_RESULTS+=("✗ VM Deployment ${env} - FAILED")
        return 1
    fi
}

function verify_state_isolation() {
    print_banner "Verify State Isolation"
    
    local config_dir="${PROJECT_ROOT}/.vm_deployment_automation"
    
    # Check that separate state files exist for each environment
    for i in "${!ENVIRONMENTS[@]}"; do
        local env="${ENVIRONMENTS[$i]}"
        local region="${REGIONS[$i]}"
        
        local wz_outputs="${config_dir}/workload-zone-${env}-${region}-outputs.json"
        local vm_outputs="${config_dir}/vm-deployment-${env}-${region}-${WORKLOAD_NAME}-outputs.json"
        
        if [[ ! -f "${wz_outputs}" ]]; then
            print_error "✗ Missing workload zone outputs: ${env}"
            TEST_RESULTS+=("✗ State Isolation ${env} - FAILED (missing outputs)")
            continue
        fi
        
        if [[ ! -f "${vm_outputs}" ]]; then
            print_error "✗ Missing VM outputs: ${env}"
            TEST_RESULTS+=("✗ State Isolation ${env} - FAILED (missing VM outputs)")
            continue
        fi
        
        # Verify environment-specific values
        local vnet_name
        vnet_name=$(jq -r '.vnet_name.value // empty' "${wz_outputs}")
        
        if [[ ! "${vnet_name}" =~ ${env} ]]; then
            print_error "✗ VNet name doesn't contain environment: ${vnet_name} (expected ${env})"
            TEST_RESULTS+=("✗ State Isolation ${env} - FAILED (incorrect naming)")
            continue
        fi
        
        print_success "✓ State isolated: ${env} (VNet: ${vnet_name})"
        TEST_RESULTS+=("✓ State Isolation ${env} - PASSED")
    done
}

function verify_environment_specific_config() {
    print_banner "Verify Environment-Specific Configuration"
    
    local config_dir="${PROJECT_ROOT}/.vm_deployment_automation"
    
    for i in "${!ENVIRONMENTS[@]}"; do
        local env="${ENVIRONMENTS[$i]}"
        local region="${REGIONS[$i]}"
        
        local wz_outputs="${config_dir}/workload-zone-${env}-${region}-outputs.json"
        
        if [[ ! -f "${wz_outputs}" ]]; then
            continue
        fi
        
        # Verify region matches
        local vnet_location
        vnet_location=$(jq -r '.vnet_location.value // empty' "${wz_outputs}" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
        
        if [[ "${vnet_location}" != "${region}" ]]; then
            print_error "✗ Region mismatch: ${env} (got ${vnet_location}, expected ${region})"
            TEST_RESULTS+=("✗ Environment Config ${env} - FAILED (region mismatch)")
            continue
        fi
        
        print_success "✓ Environment config correct: ${env} → ${region}"
        TEST_RESULTS+=("✓ Environment Config ${env} - PASSED")
    done
}

function verify_no_resource_conflicts() {
    print_banner "Verify No Resource Conflicts"
    
    local config_dir="${PROJECT_ROOT}/.vm_deployment_automation"
    
    # Collect all VNet IDs
    declare -A vnet_ids
    
    for i in "${!ENVIRONMENTS[@]}"; do
        local env="${ENVIRONMENTS[$i]}"
        local region="${REGIONS[$i]}"
        
        local wz_outputs="${config_dir}/workload-zone-${env}-${region}-outputs.json"
        
        if [[ ! -f "${wz_outputs}" ]]; then
            continue
        fi
        
        local vnet_id
        vnet_id=$(jq -r '.vnet_id.value // empty' "${wz_outputs}")
        
        if [[ -z "${vnet_id}" ]]; then
            print_error "✗ No VNet ID found: ${env}"
            TEST_RESULTS+=("✗ Resource Conflicts ${env} - FAILED (no VNet ID)")
            continue
        fi
        
        # Check for duplicate VNet IDs
        if [[ -v "vnet_ids[${vnet_id}]" ]]; then
            print_error "✗ Duplicate VNet ID: ${vnet_id} (${env} and ${vnet_ids[${vnet_id}]})"
            TEST_RESULTS+=("✗ Resource Conflicts - FAILED (duplicate VNet)")
            continue
        fi
        
        vnet_ids["${vnet_id}"]="${env}"
        print_success "✓ Unique VNet ID: ${env}"
    done
    
    TEST_RESULTS+=("✓ Resource Conflicts - PASSED")
}

function deploy_all_environments_sequential() {
    print_banner "Sequential Deployment (Dev → UAT → Prod)"
    
    for i in "${!ENVIRONMENTS[@]}"; do
        local env="${ENVIRONMENTS[$i]}"
        local region="${REGIONS[$i]}"
        
        test_workload_zone_deployment "${env}" "${region}" || continue
        test_vm_deployment "${env}" "${region}" || continue
    done
}

function deploy_all_environments_parallel() {
    print_banner "Parallel Deployment (All Environments)"
    
    local pids=()
    
    # Deploy workload zones in parallel
    for i in "${!ENVIRONMENTS[@]}"; do
        local env="${ENVIRONMENTS[$i]}"
        local region="${REGIONS[$i]}"
        
        (test_workload_zone_deployment "${env}" "${region}") &
        pids+=($!)
    done
    
    # Wait for all workload zones
    for pid in "${pids[@]}"; do
        wait "${pid}" || print_warning "Process ${pid} failed"
    done
    
    pids=()
    
    # Deploy VMs in parallel
    for i in "${!ENVIRONMENTS[@]}"; do
        local env="${ENVIRONMENTS[$i]}"
        local region="${REGIONS[$i]}"
        
        (test_vm_deployment "${env}" "${region}") &
        pids+=($!)
    done
    
    # Wait for all VMs
    for pid in "${pids[@]}"; do
        wait "${pid}" || print_warning "Process ${pid} failed"
    done
}

function cleanup_all_environments() {
    if [[ "${CLEANUP}" != "true" ]]; then
        print_warning "Cleanup not requested (use --cleanup to destroy resources)"
        return 0
    fi
    
    print_banner "Cleaning Up All Environments"
    
    for i in "${!ENVIRONMENTS[@]}"; do
        local env="${ENVIRONMENTS[$i]}"
        local region="${REGIONS[$i]}"
        
        print_info "Destroying ${env}..."
        
        cd "${SCRIPT_DIR}"
        
        # Destroy VMs
        ./deploy_vm.sh -e "${env}" -r "${region}" -n "${WORKLOAD_NAME}" --destroy -y 2>/dev/null || true
        
        # Destroy workload zone
        ./deploy_workload_zone.sh -e "${env}" -r "${region}" --destroy -y 2>/dev/null || true
        
        print_success "✓ Destroyed: ${env}"
    done
    
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
            -p|--project-code)
                PROJECT_CODE="$2"
                shift 2
                ;;
            -n|--workload)
                WORKLOAD_NAME="$2"
                shift 2
                ;;
            --parallel)
                PARALLEL=true
                shift
                ;;
            --cleanup)
                CLEANUP=true
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
    
    # Deploy environments
    if [[ "${PARALLEL}" == "true" ]]; then
        deploy_all_environments_parallel
    else
        deploy_all_environments_sequential
    fi
    
    # Run verification tests
    verify_state_isolation
    verify_environment_specific_config
    verify_no_resource_conflicts
    
    # Cleanup if requested
    cleanup_all_environments
    
    # Print summary
    print_test_summary
}

# Run main function
main "$@"
