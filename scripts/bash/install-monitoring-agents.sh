#!/bin/bash
#
# Install Azure monitoring and management agents on Linux VMs
# Supports RHEL, Ubuntu, and other major distributions
#
# Author: Cloud Infrastructure Team
# Date: 2025-10-07

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

log_info "Starting Your Organization agent installation for Linux VM..."

# Detect Linux distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
    log_info "Detected OS: $OS $VER"
else
    log_error "Cannot detect Linux distribution"
    exit 1
fi

# Parse command line arguments
WORKSPACE_ID=""
WORKSPACE_KEY=""
INSTALL_DEFENDER=false
INSTALL_BACKUP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --workspace-id)
            WORKSPACE_ID="$2"
            shift 2
            ;;
        --workspace-key)
            WORKSPACE_KEY="$2"
            shift 2
            ;;
        --install-defender)
            INSTALL_DEFENDER=true
            shift
            ;;
        --install-backup)
            INSTALL_BACKUP=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# ============================================================================
# INSTALL AZURE MONITOR AGENT (AMA)
# ============================================================================

install_azure_monitor_agent() {
    log_info "Installing Azure Monitor Agent..."
    
    case $OS in
        ubuntu|debian)
            # Download and install
            wget https://aka.ms/dependencyagentlinux -O InstallDependencyAgent-Linux64.bin
            sh InstallDependencyAgent-Linux64.bin -s
            
            # Install AMA
            wget https://aka.ms/amalinux -O AzureMonitorAgent.deb
            dpkg -i AzureMonitorAgent.deb
            ;;
            
        rhel|centos|fedora)
            # Download and install
            wget https://aka.ms/dependencyagentlinux -O InstallDependencyAgent-Linux64.bin
            sh InstallDependencyAgent-Linux64.bin -s
            
            # Install AMA
            wget https://aka.ms/amalinux -O AzureMonitorAgent.rpm
            rpm -ivh AzureMonitorAgent.rpm
            ;;
            
        *)
            log_warn "Unsupported distribution for Azure Monitor Agent: $OS"
            return 1
            ;;
    esac
    
    # Configure workspace connection if provided
    if [ -n "$WORKSPACE_ID" ] && [ -n "$WORKSPACE_KEY" ]; then
        log_info "Configuring Log Analytics workspace..."
        
        # Create configuration file
        cat > /etc/opt/microsoft/azuremonitoragent/config.json <<EOF
{
    "workspaceId": "$WORKSPACE_ID",
    "workspaceKey": "$WORKSPACE_KEY"
}
EOF
        
        # Restart agent
        systemctl restart azuremonitoragent
    fi
    
    log_info "Azure Monitor Agent installed successfully"
}

# ============================================================================
# INSTALL DEPENDENCY AGENT
# ============================================================================

install_dependency_agent() {
    log_info "Installing Dependency Agent for VM Insights..."
    
    # Check if already installed
    if systemctl is-active --quiet microsoft-dependency-agent; then
        log_warn "Dependency Agent already installed"
        return 0
    fi
    
    # Download and install
    wget --content-disposition https://aka.ms/dependencyagentlinux -O InstallDependencyAgent-Linux64.bin
    chmod +x InstallDependencyAgent-Linux64.bin
    ./InstallDependencyAgent-Linux64.bin -s
    
    # Verify installation
    if systemctl is-active --quiet microsoft-dependency-agent; then
        log_info "Dependency Agent installed successfully"
    else
        log_error "Dependency Agent installation failed"
        return 1
    fi
}

# ============================================================================
# INSTALL MICROSOFT DEFENDER FOR ENDPOINT
# ============================================================================

install_defender() {
    if [ "$INSTALL_DEFENDER" = false ]; then
        return 0
    fi
    
    log_info "Installing Microsoft Defender for Endpoint..."
    
    case $OS in
        ubuntu|debian)
            # Add Microsoft repository
            curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
            
            if [ "$OS" = "ubuntu" ]; then
                echo "deb [arch=amd64] https://packages.microsoft.com/ubuntu/$VER/prod $DISTRIB_CODENAME main" > /etc/apt/sources.list.d/microsoft-prod.list
            fi
            
            apt-get update
            apt-get install -y mdatp
            ;;
            
        rhel|centos)
            # Add Microsoft repository
            yum-config-manager --add-repo=https://packages.microsoft.com/config/rhel/$VER/prod.repo
            yum install -y mdatp
            ;;
            
        *)
            log_warn "Unsupported distribution for Defender: $OS"
            return 1
            ;;
    esac
    
    log_info "Microsoft Defender for Endpoint installed successfully"
}

