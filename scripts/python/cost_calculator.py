#!/usr/bin/env python3
"""
Azure Cost Calculator for VM Provisioning
Estimates monthly costs for Azure VMs and associated resources
"""

import json
import logging
from typing import Dict, List, Optional
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class CostCalculator:
    """Azure VM cost estimation"""
    
    # Pricing data (West Europe, USD per hour)
    # NOTE: In production, use Azure Retail Prices API
    VM_PRICING = {
        # B-series (Burstable)
        'Standard_B2s': 0.0416,
        'Standard_B2ms': 0.0832,
        'Standard_B4ms': 0.1664,
        
        # D-series v3 (General Purpose)
        'Standard_D2s_v3': 0.113,
        'Standard_D4s_v3': 0.226,
        'Standard_D8s_v3': 0.452,
        'Standard_D16s_v3': 0.904,
        'Standard_D32s_v3': 1.808,
        
        # E-series v3 (Memory Optimized)
        'Standard_E2s_v3': 0.128,
        'Standard_E4s_v3': 0.256,
        'Standard_E8s_v3': 0.512,
        'Standard_E16s_v3': 1.024,
        'Standard_E32s_v3': 2.048,
        
        # F-series v2 (Compute Optimized)
        'Standard_F2s_v2': 0.099,
        'Standard_F4s_v2': 0.198,
        'Standard_F8s_v2': 0.396,
        'Standard_F16s_v2': 0.792,
    }
    
    # Storage pricing (per GB per month)
    STORAGE_PRICING = {
        'Standard_LRS': 0.05,
        'StandardSSD_LRS': 0.10,
        'Premium_LRS': 0.15,
        'PremiumV2_LRS': 0.20,
        'UltraSSD_LRS': 0.25,
    }
    
    # Backup pricing (per GB per month)
    BACKUP_PRICING = {
        'protected_instance': 10.00,  # Per protected instance
        'storage_per_gb': 0.10,       # Per GB backup storage
    }
    
    # Network pricing
    NETWORK_PRICING = {
        'public_ip': 3.65,            # Per month (basic)
        'load_balancer_rule': 0.025,  # Per hour
        'outbound_data_gb': 0.087,    # Per GB (first 5GB free)
    }
    
    def __init__(self):
        """Initialize cost calculator"""
        logger.info("Initialized cost calculator")
    
    def calculate_vm_cost(
        self,
        vm_size: str,
        hours_per_month: int = 730
    ) -> Dict:
        """
        Calculate VM compute cost
        
        Args:
            vm_size: VM size
            hours_per_month: Hours per month (default: 730)
            
        Returns:
            VM cost breakdown
        """
        hourly_rate = self.VM_PRICING.get(vm_size, 0.10)  # Default to $0.10/hr
        monthly_cost = hourly_rate * hours_per_month
        
        return {
            'vm_size': vm_size,
            'hourly_rate': hourly_rate,
            'hours_per_month': hours_per_month,
            'monthly_cost': monthly_cost
        }
    
    def calculate_storage_cost(
        self,
        disk_size_gb: int,
        storage_type: str = 'Premium_LRS'
    ) -> Dict:
        """
        Calculate storage cost
        
        Args:
            disk_size_gb: Disk size in GB
            storage_type: Storage type
            
        Returns:
            Storage cost breakdown
        """
        price_per_gb = self.STORAGE_PRICING.get(storage_type, 0.15)
        monthly_cost = disk_size_gb * price_per_gb
        
        return {
            'disk_size_gb': disk_size_gb,
            'storage_type': storage_type,
            'price_per_gb': price_per_gb,
            'monthly_cost': monthly_cost
        }
    
    def calculate_backup_cost(
        self,
        protected_instances: int = 1,
        backup_storage_gb: int = 100
    ) -> Dict:
        """
        Calculate backup cost
        
        Args:
            protected_instances: Number of protected instances
            backup_storage_gb: Backup storage in GB
            
        Returns:
            Backup cost breakdown
        """
        instance_cost = protected_instances * self.BACKUP_PRICING['protected_instance']
        storage_cost = backup_storage_gb * self.BACKUP_PRICING['storage_per_gb']
        total_cost = instance_cost + storage_cost
        
        return {
            'protected_instances': protected_instances,
            'backup_storage_gb': backup_storage_gb,
            'instance_cost': instance_cost,
            'storage_cost': storage_cost,
            'monthly_cost': total_cost
        }
    
    def calculate_network_cost(
        self,
        public_ips: int = 1,
        outbound_data_gb: int = 100
    ) -> Dict:
        """
        Calculate network cost
        
        Args:
            public_ips: Number of public IPs
            outbound_data_gb: Outbound data transfer in GB
            
        Returns:
            Network cost breakdown
        """
        ip_cost = public_ips * self.NETWORK_PRICING['public_ip']
        
        # First 5GB free
        billable_data = max(0, outbound_data_gb - 5)
        data_cost = billable_data * self.NETWORK_PRICING['outbound_data_gb']
        
        total_cost = ip_cost + data_cost
        
        return {
            'public_ips': public_ips,
            'outbound_data_gb': outbound_data_gb,
            'ip_cost': ip_cost,
            'data_transfer_cost': data_cost,
            'monthly_cost': total_cost
        }
    
    def calculate_total_cost(
        self,
        vm_size: str,
        os_disk_size_gb: int = 128,
        data_disk_size_gb: int = 0,
        storage_type: str = 'Premium_LRS',
        enable_backup: bool = True,
        public_ip: bool = True,
        outbound_data_gb: int = 100,
        hours_per_month: int = 730
    ) -> Dict:
        """
        Calculate total VM cost including all components
        
        Args:
            vm_size: VM size
            os_disk_size_gb: OS disk size
            data_disk_size_gb: Data disk size
            storage_type: Storage type
            enable_backup: Enable Azure Backup
            public_ip: Include public IP
            outbound_data_gb: Outbound data transfer
            hours_per_month: Hours per month
            
        Returns:
            Complete cost breakdown
        """
        logger.info(f"Calculating total cost for {vm_size}")
        
        # VM compute cost
        vm_cost = self.calculate_vm_cost(vm_size, hours_per_month)
        
        # Storage cost
        os_disk_cost = self.calculate_storage_cost(os_disk_size_gb, storage_type)
        
        data_disk_cost = {'monthly_cost': 0}
        if data_disk_size_gb > 0:
            data_disk_cost = self.calculate_storage_cost(data_disk_size_gb, storage_type)
        
        # Backup cost
        backup_cost = {'monthly_cost': 0}
        if enable_backup:
            total_storage = os_disk_size_gb + data_disk_size_gb
            backup_cost = self.calculate_backup_cost(1, total_storage)
        
        # Network cost
        network_cost = self.calculate_network_cost(
            public_ips=1 if public_ip else 0,
            outbound_data_gb=outbound_data_gb
        )
        
        # Calculate total
        total_monthly_cost = (
            vm_cost['monthly_cost'] +
            os_disk_cost['monthly_cost'] +
            data_disk_cost['monthly_cost'] +
            backup_cost['monthly_cost'] +
            network_cost['monthly_cost']
        )
        
        annual_cost = total_monthly_cost * 12
        
        # Build breakdown
        breakdown = {
            'timestamp': datetime.utcnow().isoformat() + 'Z',
            'vm_size': vm_size,
            'configuration': {
                'os_disk_gb': os_disk_size_gb,
                'data_disk_gb': data_disk_size_gb,
                'storage_type': storage_type,
                'backup_enabled': enable_backup,
                'public_ip': public_ip,
                'hours_per_month': hours_per_month
            },
            'cost_breakdown': {
                'compute': vm_cost['monthly_cost'],
                'os_disk': os_disk_cost['monthly_cost'],
                'data_disk': data_disk_cost['monthly_cost'],
                'backup': backup_cost['monthly_cost'],
                'network': network_cost['monthly_cost']
            },
            'total_monthly_cost': round(total_monthly_cost, 2),
            'total_annual_cost': round(annual_cost, 2),
            'currency': 'USD',
            'region': 'West Europe'
        }
        
        logger.info(f"Total monthly cost: ${total_monthly_cost:.2f}")
        
        return breakdown
    
    def compare_vm_sizes(
        self,
        vm_sizes: List[str],
        **config
    ) -> List[Dict]:
        """
        Compare costs for multiple VM sizes
        
        Args:
            vm_sizes: List of VM sizes to compare
            **config: Configuration parameters
            
        Returns:
            List of cost breakdowns sorted by cost
        """
        comparisons = []
        
        for vm_size in vm_sizes:
            cost = self.calculate_total_cost(vm_size, **config)
            comparisons.append(cost)
        
        # Sort by cost
        comparisons.sort(key=lambda x: x['total_monthly_cost'])
        
        return comparisons
    
    def export_cost_report(
        self,
        cost_data: Dict,
        output_file: str
    ):
        """
        Export cost report to JSON file
        
        Args:
            cost_data: Cost calculation data
            output_file: Output file path
        """
        with open(output_file, 'w') as f:
            json.dump(cost_data, f, indent=2)
        
        logger.info(f"Cost report exported to: {output_file}")


