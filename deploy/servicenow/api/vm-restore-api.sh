#!/bin/bash

# ServiceNow API Wrapper: VM Backup/Restore
# Transforms ServiceNow backup/restore requests into VM operations pipeline calls
# Part of Phase 3: ServiceNow Integration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/../logs"
mkdir -p "$LOG_DIR"

log() {
    echo "[$(date -Iseconds)] $1" | tee -a "${LOG_DIR}/vm-restore-api.log"
}

parse_servicenow_payload() {
    local JSON_PAYLOAD="$1"
    
    TICKET_ID=$(echo "$JSON_PAYLOAD" | jq -r '.sys_id // empty')
    VM_NAME=$(echo "$JSON_PAYLOAD" | jq -r '.variables.vm_name // empty')
    BACKUP_ACTION=$(echo "$JSON_PAYLOAD" | jq -r '.variables.backup_action // "restore"')
    RECOVERY_POINT_ID=$(echo "$JSON_PAYLOAD" | jq -r '.variables.recovery_point_id // empty')
    RECOVERY_POINT_DATE=$(echo "$JSON_PAYLOAD" | jq -r '.variables.recovery_point_date // empty')
    ENVIRONMENT=$(echo "$JSON_PAYLOAD" | jq -r '.variables.environment // "dev"')
    REASON=$(echo "$JSON_PAYLOAD" | jq -r '.variables.reason // empty')
    REQUESTED_FOR=$(echo "$JSON_PAYLOAD" | jq -r '.requested_for.display_value // "Unknown"')
    
    log "Parsed ServiceNow payload:"
    log "  Ticket ID: $TICKET_ID"
    log "  VM Name: $VM_NAME"
    log "  Action: $BACKUP_ACTION"
    log "  Recovery Point ID: $RECOVERY_POINT_ID"
    log "  Recovery Date: $RECOVERY_POINT_DATE"
    log "  Environment: $ENVIRONMENT"
    log "  Requested For: $REQUESTED_FOR"
}

validate_input() {
    if [ -z "$TICKET_ID" ]; then
        log "ERROR: ServiceNow ticket ID required"
        exit 1
    fi
    
    if [ -z "$VM_NAME" ]; then
        log "ERROR: VM name required"
        exit 1
    fi
    
    if [[ ! "$BACKUP_ACTION" =~ ^(restore|list-recovery-points)$ ]]; then
        log "ERROR: Invalid backup action. Must be 'restore' or 'list-recovery-points'"
        exit 1
    fi
    
    if [ "$BACKUP_ACTION" == "restore" ] && [ -z "$RECOVERY_POINT_ID" ]; then
        log "ERROR: Recovery point ID required for restore operation"
        exit 1
    fi
    
    log "Input validation passed"
}

trigger_azure_devops_pipeline() {
    log "Triggering Azure DevOps VM Operations pipeline..."
    
    AZURE_DEVOPS_ORG="${AZURE_DEVOPS_ORG:-https://dev.azure.com/yourorg}"
    AZURE_DEVOPS_PROJECT="${AZURE_DEVOPS_PROJECT:-YourProject}"
    AZURE_DEVOPS_PIPELINE_ID="${VM_OPERATIONS_PIPELINE_ID:-124}"
    AZURE_DEVOPS_PAT="${AZURE_DEVOPS_PAT}"
    
    if [ -z "$AZURE_DEVOPS_PAT" ]; then
        log "ERROR: AZURE_DEVOPS_PAT not set"
        exit 1
    fi
    
    PIPELINE_URL="${AZURE_DEVOPS_ORG}/${AZURE_DEVOPS_PROJECT}/_apis/pipelines/${AZURE_DEVOPS_PIPELINE_ID}/runs?api-version=7.0"
    
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
    "operationType": "backup-restore",
    "vmName": "${VM_NAME}",
    "backupAction": "${BACKUP_ACTION}",
    "recoveryPointId": "${RECOVERY_POINT_ID}",
    "serviceNowTicket": "${TICKET_ID}",
    "reason": "${REASON}",
    "autoApprove": false
  }
}
EOF
)
    
    log "Pipeline parameters: $PIPELINE_PARAMS"
    
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
    
    log "Pipeline triggered - Run ID: $RUN_ID"
    echo "$RUN_ID" > "${LOG_DIR}/${TICKET_ID}.runid"
    echo "$RUN_URL" > "${LOG_DIR}/${TICKET_ID}.runurl"
}

update_servicenow_ticket() {
    local TICKET_ID="$1"
    local STATUS="$2"
    local MESSAGE="$3"
    
    log "Updating ServiceNow ticket: $TICKET_ID"
    
    SNOW_INSTANCE="${SNOW_INSTANCE:-your-instance.service-now.com}"
    SNOW_USERNAME="${SNOW_USERNAME}"
    SNOW_PASSWORD="${SNOW_PASSWORD}"
    
    if [ -z "$SNOW_USERNAME" ] || [ -z "$SNOW_PASSWORD" ]; then
        log "WARNING: ServiceNow credentials not set"
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

main() {
    log "=============================================="
    log "ServiceNow VM Backup/Restore API"
    log "=============================================="
    
    if [ -z "$1" ]; then
        log "ERROR: JSON payload required"
        echo "Usage: $0 '<json_payload>'"
        echo ""
        echo "Examples:"
        echo "  List recovery points:"
        echo "    $0 '{\"sys_id\":\"123\",\"variables\":{\"vm_name\":\"testvm\",\"backup_action\":\"list-recovery-points\"}}'"
        echo ""
        echo "  Restore from recovery point:"
        echo "    $0 '{\"sys_id\":\"123\",\"variables\":{\"vm_name\":\"testvm\",\"backup_action\":\"restore\",\"recovery_point_id\":\"rec-123\"}}'"
        exit 1
    fi
    
    JSON_PAYLOAD="$1"
    
    parse_servicenow_payload "$JSON_PAYLOAD"
    validate_input
    
    if [ "$BACKUP_ACTION" == "restore" ]; then
        update_servicenow_ticket "$TICKET_ID" "work_in_progress" "VM restore request received. Initiating restore from recovery point: $RECOVERY_POINT_ID"
    else
        update_servicenow_ticket "$TICKET_ID" "work_in_progress" "Recovery points list request received. Fetching available recovery points..."
    fi
    
    if trigger_azure_devops_pipeline; then
        if [ "$BACKUP_ACTION" == "restore" ]; then
            update_servicenow_ticket "$TICKET_ID" "work_in_progress" "VM restore pipeline triggered. Restore operation in progress..."
        else
            update_servicenow_ticket "$TICKET_ID" "work_in_progress" "Recovery points pipeline triggered. Listing available backups..."
        fi
        
        cat <<EOF
{
  "status": "success",
  "message": "Backup/restore pipeline triggered successfully",
  "ticket_id": "$TICKET_ID",
  "vm_name": "$VM_NAME",
  "action": "$BACKUP_ACTION",
  "run_url": "$(cat ${LOG_DIR}/${TICKET_ID}.runurl)"
}
EOF
    else
        log "ERROR: Failed to trigger pipeline"
        update_servicenow_ticket "$TICKET_ID" "closed_incomplete" "Failed to trigger backup/restore pipeline."
        exit 1
    fi
    
    log "Backup/Restore API completed successfully"
}

main "$@"
