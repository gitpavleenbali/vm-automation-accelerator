# ServiceNow Integration Scripts

This directory contains scripts for integrating Azure VM automation with ServiceNow ITSM workflows.

## Overview

These scripts enable bidirectional integration between Azure VM deployment automation and ServiceNow:
- Automated ticket creation for VM requests
- Deployment status updates
- Change management integration
- Incident tracking
- Approval workflow automation
- CMDB synchronization

## Scripts

### servicenow_client.py

**Purpose**: Python client library for ServiceNow API integration providing automated ticket management, change requests, and CMDB updates for Azure VM deployments.

**Prerequisites**:
- Python 3.8 or later
- Required packages: `requests`, `azure-identity`, `python-dotenv`
- ServiceNow instance with API access enabled
- ServiceNow credentials (username/password or OAuth token)
- Network connectivity to ServiceNow instance

**Installation**:
```bash
pip install requests azure-identity python-dotenv
# Or use requirements file:
pip install -r requirements.txt
```

**Configuration**:

Create a `.env` file or set environment variables:
```bash
# ServiceNow Instance Configuration
SERVICENOW_INSTANCE=your-instance.service-now.com
SERVICENOW_USERNAME=api_user
SERVICENOW_PASSWORD=your_password
# Or use OAuth
SERVICENOW_CLIENT_ID=your_client_id
SERVICENOW_CLIENT_SECRET=your_client_secret

# Azure Configuration (for CMDB sync)
AZURE_SUBSCRIPTION_ID=12345678-1234-1234-1234-123456789012
AZURE_TENANT_ID=tenant-id
```

**Usage as Python Module**:
```python
from servicenow_client import ServiceNowClient

# Initialize client
client = ServiceNowClient(
    instance='your-instance.service-now.com',
    username='api_user',
    password='your_password'
)

# Create incident
incident = client.create_incident(
    short_description='VM deployment failed',
    description='VM vm-app-01 deployment failed in eastus region',
    urgency='2',
    impact='2',
    category='Infrastructure',
    subcategory='Virtual Machine'
)
print(f"Incident created: {incident['number']}")

# Update incident
client.update_incident(
    incident_id=incident['sys_id'],
    state='Work In Progress',
    work_notes='Investigating root cause...'
)

# Create change request
change_request = client.create_change_request(
    short_description='Deploy 10 production VMs',
    description='Production VM deployment for Q1 2024',
    risk='Medium',
    impact='Moderate',
    type='Standard',
    requested_by='user@company.com'
)
print(f"Change Request: {change_request['number']}")

# Update CMDB with VM information
vm_ci = client.update_cmdb(
    ci_class='cmdb_ci_vm_instance',
    name='vm-app-01',
    attributes={
        'cpu_count': 4,
        'ram': 16384,
        'os': 'Windows Server 2022',
        'location': 'East US',
        'vm_inst_id': '/subscriptions/.../virtualMachines/vm-app-01',
        'status': 'Running'
    }
)
```

**Usage as Command-Line Tool**:
```bash
# Create incident
python deploy/scripts/utilities/servicenow/servicenow_client.py \
  --action create_incident \
  --short-description "VM deployment failed" \
  --description "VM vm-app-01 deployment failed in eastus region" \
  --urgency 2 \
  --impact 2

# Update incident
python deploy/scripts/utilities/servicenow/servicenow_client.py \
  --action update_incident \
  --incident-id "INC0012345" \
  --state "Work In Progress" \
  --work-notes "Investigating root cause"

# Create change request
python deploy/scripts/utilities/servicenow/servicenow_client.py \
  --action create_change_request \
  --short-description "Deploy 10 production VMs" \
  --description "Production VM deployment for Q1 2024" \
  --risk "Medium" \
  --type "Standard"

# Query incidents
python deploy/scripts/utilities/servicenow/servicenow_client.py \
  --action query_incidents \
  --filter "category=Infrastructure^subcategory=Virtual Machine^stateNOT IN6,7" \
  --output incidents.json

# Update CMDB
python deploy/scripts/utilities/servicenow/servicenow_client.py \
  --action update_cmdb \
  --ci-class "cmdb_ci_vm_instance" \
  --ci-name "vm-app-01" \
  --attributes '{"cpu_count":4,"ram":16384,"os":"Windows Server 2022"}'
```

## ServiceNowClient Class

### Methods

#### `create_incident(short_description, description, urgency, impact, **kwargs)`
Creates a new incident in ServiceNow.

