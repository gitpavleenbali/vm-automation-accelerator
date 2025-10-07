#!/usr/bin/env python3
"""
ServiceNow REST API Client for VM Automation Accelerator
Provides functions to create, update, and query ServiceNow records
"""

import os
import json
import logging
from typing import Dict, List, Optional, Any
from datetime import datetime
import requests
from requests.auth import HTTPBasicAuth

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class ServiceNowClient:
    """ServiceNow REST API client for VM automation workflows"""
    
    def __init__(
        self,
        instance_url: str = None,
        username: str = None,
        password: str = None,
        api_version: str = "v1"
    ):
        """
        Initialize ServiceNow client
        
        Args:
            instance_url: ServiceNow instance URL (e.g., https://Your Organization.service-now.com)
            username: ServiceNow username
            password: ServiceNow password
            api_version: API version (default: v1)
        """
        self.instance_url = instance_url or os.getenv('SERVICENOW_INSTANCE_URL')
        self.username = username or os.getenv('SERVICENOW_USERNAME')
        self.password = password or os.getenv('SERVICENOW_PASSWORD')
        self.api_version = api_version
        
        if not all([self.instance_url, self.username, self.password]):
            raise ValueError(
                "ServiceNow credentials not provided. Set environment variables: "
                "SERVICENOW_INSTANCE_URL, SERVICENOW_USERNAME, SERVICENOW_PASSWORD"
            )
        
        self.base_url = f"{self.instance_url}/api/now/{api_version}"
        self.auth = HTTPBasicAuth(self.username, self.password)
        self.headers = {
            "Content-Type": "application/json",
            "Accept": "application/json"
        }
    
    def _make_request(
        self,
        method: str,
        endpoint: str,
        data: Optional[Dict] = None,
        params: Optional[Dict] = None
    ) -> Dict:
        """
        Make HTTP request to ServiceNow API
        
        Args:
            method: HTTP method (GET, POST, PUT, PATCH)
            endpoint: API endpoint
            data: Request body data
            params: Query parameters
            
        Returns:
            API response as dictionary
        """
        url = f"{self.base_url}/{endpoint}"
        
        try:
            response = requests.request(
                method=method,
                url=url,
                auth=self.auth,
                headers=self.headers,
                json=data,
                params=params,
                timeout=30
            )
            response.raise_for_status()
            return response.json()
            
        except requests.exceptions.HTTPError as e:
            logger.error(f"HTTP error: {e}")
            logger.error(f"Response: {e.response.text}")
            raise
        except requests.exceptions.RequestException as e:
            logger.error(f"Request error: {e}")
            raise
    
    # =========================================================================
    # REQUEST ITEM METHODS
    # =========================================================================
    
    def get_request_item(self, sys_id: str) -> Dict:
        """
        Get request item by sys_id
        
        Args:
            sys_id: ServiceNow sys_id
            
        Returns:
            Request item record
        """
        logger.info(f"Getting request item: {sys_id}")
        response = self._make_request("GET", f"table/sc_req_item/{sys_id}")
        return response.get('result', {})
    
    def update_request_item(
        self,
        sys_id: str,
        state: Optional[str] = None,
        work_notes: Optional[str] = None,
        additional_fields: Optional[Dict] = None
    ) -> Dict:
        """
        Update request item
        
        Args:
            sys_id: ServiceNow sys_id
            state: New state (e.g., '2' for In Progress, '3' for Closed Complete)
            work_notes: Work notes to add
            additional_fields: Additional fields to update
            
        Returns:
            Updated request item record
        """
        logger.info(f"Updating request item: {sys_id}")
        
        data = {}
        if state:
            data['state'] = state
        if work_notes:
            data['work_notes'] = work_notes
        if additional_fields:
            data.update(additional_fields)
        
        response = self._make_request("PATCH", f"table/sc_req_item/{sys_id}", data=data)
        return response.get('result', {})
    
    def get_request_item_by_number(self, number: str) -> Dict:
        """
        Get request item by number (e.g., RITM0010001)
        
        Args:
            number: Request item number
            
        Returns:
            Request item record
        """
        logger.info(f"Getting request item by number: {number}")
        params = {'sysparm_query': f'number={number}', 'sysparm_limit': 1}
        response = self._make_request("GET", "table/sc_req_item", params=params)
        results = response.get('result', [])
        return results[0] if results else {}
    
    # =========================================================================
    # CHANGE REQUEST METHODS
    # =========================================================================
    
    def create_change_request(
        self,
        short_description: str,
        description: str,
        type: str = "normal",
        risk: str = "moderate",
        impact: str = "3",
        priority: str = "3",
        assignment_group: str = "cloud_infrastructure_team",
        **kwargs
    ) -> Dict:
        """
        Create change request
        
        Args:
            short_description: Brief description
            description: Detailed description
            type: Change type (standard, normal, emergency)
            risk: Risk level (low, moderate, high)
            impact: Impact (1=High, 2=Medium, 3=Low)
            priority: Priority (1=Critical, 2=High, 3=Moderate, 4=Low)
            assignment_group: Assignment group
            **kwargs: Additional fields
            
        Returns:
            Created change request record
        """
        logger.info(f"Creating change request: {short_description}")
        
        data = {
            'short_description': short_description,
            'description': description,
            'type': type,
            'risk': risk,
            'impact': impact,
            'priority': priority,
            'assignment_group': assignment_group,
            **kwargs
        }
        
        response = self._make_request("POST", "table/change_request", data=data)
        return response.get('result', {})
    
    def update_change_request(
        self,
        sys_id: str,
        state: Optional[str] = None,
        work_notes: Optional[str] = None,
        **kwargs
    ) -> Dict:
        """
        Update change request
        
        Args:
            sys_id: ServiceNow sys_id
            state: New state
            work_notes: Work notes
            **kwargs: Additional fields
            
        Returns:
            Updated change request record
        """
        logger.info(f"Updating change request: {sys_id}")
        
        data = {}
        if state:
            data['state'] = state
        if work_notes:
            data['work_notes'] = work_notes
        data.update(kwargs)
        
        response = self._make_request("PATCH", f"table/change_request/{sys_id}", data=data)
        return response.get('result', {})
    
    # =========================================================================
    # INCIDENT METHODS
    # =========================================================================
    
    def create_incident(
        self,
        short_description: str,
        description: str,
        urgency: str = "3",
        impact: str = "3",
        priority: str = "3",
        assignment_group: str = "cloud_infrastructure_team",
        **kwargs
    ) -> Dict:
        """
        Create incident
        
        Args:
            short_description: Brief description
            description: Detailed description
            urgency: Urgency (1=High, 2=Medium, 3=Low)
            impact: Impact (1=High, 2=Medium, 3=Low)
            priority: Priority (auto-calculated from urgency + impact)
            assignment_group: Assignment group
            **kwargs: Additional fields
            
        Returns:
            Created incident record
        """
        logger.info(f"Creating incident: {short_description}")
        
        data = {
            'short_description': short_description,
            'description': description,
            'urgency': urgency,
            'impact': impact,
            'priority': priority,
            'assignment_group': assignment_group,
            **kwargs
        }
        
        response = self._make_request("POST", "table/incident", data=data)
        return response.get('result', {})
    
    def update_incident(
        self,
        sys_id: str,
        state: Optional[str] = None,
        work_notes: Optional[str] = None,
        **kwargs
    ) -> Dict:
        """
        Update incident
        
        Args:
            sys_id: ServiceNow sys_id
            state: New state
            work_notes: Work notes
            **kwargs: Additional fields
            
        Returns:
            Updated incident record
        """
        logger.info(f"Updating incident: {sys_id}")
        
        data = {}
        if state:
            data['state'] = state
        if work_notes:
            data['work_notes'] = work_notes
        data.update(kwargs)
        
        response = self._make_request("PATCH", f"table/incident/{sys_id}", data=data)
        return response.get('result', {})
    
    # =========================================================================
    # CMDB METHODS
    # =========================================================================
    
    def create_vm_ci(
        self,
        name: str,
        vm_inst_id: str,
        environment: str,
        os: str,
        cpu_count: int,
        ram: int,
        disk_space: int,
        location: str,
        cost_center: str,
        owned_by: str,
        **kwargs
    ) -> Dict:
        """
        Create VM configuration item in CMDB
        
        Args:
            name: VM name
            vm_inst_id: Azure VM resource ID
            environment: Environment (dev, uat, prod)
            os: Operating system
            cpu_count: Number of vCPUs
            ram: RAM in MB
            disk_space: Disk space in GB
            location: Azure region
            cost_center: Cost center
            owned_by: Owner user sys_id
            **kwargs: Additional fields
            
        Returns:
            Created CI record
        """
        logger.info(f"Creating VM CI: {name}")
        
        data = {
            'name': name,
            'vm_inst_id': vm_inst_id,
            'vcenter_name': 'Azure',
            'environment': environment,
            'os': os,
            'cpu_count': cpu_count,
            'ram': ram,
            'disk_space': disk_space,
            'location': location,
            'cost_center': cost_center,
            'owned_by': owned_by,
            'managed_by': 'cloud_infrastructure_team',
            'operational_status': '1',  # Operational
            **kwargs
        }
        
        response = self._make_request("POST", "table/cmdb_ci_vm_instance", data=data)
        return response.get('result', {})
    
    def update_vm_ci(self, sys_id: str, **kwargs) -> Dict:
        """
        Update VM configuration item
        
        Args:
            sys_id: CI sys_id
            **kwargs: Fields to update
            
        Returns:
            Updated CI record
        """
        logger.info(f"Updating VM CI: {sys_id}")
        response = self._make_request("PATCH", f"table/cmdb_ci_vm_instance/{sys_id}", data=kwargs)
        return response.get('result', {})
    
    def get_vm_ci_by_name(self, name: str) -> Dict:
        """
        Get VM CI by name
        
        Args:
            name: VM name
            
        Returns:
            CI record
        """
        logger.info(f"Getting VM CI by name: {name}")
        params = {'sysparm_query': f'name={name}', 'sysparm_limit': 1}
        response = self._make_request("GET", "table/cmdb_ci_vm_instance", params=params)
        results = response.get('result', [])
        return results[0] if results else {}


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

