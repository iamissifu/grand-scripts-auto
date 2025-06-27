#!/bin/bash

# Server Hardening Script for Ubuntu EC2
# This script implements security best practices for a production server

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root (use sudo)"
   exit 1
fi

print_status "Starting server hardening process..."

# Update system packages
print_status "Updating system packages..."
apt update && apt upgrade -y

# Install essential security packages
print_status "Installing security packages..."
apt install -y \
    fail2ban \
    ufw \
    unattended-upgrades \
    auditd \
    rkhunter \
    chkrootkit \
    apparmor \
    apparmor-utils \
    libpam-pwquality \
    logwatch \
    aide \
    clamav \
    clamav-daemon

# Configure automatic security updates
print_status "Configuring automatic security updates..."
cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

Unattended-Upgrade::Package-Blacklist {
};

Unattended-Upgrade::DevRelease "false";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOF

# Enable automatic security updates
echo 'APT::Periodic::Update-Package-Lists "1";' > /etc/apt/apt.conf.d/20auto-upgrades
echo 'APT::Periodic::Download-Upgradeable-Packages "1";' >> /etc/apt/apt.conf.d/20auto-upgrades
echo 'APT::Periodic::AutocleanInterval "7";' >> /etc/apt/apt.conf.d/20auto-upgrades
echo 'APT::Periodic::Unattended-Upgrade "1";' >> /etc/apt/apt.conf.d/20auto-upgrades

# Configure SSH hardening
print_status "Hardening SSH configuration..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

cat > /etc/ssh/sshd_config << 'EOF'
# SSH Server Configuration - Hardened
Port 22
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Authentication
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# Security
X11Forwarding no
AllowTcpForwarding no
GatewayPorts no
PermitTunnel no
MaxAuthTries 3
MaxSessions 2
ClientAliveInterval 300
ClientAliveCountMax 2
LoginGraceTime 60
Banner /etc/issue.net

# Logging
SyslogFacility AUTH
LogLevel INFO

# Allow specific users (modify as needed)
AllowUsers ubuntu

# Additional security
PermitUserEnvironment no
Compression delayed
TCPKeepAlive yes
EOF

# Create SSH banner
cat > /etc/issue.net << 'EOF'
***************************************************************************
                        NOTICE TO USERS

This computer system is the private property of its owner, whether
individual, corporate or government. It is for authorized use only.
Users (authorized or unauthorized) have no explicit or implicit
expectation of privacy.

By using this system, you consent to your keystrokes and data content
being monitored.

All activities are logged and monitored. Unauthorized access or use
may subject you to criminal and civil penalties.

If you are not an authorized user of this system, exit now.
***************************************************************************
EOF

# Configure fail2ban
print_status "Configuring fail2ban..."
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = auto
usedns = warn

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 3
bantime = 3600

[nginx-botsearch]
enabled = true
filter = nginx-botsearch
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 3
bantime = 3600
EOF

# Configure UFW firewall
print_status "Configuring UFW firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 22/tcp
ufw --force enable

# Configure password policy
print_status "Configuring password policy..."
cat > /etc/security/pwquality.conf << 'EOF'
minlen = 12
minclass = 3
maxrepeat = 2
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
gecoscheck = 1
EOF

# Configure login security
print_status "Configuring login security..."
cat > /etc/security/access.conf << 'EOF'
# Disable root login from console
-:root:ALL EXCEPT LOCAL
EOF

# Configure system limits
print_status "Configuring system limits..."
cat >> /etc/security/limits.conf << 'EOF'
# Security limits
* soft core 0
* hard core 0
* soft nproc 1000
* hard nproc 2000
* soft nofile 4096
* hard nofile 8192
EOF

# Configure kernel parameters for security
print_status "Configuring kernel security parameters..."
cat >> /etc/sysctl.conf << 'EOF'

# Security kernel parameters
# Disable IP forwarding
net.ipv4.ip_forward = 0

# Disable source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0

# Disable ICMP broadcasts
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Enable bad error message protection
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Enable SYN flood protection
net.ipv4.tcp_syncookies = 1

# Enable reverse path filtering
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Disable IPv6 if not needed
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1

# Disable core dumps
fs.suid_dumpable = 0

