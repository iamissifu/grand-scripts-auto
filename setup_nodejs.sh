#!/bin/bash

# Node.js Runtime Environment Installation Script for Ubuntu
# This script installs Node.js, npm, and PM2 process manager

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

print_status "Starting Node.js runtime environment installation..."

# Update system packages
print_status "Updating system packages..."
apt update && apt upgrade -y

# Install essential packages
print_status "Installing essential packages..."
apt install -y \
    curl \
    wget \
    git \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    build-essential \
    python3 \
    python3-pip

# ============================================================================
# Install Node.js and npm
# ============================================================================
print_status "Installing Node.js and npm..."

# Add NodeSource repository for Node.js 18.x LTS
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -

# Install Node.js
apt install -y nodejs

# Verify installation
print_status "Verifying Node.js installation..."
node --version
npm --version

# Install global npm packages
print_status "Installing global npm packages..."
npm install -g \
    pm2 \
    nodemon \
    yarn \
    typescript \
    @types/node \
    eslint \
    prettier

# ============================================================================
# Configure PM2
# ============================================================================
print_status "Configuring PM2 process manager..."

# Create log directory for PM2
mkdir -p /var/log/pm2
chown -R ubuntu:ubuntu /var/log/pm2

# Configure PM2 startup
print_status "Configuring PM2 startup..."
sudo -u ubuntu pm2 startup