def update_pipeline_status(
    ticket_number: str,
    pipeline_name: str,
    status: str,
    details: Optional[str] = None
) -> bool:
    """
    Update ServiceNow ticket with pipeline status
    
    Args:
        ticket_number: ServiceNow ticket number (RITM/CHG/INC)
        pipeline_name: Name of the pipeline
        status: Status (Started, In Progress, Completed, Failed)
        details: Additional details
        
    Returns:
        True if successful, False otherwise
    """
    try:
        client = ServiceNowClient()
        
        work_notes = f"Azure DevOps Pipeline: {pipeline_name}\nStatus: {status}"
        if details:
            work_notes += f"\n\nDetails:\n{details}"
        work_notes += f"\n\nTimestamp: {datetime.utcnow().isoformat()}Z"
        
        # Determine ticket type and get record
        if ticket_number.startswith('RITM'):
            record = client.get_request_item_by_number(ticket_number)
            if record:
                state = '2' if status in ['Started', 'In Progress'] else '3' if status == 'Completed' else None
                client.update_request_item(record['sys_id'], state=state, work_notes=work_notes)
        elif ticket_number.startswith('CHG'):
            # Handle change request
            params = {'sysparm_query': f'number={ticket_number}', 'sysparm_limit': 1}
            response = client._make_request("GET", "table/change_request", params=params)
            results = response.get('result', [])
            if results:
                client.update_change_request(results[0]['sys_id'], work_notes=work_notes)
        elif ticket_number.startswith('INC'):
            # Handle incident
            params = {'sysparm_query': f'number={ticket_number}', 'sysparm_limit': 1}
            response = client._make_request("GET", "table/incident", params=params)
            results = response.get('result', [])
            if results:
                client.update_incident(results[0]['sys_id'], work_notes=work_notes)
        
        logger.info(f"Updated ticket {ticket_number} with status: {status}")
        return True
        
    except Exception as e:
        logger.error(f"Failed to update ServiceNow ticket: {e}")
        return False


def main():
    """Example usage"""
    import argparse
    
    parser = argparse.ArgumentParser(description='ServiceNow API Client')
    parser.add_argument('--ticket', required=True, help='Ticket number')
    parser.add_argument('--status', required=True, help='Status')
    parser.add_argument('--pipeline', required=True, help='Pipeline name')
    parser.add_argument('--details', help='Additional details')
    
    args = parser.parse_args()
    
    success = update_pipeline_status(
        ticket_number=args.ticket,
        pipeline_name=args.pipeline,
        status=args.status,
        details=args.details
    )
    
    exit(0 if success else 1)


if __name__ == '__main__':
    main()
