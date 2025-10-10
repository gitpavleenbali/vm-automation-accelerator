#!/bin/bash

# ServiceNow API Wrapper: VM Order
# Transforms ServiceNow catalog requests into SAP deployment script calls
# Part of Phase 3: ServiceNow Integration

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_SCRIPT="${SCRIPT_DIR}/../../scripts/deploy_vm.sh"
LOG_DIR="${SCRIPT_DIR}/../logs"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Function to log messages
log() {
    echo "[$(date -Iseconds)] $1" | tee -a "${LOG_DIR}/vm-order-api.log"
}

# Function to parse ServiceNow JSON payload
parse_servicenow_payload() {
    local JSON_PAYLOAD="$1"
    
    # Extract fields from ServiceNow JSON
    # Expected fields:
    # - sys_id: ServiceNow ticket ID
    # - short_description: VM name or description
    # - requested_for: User requesting VM
    # - variables.vm_name: VM name
    # - variables.vm_size: VM SKU
    # - variables.os_type: Windows or Linux
    # - variables.environment: dev/uat/prod
    # - variables.enable_backup: true/false
    # - variables.enable_monitoring: true/false
    
    TICKET_ID=$(echo "$JSON_PAYLOAD" | jq -r '.sys_id // empty')
    VM_NAME=$(echo "$JSON_PAYLOAD" | jq -r '.variables.vm_name // empty')
    VM_SIZE=$(echo "$JSON_PAYLOAD" | jq -r '.variables.vm_size // "Standard_D2s_v3"')
    OS_TYPE=$(echo "$JSON_PAYLOAD" | jq -r '.variables.os_type // "Linux"')
    ENVIRONMENT=$(echo "$JSON_PAYLOAD" | jq -r '.variables.environment // "dev"')
    ENABLE_BACKUP=$(echo "$JSON_PAYLOAD" | jq -r '.variables.enable_backup // "true"')
    ENABLE_MONITORING=$(echo "$JSON_PAYLOAD" | jq -r '.variables.enable_monitoring // "true"')
    REQUESTED_FOR=$(echo "$JSON_PAYLOAD" | jq -r '.requested_for.display_value // "Unknown"')
    
    log "Parsed ServiceNow payload:"
    log "  Ticket ID: $TICKET_ID"
    log "  VM Name: $VM_NAME"
    log "  VM Size: $VM_SIZE"
    log "  OS Type: $OS_TYPE"
    log "  Environment: $ENVIRONMENT"
    log "  Requested For: $REQUESTED_FOR"
}

# Function to validate input
validate_input() {
    if [ -z "$TICKET_ID" ]; then
        log "ERROR: ServiceNow ticket ID (sys_id) is required"
        exit 1
    fi
    
    if [ -z "$VM_NAME" ]; then
        log "ERROR: VM name is required"
        exit 1
    fi
    
    log "Input validation passed"
}

# Function to trigger Azure DevOps pipeline
trigger_azure_devops_pipeline() {
    local TICKET_ID="$1"
    local VM_NAME="$2"
    local VM_SIZE="$3"
    local OS_TYPE="$4"
    local ENVIRONMENT="$5"
    local ENABLE_BACKUP="$6"
    local ENABLE_MONITORING="$7"
    
    log "Triggering Azure DevOps pipeline..."
    
    # Azure DevOps configuration (should be in environment variables)
    AZURE_DEVOPS_ORG="${AZURE_DEVOPS_ORG:-https://dev.azure.com/yourorg}"
    AZURE_DEVOPS_PROJECT="${AZURE_DEVOPS_PROJECT:-YourProject}"
    AZURE_DEVOPS_PIPELINE_ID="${VM_DEPLOYMENT_PIPELINE_ID:-123}"  # VM deployment pipeline ID
    AZURE_DEVOPS_PAT="${AZURE_DEVOPS_PAT}"
    
    if [ -z "$AZURE_DEVOPS_PAT" ]; then
        log "ERROR: AZURE_DEVOPS_PAT environment variable not set"
        exit 1
    fi
    
    # Build pipeline API URL
    PIPELINE_URL="${AZURE_DEVOPS_ORG}/${AZURE_DEVOPS_PROJECT}/_apis/pipelines/${AZURE_DEVOPS_PIPELINE_ID}/runs?api-version=7.0"
    
    # Create pipeline parameters JSON
    PIPELINE_PARAMS=$(cat <<EOF
{
  "resources": {
    "repositories": {
      "self": {
        "refName": "refs/heads/main"
      }
    }
  },
  "templateParameters": {
    "environment": "${ENVIRONMENT}",
    "vmName": "${VM_NAME}",
    "vmSize": "${VM_SIZE}",
    "osType": "${OS_TYPE}",
    "action": "deploy",
    "serviceNowTicket": "${TICKET_ID}",
    "enableBackup": ${ENABLE_BACKUP},
    "enableMonitoring": ${ENABLE_MONITORING},
    "autoApprove": false
  }
}
EOF
)
    
    log "Pipeline parameters:"
    log "$PIPELINE_PARAMS"
    
    # Trigger pipeline
    RESPONSE=$(curl -s -X POST "$PIPELINE_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: Basic $(echo -n :${AZURE_DEVOPS_PAT} | base64)" \
        -d "$PIPELINE_PARAMS")
    
    # Extract run ID
    RUN_ID=$(echo "$RESPONSE" | jq -r '.id // empty')
    RUN_URL=$(echo "$RESPONSE" | jq -r '._links.web.href // empty')
    
    if [ -z "$RUN_ID" ]; then
        log "ERROR: Failed to trigger pipeline"
        log "Response: $RESPONSE"
        exit 1
    fi
    
    log "Pipeline triggered successfully"
    log "  Run ID: $RUN_ID"
    log "  Run URL: $RUN_URL"
    
    # Store for ServiceNow update
    echo "$RUN_ID" > "${LOG_DIR}/${TICKET_ID}.runid"
    echo "$RUN_URL" > "${LOG_DIR}/${TICKET_ID}.runurl"
}