def main():
    """CLI interface"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Azure VM Cost Calculator')
    parser.add_argument('--vm-size', required=True, help='VM size')
    parser.add_argument('--os-disk', type=int, default=128, help='OS disk size (GB)')
    parser.add_argument('--data-disk', type=int, default=0, help='Data disk size (GB)')
    parser.add_argument('--storage-type', default='Premium_LRS', help='Storage type')
    parser.add_argument('--backup', action='store_true', help='Enable backup')
    parser.add_argument('--public-ip', action='store_true', help='Include public IP')
    parser.add_argument('--hours', type=int, default=730, help='Hours per month')
    parser.add_argument('--output', help='Output file path')
    
    args = parser.parse_args()
    
    calculator = CostCalculator()
    
    cost_data = calculator.calculate_total_cost(
        vm_size=args.vm_size,
        os_disk_size_gb=args.os_disk,
        data_disk_size_gb=args.data_disk,
        storage_type=args.storage_type,
        enable_backup=args.backup,
        public_ip=args.public_ip,
        hours_per_month=args.hours
    )
    
    # Print summary
    print("\n" + "="*80)
    print("AZURE VM COST ESTIMATE")
    print("="*80)
    print(f"\nVM Size: {cost_data['vm_size']}")
    print(f"Region: {cost_data['region']}")
    
    print("\nConfiguration:")
    for key, value in cost_data['configuration'].items():
        print(f"  {key}: {value}")
    
    print("\nCost Breakdown (Monthly):")
    for component, cost in cost_data['cost_breakdown'].items():
        print(f"  {component.replace('_', ' ').title()}: ${cost:.2f}")
    
    print(f"\n{'='*80}")
    print(f"Total Monthly Cost: ${cost_data['total_monthly_cost']:.2f}")
    print(f"Total Annual Cost: ${cost_data['total_annual_cost']:.2f}")
    print(f"{'='*80}\n")
    
    # Export if requested
    if args.output:
        calculator.export_cost_report(cost_data, args.output)
    
    return cost_data


if __name__ == '__main__':
    main()