# Randomize memory addresses
kernel.randomize_va_space = 2
EOF

# Apply kernel parameters
sysctl -p

# Configure auditd
print_status "Configuring audit daemon..."
cat > /etc/audit/auditd.conf << 'EOF'
log_file = /var/log/audit/audit.log
log_format = RAW
log_group = root
priority_boost = 4
flush = INCREMENTAL
freq = 20
num_logs = 5
disp_qos = lossy
dispatcher = /sbin/audispd
name_format = NONE
max_log_file = 6
max_log_file_action = ROTATE
space_left = 75
space_left_action = SYSLOG
action_mail_acct = root
admin_space_left = 50
admin_space_left_action = SUSPEND
disk_full_action = SUSPEND
disk_error_action = SUSPEND
EOF

# Configure audit rules
cat > /etc/audit/rules.d/audit.rules << 'EOF'
# Delete all previous rules
-D

# Set buffer size
-b 8192

# Make the configuration immutable
-e 2

# Log all system calls
-a always,exit -F arch=b64 -S execve
-a always,exit -F arch=b32 -S execve

# Log file access
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k identity

# Log network configuration
-w /etc/hosts -p wa -k system-locale
-w /etc/network/ -p wa -k system-locale

# Log systemd configuration
-w /etc/systemd/ -p wa -k system-locale
-w /lib/systemd/ -p wa -k system-locale

# Log kernel module loading
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules

# Log mount operations
-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=4294967295 -k export
-a always,exit -F arch=b32 -S mount -F auid>=1000 -F auid!=4294967295 -k export
EOF

# Configure AIDE (Advanced Intrusion Detection Environment)
print_status "Configuring AIDE..."
aideinit --yes
cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# Configure logwatch
print_status "Configuring logwatch..."
cat > /etc/logwatch/conf/logwatch.conf << 'EOF'
LogDir = /var/log
TmpDir = /var/cache/logwatch
MailTo = root
MailFrom = Logwatch
Detail = Low
Range = Today
EOF

# Create security monitoring script
print_status "Creating security monitoring script..."
cat > /usr/local/bin/security-check.sh << 'EOF'
#!/bin/bash

echo "=== Security Status Check ==="
echo "Date: $(date)"
echo ""

echo "=== Failed Login Attempts ==="
grep "Failed password" /var/log/auth.log | tail -10

echo ""
echo "=== SSH Connections ==="
ss -tuln | grep :22

echo ""
echo "=== UFW Status ==="
ufw status

echo ""
echo "=== Fail2ban Status ==="
fail2ban-client status

echo ""
echo "=== Open Ports ==="
netstat -tuln

echo ""
echo "=== Running Services ==="
systemctl list-units --type=service --state=running | head -20

echo ""
echo "=== Disk Usage ==="
df -h

echo ""
echo "=== Memory Usage ==="
free -h
EOF

chmod +x /usr/local/bin/security-check.sh

# Create daily security report cron job
print_status "Setting up daily security reports..."
cat > /etc/cron.daily/security-report << 'EOF'
#!/bin/bash
/usr/local/bin/security-check.sh > /var/log/security-report-$(date +%Y%m%d).log 2>&1
EOF

chmod +x /etc/cron.daily/security-report

# Enable and start services
print_status "Enabling and starting security services..."
systemctl enable fail2ban
systemctl start fail2ban
systemctl enable ufw
systemctl enable auditd
systemctl start auditd
systemctl enable apparmor
systemctl start apparmor

# Restart SSH to apply new configuration
print_status "Restarting SSH service..."
systemctl restart ssh

# Final security recommendations
print_status "Server hardening completed!"
print_warning "IMPORTANT: Before disconnecting, ensure you have:"
print_warning "1. Generated and configured SSH keys for authentication"
print_warning "2. Tested SSH connection with the new configuration"
print_warning "3. Documented the server's IP and access credentials"
print_warning "4. Set up monitoring and alerting for security events"

print_status "Security services enabled:"
echo "- UFW Firewall"
echo "- Fail2ban (SSH protection)"
echo "- Audit daemon"
echo "- AppArmor"
echo "- Automatic security updates"
echo "- Daily security reports"
