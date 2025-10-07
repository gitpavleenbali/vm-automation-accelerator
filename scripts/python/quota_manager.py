#!/usr/bin/env python3
"""
Azure Quota Manager for VM Automation Accelerator
Checks and manages Azure resource quotas
"""

import os
import sys
import json
import logging
from typing import Dict, List, Optional
from datetime import datetime
from azure.identity import DefaultAzureCredential
from azure.mgmt.compute import ComputeManagementClient
from azure.mgmt.network import NetworkManagementClient
from azure.mgmt.resource import SubscriptionClient

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class QuotaManager:
    """Azure quota management and validation"""
    
    # VM family mapping
    VM_FAMILY_MAP = {
        'Standard_B': 'standardBSFamily',
        'Standard_D2': 'standardDSv3Family',
        'Standard_D4': 'standardDSv3Family',
        'Standard_D8': 'standardDSv3Family',
        'Standard_D16': 'standardDSv3Family',
        'Standard_E2': 'standardESv3Family',
        'Standard_E4': 'standardESv3Family',
        'Standard_E8': 'standardESv3Family',
        'Standard_E16': 'standardESv3Family',
        'Standard_F2': 'standardFSv2Family',
        'Standard_F4': 'standardFSv2Family',
        'Standard_F8': 'standardFSv2Family',
    }
    
    def __init__(self, subscription_id: str):
        """
        Initialize quota manager
        
        Args:
            subscription_id: Azure subscription ID
        """
        self.subscription_id = subscription_id
        self.credential = DefaultAzureCredential()
        self.compute_client = ComputeManagementClient(self.credential, subscription_id)
        self.network_client = NetworkManagementClient(self.credential, subscription_id)
        
        logger.info(f"Initialized quota manager for subscription: {subscription_id}")
    
    def get_vm_family(self, vm_size: str) -> str:
        """
        Get VM family from VM size
        
        Args:
            vm_size: VM size (e.g., Standard_D4s_v3)
            
        Returns:
            VM family name
        """
        for prefix, family in self.VM_FAMILY_MAP.items():
            if vm_size.startswith(prefix):
                return family
        
        # Default to DSv3 family
        return 'standardDSv3Family'
    
    def get_vm_size_details(self, location: str, vm_size: str) -> Optional[Dict]:
        """
        Get VM size details
        
        Args:
            location: Azure region
            vm_size: VM size
            
        Returns:
            VM size details dictionary
        """
        try:
            vm_sizes = self.compute_client.virtual_machine_sizes.list(location)
            
            for size in vm_sizes:
                if size.name == vm_size:
                    return {
                        'name': size.name,
                        'cores': size.number_of_cores,
                        'memory_mb': size.memory_in_mb,
                        'max_data_disks': size.max_data_disk_count,
                        'os_disk_size_mb': size.os_disk_size_in_mb,
                        'resource_disk_size_mb': size.resource_disk_size_in_mb
                    }
            
            return None
            
        except Exception as e:
            logger.error(f"Failed to get VM size details: {e}")
            return None
    
    def check_compute_quota(
        self,
        location: str,
        vm_size: str,
        quantity: int = 1
    ) -> Dict:
        """
        Check compute quota availability
        
        Args:
            location: Azure region
            vm_size: VM size
            quantity: Number of VMs
            
        Returns:
            Quota check results
        """
        logger.info(f"Checking quota for {quantity} x {vm_size} in {location}")
        
        # Get VM size details
        vm_details = self.get_vm_size_details(location, vm_size)
        if not vm_details:
            return {
                'success': False,
                'error': f'VM size {vm_size} not found in {location}'
            }
        
        cores_required = vm_details['cores'] * quantity
        memory_required = vm_details['memory_mb'] * quantity
        
        logger.info(f"Cores required: {cores_required}")
        logger.info(f"Memory required: {memory_required} MB")
        
        # Get usage and quotas
        try:
            usages = self.compute_client.usage.list(location)
            
            quota_results = {
                'vm_size': vm_size,
                'location': location,
                'quantity': quantity,
                'cores_required': cores_required,
                'memory_required_mb': memory_required,
                'quotas': {},
                'sufficient': True
            }
            
            for usage in usages:
                quota_name = usage.name.value
                current = usage.current_value
                limit = usage.limit
                available = limit - current
                
                # Check total cores
                if quota_name == 'cores':
                    quota_results['quotas']['total_cores'] = {
                        'name': 'Total Regional vCPUs',
                        'current': current,
                        'limit': limit,
                        'available': available,
                        'required': cores_required,
                        'sufficient': available >= cores_required
                    }
                    
                    if available < cores_required:
                        quota_results['sufficient'] = False
                        logger.warning(f"Insufficient total cores: {available} < {cores_required}")
                
                # Check VM family
                vm_family = self.get_vm_family(vm_size)
                if quota_name == vm_family:
                    quota_results['quotas']['family_cores'] = {
                        'name': f'VM Family ({vm_family})',
                        'current': current,
                        'limit': limit,
                        'available': available,
                        'required': cores_required,
                        'sufficient': available >= cores_required
                    }
                    
                    if available < cores_required:
                        quota_results['sufficient'] = False
                        logger.warning(f"Insufficient family cores: {available} < {cores_required}")
            
            quota_results['success'] = True
            return quota_results
            
        except Exception as e:
            logger.error(f"Failed to check quota: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def check_network_quota(self, location: str, quantity: int = 1) -> Dict:
        """
        Check network quota availability
        
        Args:
            location: Azure region
            quantity: Number of resources
            
        Returns:
            Network quota results
        """
        try:
            # Get network usage
            usages = self.network_client.usages.list(location)
            
            network_quotas = {}
            
            for usage in usages:
                if usage.name and usage.name.value:
                    quota_name = usage.name.value
                    current = usage.current_value
                    limit = usage.limit
                    available = limit - current
                    
                    network_quotas[quota_name] = {
                        'current': current,
                        'limit': limit,
                        'available': available,
                        'sufficient': available >= quantity
                    }
            
            return {
                'success': True,
                'quotas': network_quotas
            }
            
        except Exception as e:
            logger.error(f"Failed to check network quota: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def generate_quota_report(
        self,
        location: str,
        vm_size: str,
        quantity: int = 1,
        output_file: Optional[str] = None
    ) -> Dict:
        """
        Generate comprehensive quota report
        
        Args:
            location: Azure region
            vm_size: VM size
            quantity: Number of VMs
            output_file: Optional output file path
            
        Returns:
            Complete quota report
        """
        logger.info("Generating quota report...")
        
        # Check compute quota
        compute_quota = self.check_compute_quota(location, vm_size, quantity)
        
        # Check network quota
        network_quota = self.check_network_quota(location, quantity)
        
        # Build report
        report = {
            'subscription_id': self.subscription_id,
            'location': location,
            'vm_size': vm_size,
            'quantity': quantity,
            'timestamp': datetime.utcnow().isoformat() + 'Z',
            'compute': compute_quota,
            'network': network_quota,
            'overall_sufficient': compute_quota.get('sufficient', False)
        }
        
        # Save to file if specified
        if output_file:
            with open(output_file, 'w') as f:
                json.dump(report, f, indent=2)
            logger.info(f"Quota report saved to: {output_file}")
        
        return report
    
    def request_quota_increase(
        self,
        location: str,
        quota_name: str,
        requested_limit: int,
        justification: str
    ) -> Dict:
        """
        Request quota increase (placeholder for support ticket creation)
        
        Args:
            location: Azure region
            quota_name: Quota to increase
            requested_limit: Requested new limit
            justification: Business justification
            
        Returns:
            Request status
        """
        logger.info(f"Quota increase request: {quota_name} to {requested_limit} in {location}")
        
        # In production, this would create an Azure support ticket
        # For now, just return a placeholder response
        
        return {
            'status': 'pending',
            'message': 'Quota increase request would be submitted to Azure Support',
            'details': {
                'location': location,
                'quota_name': quota_name,
                'requested_limit': requested_limit,
                'justification': justification
            }
        }


def main():
    """CLI interface"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Azure Quota Manager')
    parser.add_argument('--subscription-id', required=True, help='Azure subscription ID')
    parser.add_argument('--location', required=True, help='Azure region')
    parser.add_argument('--vm-size', required=True, help='VM size')
    parser.add_argument('--quantity', type=int, default=1, help='Number of VMs')
    parser.add_argument('--output', help='Output file path')
    
    args = parser.parse_args()
    
    try:
        manager = QuotaManager(args.subscription_id)
        report = manager.generate_quota_report(
            location=args.location,
            vm_size=args.vm_size,
            quantity=args.quantity,
            output_file=args.output
        )
        
        # Print summary
        print("\n" + "="*80)
        print("QUOTA CHECK SUMMARY")
        print("="*80)
        
        if report['compute'].get('success'):
            print(f"\nVM Size: {report['vm_size']}")
            print(f"Location: {report['location']}")
            print(f"Quantity: {report['quantity']}")
            print(f"Cores Required: {report['compute']['cores_required']}")
            
            print("\nQuota Status:")
            for quota_type, quota_data in report['compute'].get('quotas', {}).items():
                status = "✓" if quota_data['sufficient'] else "✗"
                print(f"  {status} {quota_data['name']}")
                print(f"     Current: {quota_data['current']}, Limit: {quota_data['limit']}, Available: {quota_data['available']}")
            
            if report['overall_sufficient']:
                print("\n✓ QUOTA CHECK PASSED")
                exit_code = 0
            else:
                print("\n✗ QUOTA CHECK FAILED - Insufficient quota")
                print("Request quota increase through Azure Portal")
                exit_code = 1
        else:
            print(f"\n✗ ERROR: {report['compute'].get('error')}")
            exit_code = 1
        
        print("="*80 + "\n")
        
        sys.exit(exit_code)
        
    except Exception as e:
        logger.error(f"Failed to check quota: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
