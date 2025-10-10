#!/bin/bash

# ServiceNow API Wrapper: VM Disk Modification
# Transforms ServiceNow disk modification requests into VM operations pipeline calls
# Part of Phase 3: ServiceNow Integration

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/../logs"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Function to log messages
log() {
    echo "[$(date -Iseconds)] $1" | tee -a "${LOG_DIR}/vm-disk-modify-api.log"
}

# Function to parse ServiceNow JSON payload
parse_servicenow_payload() {
    local JSON_PAYLOAD="$1"
    
    TICKET_ID=$(echo "$JSON_PAYLOAD" | jq -r '.sys_id // empty')
    VM_NAME=$(echo "$JSON_PAYLOAD" | jq -r '.variables.vm_name // empty')
    DISK_OPERATION=$(echo "$JSON_PAYLOAD" | jq -r '.variables.disk_operation // "add"')
    DISK_SIZE_GB=$(echo "$JSON_PAYLOAD" | jq -r '.variables.disk_size_gb // "128"')
    DISK_NAME=$(echo "$JSON_PAYLOAD" | jq -r '.variables.disk_name // empty')
    DISK_TYPE=$(echo "$JSON_PAYLOAD" | jq -r '.variables.disk_type // "Premium_LRS"')
    ENVIRONMENT=$(echo "$JSON_PAYLOAD" | jq -r '.variables.environment // "dev"')
    REASON=$(echo "$JSON_PAYLOAD" | jq -r '.variables.reason // empty')
    REQUESTED_FOR=$(echo "$JSON_PAYLOAD" | jq -r '.requested_for.display_value // "Unknown"')
    
    log "Parsed ServiceNow payload:"
    log "  Ticket ID: $TICKET_ID"
    log "  VM Name: $VM_NAME"
    log "  Operation: $DISK_OPERATION"
    log "  Disk Size: $DISK_SIZE_GB GB"
    log "  Disk Name: $DISK_NAME"
    log "  Disk Type: $DISK_TYPE"
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
    
    if [[ ! "$DISK_OPERATION" =~ ^(add|resize|delete)$ ]]; then
        log "ERROR: Invalid disk operation. Must be add, resize, or delete"
        exit 1
    fi
    
    if [ "$DISK_OPERATION" == "add" ] || [ "$DISK_OPERATION" == "resize" ]; then
        if [ "$DISK_SIZE_GB" -lt 32 ]; then
            log "ERROR: Disk size must be at least 32 GB"
            exit 1
        fi
    fi
    
    if [ "$DISK_OPERATION" == "resize" ] || [ "$DISK_OPERATION" == "delete" ]; then
        if [ -z "$DISK_NAME" ]; then
            log "ERROR: Disk name is required for resize/delete operations"
            exit 1
        fi
    fi
    
    log "Input validation passed"
}

# Function to trigger Azure DevOps pipeline
trigger_azure_devops_pipeline() {
    log "Triggering Azure DevOps VM Operations pipeline..."
    
    # Azure DevOps configuration
    AZURE_DEVOPS_ORG="${AZURE_DEVOPS_ORG:-https://dev.azure.com/yourorg}"
    AZURE_DEVOPS_PROJECT="${AZURE_DEVOPS_PROJECT:-YourProject}"
    AZURE_DEVOPS_PIPELINE_ID="${VM_OPERATIONS_PIPELINE_ID:-124}"
    AZURE_DEVOPS_PAT="${AZURE_DEVOPS_PAT}"
    
    if [ -z "$AZURE_DEVOPS_PAT" ]; then
        log "ERROR: AZURE_DEVOPS_PAT environment variable not set"
        exit 1
    fi
    
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
    "operationType": "disk-modify",
    "vmName": "${VM_NAME}",
    "diskOperation": "${DISK_OPERATION}",
    "diskSizeGB": ${DISK_SIZE_GB},
    "diskName": "${DISK_NAME}",
    "diskType": "${DISK_TYPE}",
    "serviceNowTicket": "${TICKET_ID}",
    "reason": "${REASON}",
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
    
    echo "$RUN_ID" > "${LOG_DIR}/${TICKET_ID}.runid"
    echo "$RUN_URL" > "${LOG_DIR}/${TICKET_ID}.runurl"
}

# Function to update ServiceNow ticket
update_servicenow_ticket() {
    local TICKET_ID="$1"
    local STATUS="$2"
    local MESSAGE="$3"
    
    log "Updating ServiceNow ticket: $TICKET_ID"
    
    SNOW_INSTANCE="${SNOW_INSTANCE:-your-instance.service-now.com}"
    SNOW_USERNAME="${SNOW_USERNAME}"
    SNOW_PASSWORD="${SNOW_PASSWORD}"
    
    if [ -z "$SNOW_USERNAME" ] || [ -z "$SNOW_PASSWORD" ]; then
        log "WARNING: ServiceNow credentials not set, skipping ticket update"
        return
    fi
    
    RUN_URL=$(cat "${LOG_DIR}/${TICKET_ID}.runurl" 2>/dev/null || echo "")
    
    UPDATE_JSON=$(cat <<EOF
{
  "work_notes": "${MESSAGE}\\n\\nPipeline URL: ${RUN_URL}",
  "state": "${STATUS}"
}
EOF
)
    
    curl -s -X PATCH \
        "https://${SNOW_INSTANCE}/api/now/table/sc_req_item/${TICKET_ID}" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -u "${SNOW_USERNAME}:${SNOW_PASSWORD}" \
        -d "$UPDATE_JSON" > /dev/null
    
    log "ServiceNow ticket updated"
}

# Main execution
main() {
    log "=============================================="
    log "ServiceNow VM Disk Modification API"
    log "=============================================="
    
    if [ -z "$1" ]; then
        log "ERROR: JSON payload required"
        echo "Usage: $0 '<json_payload>'"
        echo "Example: $0 '{\"sys_id\":\"123\",\"variables\":{\"vm_name\":\"testvm\",\"disk_operation\":\"add\",\"disk_size_gb\":\"256\"}}'"
        exit 1
    fi
    
    JSON_PAYLOAD="$1"
    
    parse_servicenow_payload "$JSON_PAYLOAD"
    validate_input
    
    update_servicenow_ticket "$TICKET_ID" "work_in_progress" "Disk modification request received. Initiating operation..."
    
    if trigger_azure_devops_pipeline; then
        log "Pipeline triggered successfully"
        update_servicenow_ticket "$TICKET_ID" "work_in_progress" "Disk modification pipeline triggered. Operation in progress..."
        
        cat <<EOF
{
  "status": "success",
  "message": "Disk modification pipeline triggered successfully",
  "ticket_id": "$TICKET_ID",
  "vm_name": "$VM_NAME",
  "operation": "$DISK_OPERATION",
  "run_url": "$(cat ${LOG_DIR}/${TICKET_ID}.runurl)"
}
EOF
    else
        log "ERROR: Failed to trigger pipeline"
        update_servicenow_ticket "$TICKET_ID" "closed_incomplete" "Failed to trigger disk modification pipeline. Please check logs."
        exit 1
    fi
    
    log "=============================================="
    log "Disk Modification API completed successfully"
    log "=============================================="
}

main "$@"