# Function to update ServiceNow ticket
update_servicenow_ticket() {
    local TICKET_ID="$1"
    local STATUS="$2"
    local MESSAGE="$3"
    
    log "Updating ServiceNow ticket: $TICKET_ID"
    
    # ServiceNow configuration (should be in environment variables)
    SNOW_INSTANCE="${SNOW_INSTANCE:-your-instance.service-now.com}"
    SNOW_USERNAME="${SNOW_USERNAME}"
    SNOW_PASSWORD="${SNOW_PASSWORD}"
    
    if [ -z "$SNOW_USERNAME" ] || [ -z "$SNOW_PASSWORD" ]; then
        log "WARNING: ServiceNow credentials not set, skipping ticket update"
        return
    fi
    
    # Get pipeline run URL
    RUN_URL=$(cat "${LOG_DIR}/${TICKET_ID}.runurl" 2>/dev/null || echo "")
    
    # Build update JSON
    UPDATE_JSON=$(cat <<EOF
{
  "work_notes": "${MESSAGE}\\n\\nPipeline URL: ${RUN_URL}",
  "state": "${STATUS}"
}
EOF
)
    
    # Update ticket
    RESPONSE=$(curl -s -X PATCH \
        "https://${SNOW_INSTANCE}/api/now/table/sc_req_item/${TICKET_ID}" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -u "${SNOW_USERNAME}:${SNOW_PASSWORD}" \
        -d "$UPDATE_JSON")
    
    log "ServiceNow ticket updated"
}

# Function to call deployment script directly (alternative to pipeline)
call_deployment_script() {
    local VM_NAME="$1"
    local ENVIRONMENT="$2"
    
    log "Calling deployment script directly..."
    
    # Build script arguments
    SCRIPT_ARGS="-e ${ENVIRONMENT} -r eastus -n ${VM_NAME}"
    
    # Add additional arguments
    if [ "$ENABLE_BACKUP" == "true" ]; then
        SCRIPT_ARGS="$SCRIPT_ARGS --enable-backup"
    fi
    
    if [ "$ENABLE_MONITORING" == "true" ]; then
        SCRIPT_ARGS="$SCRIPT_ARGS --enable-monitoring"
    fi
    
    # Execute deployment script
    log "Executing: $DEPLOY_SCRIPT $SCRIPT_ARGS"
    
    if bash "$DEPLOY_SCRIPT" $SCRIPT_ARGS; then
        log "Deployment completed successfully"
        return 0
    else
        log "ERROR: Deployment failed"
        return 1
    fi
}

# Main execution
main() {
    log "=============================================="
    log "ServiceNow VM Order API"
    log "=============================================="
    
    # Check if JSON payload provided
    if [ -z "$1" ]; then
        log "ERROR: JSON payload required as first argument"
        echo "Usage: $0 '<json_payload>'"
        echo "Example: $0 '{\"sys_id\":\"123\",\"variables\":{\"vm_name\":\"testvm\",\"environment\":\"dev\"}}'"
        exit 1
    fi
    
    JSON_PAYLOAD="$1"
    
    # Parse ServiceNow payload
    parse_servicenow_payload "$JSON_PAYLOAD"
    
    # Validate input
    validate_input
    
    # Update ServiceNow ticket - request received
    update_servicenow_ticket "$TICKET_ID" "work_in_progress" "VM order request received. Initiating deployment..."
    
    # Deployment method: Pipeline (preferred) or Direct Script
    DEPLOYMENT_METHOD="${DEPLOYMENT_METHOD:-pipeline}"
    
    if [ "$DEPLOYMENT_METHOD" == "pipeline" ]; then
        # Trigger Azure DevOps pipeline
        if trigger_azure_devops_pipeline "$TICKET_ID" "$VM_NAME" "$VM_SIZE" "$OS_TYPE" "$ENVIRONMENT" "$ENABLE_BACKUP" "$ENABLE_MONITORING"; then
            log "Pipeline triggered successfully"
            update_servicenow_ticket "$TICKET_ID" "work_in_progress" "Azure DevOps pipeline triggered. Deployment in progress..."
            
            # Return success with run details
            cat <<EOF
{
  "status": "success",
  "message": "Pipeline triggered successfully",
  "ticket_id": "$TICKET_ID",
  "vm_name": "$VM_NAME",
  "run_url": "$(cat ${LOG_DIR}/${TICKET_ID}.runurl)"
}
EOF
        else
            log "ERROR: Failed to trigger pipeline"
            update_servicenow_ticket "$TICKET_ID" "closed_incomplete" "Failed to trigger deployment pipeline. Please check logs."
            exit 1
        fi
    else
        # Call deployment script directly
        if call_deployment_script "$VM_NAME" "$ENVIRONMENT"; then
            log "Deployment completed successfully"
            update_servicenow_ticket "$TICKET_ID" "closed_complete" "VM deployment completed successfully"
            
            cat <<EOF
{
  "status": "success",
  "message": "VM deployed successfully",
  "ticket_id": "$TICKET_ID",
  "vm_name": "$VM_NAME"
}
EOF
        else
            log "ERROR: Deployment failed"
            update_servicenow_ticket "$TICKET_ID" "closed_incomplete" "VM deployment failed. Please check logs."
            exit 1
        fi
    fi
    
    log "=============================================="
    log "VM Order API completed successfully"
    log "=============================================="
}

# Execute main function
main "$@"