**Parameters**:
- `short_description` (str): Brief description of the issue
- `description` (str): Detailed description
- `urgency` (str): Urgency level (1=High, 2=Medium, 3=Low)
- `impact` (str): Impact level (1=High, 2=Medium, 3=Low)
- `category` (str, optional): Incident category
- `subcategory` (str, optional): Incident subcategory
- `assignment_group` (str, optional): Assignment group name
- `assigned_to` (str, optional): User to assign to

**Returns**: Dict containing incident details including `sys_id` and `number`

#### `update_incident(incident_id, **kwargs)`
Updates an existing incident.

**Parameters**:
- `incident_id` (str): Incident sys_id or number
- `state` (str, optional): New state (New, In Progress, Resolved, Closed)
- `work_notes` (str, optional): Work notes to add
- `close_notes` (str, optional): Closing notes
- `resolution_code` (str, optional): Resolution code

**Returns**: Dict containing updated incident details

#### `create_change_request(short_description, description, risk, impact, type, **kwargs)`
Creates a change request in ServiceNow.

**Parameters**:
- `short_description` (str): Brief description of change
- `description` (str): Detailed change description
- `risk` (str): Risk level (High, Medium, Low)
- `impact` (str): Impact level (High, Medium, Low)
- `type` (str): Change type (Standard, Normal, Emergency)
- `requested_by` (str, optional): Requester email
- `start_date` (str, optional): Planned start date (ISO format)
- `end_date` (str, optional): Planned end date (ISO format)

**Returns**: Dict containing change request details

#### `update_change_request(change_id, **kwargs)`
Updates an existing change request.

**Parameters**:
- `change_id` (str): Change request sys_id or number
- `state` (str, optional): New state
- `approval` (str, optional): Approval status (Approved, Rejected, Pending)
- `work_notes` (str, optional): Work notes

**Returns**: Dict containing updated change request details

#### `update_cmdb(ci_class, name, attributes)`
Creates or updates a Configuration Item in CMDB.

**Parameters**:
- `ci_class` (str): CI class (e.g., cmdb_ci_vm_instance, cmdb_ci_server)
- `name` (str): CI name/identifier
- `attributes` (dict): CI attributes to update

**Returns**: Dict containing CI details

#### `query_incidents(filter_query, limit=100)`
Queries incidents based on filter.

**Parameters**:
- `filter_query` (str): Encoded query string
- `limit` (int, optional): Max results (default: 100)

**Returns**: List of incident dicts

## Integration Patterns

### 1. Terraform Integration

Integrate with Terraform using `local-exec` provisioner:

```hcl
# terraform/main.tf
resource "azurerm_virtual_machine" "vm" {
  # ... VM configuration
  
  provisioner "local-exec" {
    command = <<EOT
      python deploy/scripts/utilities/servicenow/servicenow_client.py \
        --action create_incident \
        --short-description "VM ${self.name} deployed" \
        --description "VM ${self.name} successfully deployed to ${var.location}" \
        --urgency 3 \
        --impact 3 \
        --category "Infrastructure" \
        --subcategory "Virtual Machine"
    EOT
  }
  
  provisioner "local-exec" {
    when = destroy
    command = <<EOT
      python deploy/scripts/utilities/servicenow/servicenow_client.py \
        --action create_change_request \
        --short-description "VM ${self.name} decommission" \
        --description "Decommissioning VM ${self.name}" \
        --risk "Low" \
        --type "Standard"
    EOT
  }
}
```

### 2. Azure DevOps Pipeline Integration

Integrate into CI/CD pipelines:

```yaml
# azure-pipelines.yml
stages:
  - stage: Deploy
    jobs:
      - job: DeployVMs
        steps:
          # Create change request before deployment
          - task: PythonScript@0
            displayName: 'Create ServiceNow Change Request'
            inputs:
              scriptPath: 'deploy/scripts/utilities/servicenow/servicenow_client.py'
              arguments: |
                --action create_change_request \
                --short-description "VM Deployment - $(Build.BuildNumber)" \
                --description "Deploying VMs via pipeline $(Build.BuildNumber)" \
                --risk "Medium" \
                --type "Standard" \
                --requested-by "$(Build.RequestedForEmail)"
            env:
              SERVICENOW_INSTANCE: $(SERVICENOW_INSTANCE)
              SERVICENOW_USERNAME: $(SERVICENOW_USERNAME)
              SERVICENOW_PASSWORD: $(SERVICENOW_PASSWORD)
          
          # Deploy infrastructure
          - task: TerraformCLI@0
            displayName: 'Terraform Apply'
            inputs:
              command: 'apply'
              
          # Update change request after deployment
          - task: PythonScript@0
            displayName: 'Update Change Request - Success'
            condition: succeeded()
            inputs:
              scriptPath: 'deploy/scripts/utilities/servicenow/servicenow_client.py'
              arguments: |
                --action update_change_request \
                --change-id "$(CHANGE_REQUEST_ID)" \
                --state "Implement" \
                --work-notes "Deployment completed successfully"
          
          # Create incident on failure
          - task: PythonScript@0
            displayName: 'Create Incident - Failure'
            condition: failed()
            inputs:
              scriptPath: 'deploy/scripts/utilities/servicenow/servicenow_client.py'
              arguments: |
                --action create_incident \
                --short-description "VM Deployment Failed - $(Build.BuildNumber)" \
                --description "Pipeline $(Build.BuildNumber) failed during VM deployment" \
                --urgency 2 \
                --impact 2
```