# ============================================================================
# CONFIGURE SYSLOG FOR AZURE MONITOR
# ============================================================================

configure_syslog() {
    log_info "Configuring syslog for Azure Monitor..."
    
    # Ensure rsyslog is installed
    case $OS in
        ubuntu|debian)
            apt-get install -y rsyslog
            ;;
        rhel|centos|fedora)
            yum install -y rsyslog
            ;;
    esac
    
    # Configure rsyslog to forward to Azure Monitor
    cat > /etc/rsyslog.d/95-omsagent.conf <<EOF
# Azure Monitor configuration
*.info;mail.none;authpriv.none;cron.none @127.0.0.1:25224
EOF
    
    # Restart rsyslog
    systemctl restart rsyslog
    
    log_info "Syslog configured successfully"
}

# ============================================================================
# INSTALL CUSTOM MONITORING SCRIPTS
# ============================================================================

install_monitoring_scripts() {
    log_info "Installing custom monitoring scripts..."
    
    # Create monitoring directory
    mkdir -p /opt/Your Organization/monitoring
    
    # Create disk monitoring script
    cat > /opt/Your Organization/monitoring/check_disk.sh <<'EOF'
#!/bin/bash
# Check disk usage and alert if > 80%

THRESHOLD=80

df -H | grep -vE '^Filesystem|tmpfs|cdrom' | awk '{ print $5 " " $1 }' | while read output;
do
    usage=$(echo $output | awk '{ print $1}' | cut -d'%' -f1)
    partition=$(echo $output | awk '{ print $2 }')
    
    if [ $usage -ge $THRESHOLD ]; then
        echo "WARNING: Partition $partition is ${usage}% full"
        logger -t disk_monitor "WARNING: Partition $partition is ${usage}% full"
    fi
done
EOF
    
    chmod +x /opt/Your Organization/monitoring/check_disk.sh
    
    # Add to crontab (run every hour)
    (crontab -l 2>/dev/null; echo "0 * * * * /opt/Your Organization/monitoring/check_disk.sh") | crontab -
    
    log_info "Monitoring scripts installed successfully"
}

# ============================================================================
# VERIFY INSTALLATIONS
# ============================================================================

verify_installations() {
    log_info "Verifying agent installations..."
    
    local all_ok=true
    
    # Check Azure Monitor Agent
    if systemctl is-active --quiet azuremonitoragent; then
        log_info "✓ Azure Monitor Agent: Running"
    else
        log_warn "✗ Azure Monitor Agent: Not running"
        all_ok=false
    fi
    
    # Check Dependency Agent
    if systemctl is-active --quiet microsoft-dependency-agent; then
        log_info "✓ Dependency Agent: Running"
    else
        log_warn "✗ Dependency Agent: Not running"
        all_ok=false
    fi
    
    # Check Defender (if installed)
    if [ "$INSTALL_DEFENDER" = true ]; then
        if systemctl is-active --quiet mdatp; then
            log_info "✓ Microsoft Defender: Running"
        else
            log_warn "✗ Microsoft Defender: Not running"
            all_ok=false
        fi
    fi
    
    # Check rsyslog
    if systemctl is-active --quiet rsyslog; then
        log_info "✓ Rsyslog: Running"
    else
        log_warn "✗ Rsyslog: Not running"
        all_ok=false
    fi
    
    if [ "$all_ok" = true ]; then
        log_info "All agents installed and running successfully"
        return 0
    else
        log_warn "Some agents failed to install or start"
        return 1
    fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log_info "Starting agent installation process..."
    
    # Update package manager
    case $OS in
        ubuntu|debian)
            apt-get update
            ;;
        rhel|centos|fedora)
            yum update -y
            ;;
    esac
    
    # Install agents
    install_azure_monitor_agent || log_warn "Azure Monitor Agent installation failed"
    install_dependency_agent || log_warn "Dependency Agent installation failed"
    install_defender || log_warn "Defender installation failed"
    configure_syslog || log_warn "Syslog configuration failed"
    install_monitoring_scripts || log_warn "Monitoring scripts installation failed"
    
    # Verify installations
    verify_installations
    
    log_info "Agent installation completed"
    log_info "Please verify agent status in Azure Portal"
}

# Run main function
main

exit 0
