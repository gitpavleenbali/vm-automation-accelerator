# ServiceNow Integration for VM Automation Accelerator
# Helper script for ServiceNow change management integration

param(
    [Parameter(Mandatory=$true)]
    [string]$ServiceNowInstance,
    
    [Parameter(Mandatory=$true)]  
    [string]$Username,
    
    [Parameter(Mandatory=$true)]
    [string]$Password,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("create", "update", "validate", "close")]
    [string]$Action,
    
    [Parameter(Mandatory=$false)]
    [string]$ChangeTicket,
    
    [Parameter(Mandatory=$false)]
    [string]$Environment,
    
    [Parameter(Mandatory=$false)]
    [string]$DeploymentResults
)

# ServiceNow REST API configuration
$ServiceNowUrl = "https://$ServiceNowInstance.service-now.com"
$Headers = @{
    'Authorization' = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$Username`:$Password"))
    'Content-Type' = 'application/json'
    'Accept' = 'application/json'
}

function New-ServiceNowChangeRequest {
    param(
        [string]$Summary,
        [string]$Description,
        [string]$Environment
    )
    
    $changeData = @{
        short_description = $Summary
        description = $Description
        category = "Infrastructure"
        type = "Standard"
        risk = if ($Environment -eq "prod") { "High" } else { "Low" }
        priority = if ($Environment -eq "prod") { "2" } else { "4" }
        requested_by = $Username
        assignment_group = "Infrastructure Team"
        implementation_plan = @"
Automated deployment of VM Automation Accelerator infrastructure:

1. Deploy Control Plane (Resource Groups, Storage)
2. Deploy Workload Zone (Networking, Security Groups)  
3. Deploy VM Layer (Virtual Machines with Managed Identity)
4. Validate deployment and perform health checks

Environment: $Environment
Deployment Method: Azure DevOps Pipeline
Rollback Plan: Terraform destroy in reverse order
"@
    } | ConvertTo-Json -Depth 10
    
    try {
        $response = Invoke-RestMethod -Uri "$ServiceNowUrl/api/now/table/change_request" -Method Post -Headers $Headers -Body $changeData
        Write-Host "✅ Change request created: $($response.result.number)" -ForegroundColor Green
        return $response.result.number
    }
    catch {
        Write-Error "Failed to create ServiceNow change request: $_"
        throw
    }
}

function Get-ServiceNowChangeRequest {
    param([string]$TicketNumber)
    
    try {
        $response = Invoke-RestMethod -Uri "$ServiceNowUrl/api/now/table/change_request?sysparm_query=number=$TicketNumber" -Method Get -Headers $Headers
        
        if ($response.result.Count -eq 0) {
            throw "Change request $TicketNumber not found"
        }
        
        return $response.result[0]
    }
    catch {
        Write-Error "Failed to retrieve ServiceNow change request: $_"
        throw
    }
}

function Update-ServiceNowChangeRequest {
    param(
        [string]$TicketNumber,
        [string]$WorkNotes,
        [string]$State
    )
    
    try {
        $change = Get-ServiceNowChangeRequest -TicketNumber $TicketNumber
        
        $updateData = @{
            work_notes = $WorkNotes
        }
        
        if ($State) {
            $updateData.state = switch ($State) {
                "implementing" { "2" }
                "completed" { "3" }
                "failed" { "-4" }
                default { $State }
            }
        }
        
        $jsonData = $updateData | ConvertTo-Json -Depth 10
        $response = Invoke-RestMethod -Uri "$ServiceNowUrl/api/now/table/change_request/$($change.sys_id)" -Method Put -Headers $Headers -Body $jsonData
        
        Write-Host "✅ Change request $TicketNumber updated successfully" -ForegroundColor Green
        return $response.result
    }
    catch {
        Write-Error "Failed to update ServiceNow change request: $_"
        throw
    }
}

function Test-ServiceNowChangeApproval {
    param([string]$TicketNumber)
    
    try {
        $change = Get-ServiceNowChangeRequest -TicketNumber $TicketNumber
        
        $approvalState = $change.approval
        $changeState = $change.state
        
        Write-Host "Change Request Status:" -ForegroundColor Cyan
        Write-Host "  Number: $($change.number)"
        Write-Host "  State: $($change.state)"
        Write-Host "  Approval: $($change.approval)"
        Write-Host "  Risk: $($change.risk)"
        
        # Check if change is approved and scheduled
        if ($approvalState -eq "approved" -and $changeState -eq "scheduled") {
            Write-Host "✅ Change request is approved and ready for implementation" -ForegroundColor Green
            return $true
        }
        elseif ($approvalState -eq "not_requested" -or $approvalState -eq "requested") {
            Write-Warning "⚠️ Change request is pending approval"
            return $false
        }
        elseif ($approvalState -eq "rejected") {
            Write-Error "❌ Change request has been rejected"
            return $false
        }
        else {
            Write-Warning "⚠️ Change request status unclear - State: $changeState, Approval: $approvalState"
            return $false
        }
    }
    catch {
        Write-Error "Failed to validate ServiceNow change approval: $_"
        throw
    }
}

# Main script execution
switch ($Action) {
    "create" {
        $summary = "VM Automation Accelerator Deployment - $Environment Environment"
        $description = "Automated deployment of 3-tier VM infrastructure using Terraform and Azure DevOps pipeline"
        $ticket = New-ServiceNowChangeRequest -Summary $summary -Description $description -Environment $Environment
        Write-Output $ticket
    }
    
    "validate" {
        if (-not $ChangeTicket) {
            throw "ChangeTicket parameter is required for validate action"
        }
        $isApproved = Test-ServiceNowChangeApproval -TicketNumber $ChangeTicket
        if (-not $isApproved) {
            exit 1
        }
    }
    
    "update" {
        if (-not $ChangeTicket) {
            throw "ChangeTicket parameter is required for update action"
        }
        
        $workNotes = if ($DeploymentResults) {
            "Deployment Results:`n$DeploymentResults"
        } else {
            "Deployment in progress for $Environment environment via Azure DevOps pipeline"
        }
        
        Update-ServiceNowChangeRequest -TicketNumber $ChangeTicket -WorkNotes $workNotes -State "implementing"
    }
    
    "close" {
        if (-not $ChangeTicket) {
            throw "ChangeTicket parameter is required for close action"
        }
        
        $workNotes = @"
Deployment completed successfully for $Environment environment.

Deployment Summary:
$DeploymentResults

Infrastructure validated and operational.
Change request can be closed.
"@
        
        Update-ServiceNowChangeRequest -TicketNumber $ChangeTicket -WorkNotes $workNotes -State "completed"
    }
}