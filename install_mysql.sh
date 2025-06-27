#!/bin/bash

# Secure MySQL Server Setup Script (Ubuntu) — No App DB/User

set -e

# === Colors ===
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# === Root Check ===
if [[ $EUID -ne 0 ]]; then
    error "Run this script as root using sudo."
    exit 1
fi

# === System Update ===
info "Updating packages..."
apt update && apt upgrade -y

# === Install MySQL Server ===
info "Installing MySQL server..."
DEBIAN_FRONTEND=noninteractive apt install -y mysql-server mysql-client

# === Start & Enable MySQL ===
info "Starting and enabling MySQL..."
systemctl start mysql
systemctl enable mysql

# === Secure Root Password Setup ===
ROOT_PASSWORD=$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 20)

info "Setting root password and securing installation..."
mysql --user=root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

# === Store root password in root-only config ===
cat > /root/.my.cnf <<EOF
[client]
user=root
password=${ROOT_PASSWORD}
EOF

chmod 600 /root/.my.cnf

# === Optional: Harden MySQL Config ===
info "Applying secure defaults to mysqld.cnf..."
cp /etc/mysql/mysql.conf.d/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf.backup

cat > /etc/mysql/mysql.conf.d/mysqld.cnf <<'EOF'
[mysqld]
pid-file = /var/run/mysqld/mysqld.pid
socket = /var/run/mysqld/mysqld.sock
datadir = /var/lib/mysql
log-error = /var/log/mysql/error.log
bind-address = 127.0.0.1
local-infile = 0
secure-file-priv = /var/lib/mysql-files
skip-symbolic-links
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
EOF

systemctl restart mysql

# === Summary ===
info "MySQL Server setup complete!"
echo
echo "=== MySQL Root Access Info ==="
echo "Root password saved to: /root/.my.cnf"
echo "Use 'mysql' as root without typing password (only as root user)"