### 3. Event-Driven Integration

Use Azure Logic Apps or Functions for event-driven updates:

```python
# Azure Function triggered by VM state changes
import azure.functions as func
from servicenow_client import ServiceNowClient

def main(event: func.EventGridEvent):
    client = ServiceNowClient(
        instance=os.environ['SERVICENOW_INSTANCE'],
        username=os.environ['SERVICENOW_USERNAME'],
        password=os.environ['SERVICENOW_PASSWORD']
    )
    
    vm_name = event.subject.split('/')[-1]
    event_type = event.event_type
    
    if event_type == 'Microsoft.Compute.VirtualMachines.Deleted':
        # Update CMDB
        client.update_cmdb(
            ci_class='cmdb_ci_vm_instance',
            name=vm_name,
            attributes={'status': 'Retired'}
        )
    elif event_type == 'Microsoft.Compute.VirtualMachines.StatusChange':
        # Create incident if VM stopped unexpectedly
        if event.data['status'] == 'PowerState/stopped':
            client.create_incident(
                short_description=f'VM {vm_name} stopped unexpectedly',
                description=f'VM {vm_name} has stopped. Investigation required.',
                urgency='2',
                impact='2'
            )
```

## Error Handling

The client includes comprehensive error handling:

```python
from servicenow_client import ServiceNowClient, ServiceNowError

try:
    client = ServiceNowClient(instance='...', username='...', password='...')
    incident = client.create_incident(
        short_description='Test incident',
        description='Test description',
        urgency='2',
        impact='2'
    )
except ServiceNowError as e:
    print(f"ServiceNow API Error: {e}")
    print(f"Status Code: {e.status_code}")
    print(f"Response: {e.response}")
except Exception as e:
    print(f"Unexpected error: {e}")
```

## Troubleshooting

### Common Issues

**Problem**: Authentication failures
```python
# Solution: Verify credentials
from servicenow_client import ServiceNowClient
client = ServiceNowClient(instance='...', username='...', password='...')
print(client.test_connection())  # Should return True
```

**Problem**: SSL certificate errors
```python
# Solution: Disable SSL verification (not recommended for production)
client = ServiceNowClient(
    instance='...',
    username='...',
    password='...',
    verify_ssl=False
)
```

**Problem**: Rate limiting
```python
# Solution: Implement retry with exponential backoff
import time
from servicenow_client import ServiceNowClient, ServiceNowError

def create_incident_with_retry(client, max_retries=3, **kwargs):
    for attempt in range(max_retries):
        try:
            return client.create_incident(**kwargs)
        except ServiceNowError as e:
            if e.status_code == 429:  # Rate limit
                wait_time = 2 ** attempt
                print(f"Rate limited. Waiting {wait_time}s...")
                time.sleep(wait_time)
            else:
                raise
    raise Exception("Max retries exceeded")
```

## Testing

Test ServiceNow integration:

```bash
# Test connection
python -c "from servicenow_client import ServiceNowClient; \
  client = ServiceNowClient(instance='your-instance.service-now.com', username='user', password='pass'); \
  print('Connected!' if client.test_connection() else 'Connection failed')"

# Create test incident
python deploy/scripts/utilities/servicenow/servicenow_client.py \
  --action create_incident \
  --short-description "Test incident - DELETE ME" \
  --description "Testing ServiceNow integration" \
  --urgency 3 \
  --impact 3
```

## Logs

- **Client Logs**: Enable debug logging with `client.set_log_level('DEBUG')`
- **API Logs**: Check ServiceNow instance logs in System Logs > REST
- **Azure Integration Logs**: Check Azure Function/Logic App logs

## Related Documentation

- [ServiceNow REST API Documentation](https://developer.servicenow.com/dev.do#!/reference/api/latest/rest)
- [CMDB Integration Guide](../../../../../../docs/servicenow/cmdb-integration.md)
- [Change Management Workflow](../../../../../../docs/servicenow/change-management.md)
- [Incident Management](../../../../../../docs/servicenow/incident-management.md)
