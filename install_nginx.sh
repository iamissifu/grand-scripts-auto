#!/bin/bash

# Nginx Web Server Installation Script for Ubuntu
# This script installs and configures Nginx with security and performance optimizations

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

print_status "Starting Nginx web server installation..."

# Update system packages
print_status "Updating system packages..."
apt update && apt upgrade -y

# Install Nginx and dependencies
print_status "Installing Nginx and dependencies..."
apt install -y \
    nginx \
    curl \
    wget \
    unzip \
    software-properties-common

# ============================================================================
# Configure Nginx
# ============================================================================
print_status "Configuring Nginx..."

# Backup original configuration
cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup

# Create main Nginx configuration
cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name _;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Remove server signature
    server_tokens off;

    # Root directory
    root /var/www/html;
    index index.html index.htm index.php;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private must-revalidate auth;
    gzip_types 
        text/plain 
        text/css 
        text/xml 
        text/javascript 
        application/x-javascript 
        application/xml+rss 
        application/json 
        application/javascript;

    # Security: Hide nginx version
    server_tokens off;

    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    # Handle static files with caching
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|pdf|txt|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header X-Content-Type-Options nosniff;
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Deny access to backup files
    location ~ ~$ {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Main location block
    location / {
        try_files $uri $uri/ =404;
    }
}
EOF

# Create a test web page
print_status "Creating test web page..."
cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Nginx Server - DevSecOps Environment</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
        }
        .container {
            background: rgba(255, 255, 255, 0.1);
            padding: 30px;
            border-radius: 15px;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
        }
        h1 {
            text-align: center;
            margin-bottom: 30px;
            font-size: 2.5em;
        }
        .status {
            background: rgba(76, 175, 80, 0.2);
            border: 1px solid #4CAF50;
            padding: 20px;
            border-radius: 10px;
            margin: 20px 0;
        }
        .info {
            background: rgba(33, 150, 243, 0.2);
            border: 1px solid #2196F3;
            padding: 20px;
            border-radius: 10px;
            margin: 20px 0;
        }
        .warning {
            background: rgba(255, 152, 0, 0.2);
            border: 1px solid #FF9800;
            padding: 20px;
            border-radius: 10px;
            margin: 20px 0;
        }
        .feature-list {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }
        .feature {
            background: rgba(255, 255, 255, 0.1);
            padding: 15px;
            border-radius: 8px;
            border-left: 4px solid #4CAF50;
        }
        .timestamp {
            text-align: center;
            margin-top: 30px;
            opacity: 0.8;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Nginx Web Server</h1>
        
        <div class="status">
            <h3>Server Status: Online</h3>
            <p>Your Nginx web server is successfully running and configured with security best practices!</p>
        </div>

        <div class="info">
            <h3>Server Information:</h3>
            <div class="feature-list">
                <div class="feature">
                    <strong>Web Server:</strong> Nginx
                </div>
                <div class="feature">
                    <strong>Port:</strong> 80 (HTTP)
                </div>
                <div class="feature">
                    <strong>Document Root:</strong> /var/www/html
                </div>
                <div class="feature">
                    <strong>Security Headers:</strong> Enabled
                </div>
                <div class="feature">
                    <strong>Gzip Compression:</strong> Enabled
                </div>
                <div class="feature">
                    <strong>Static File Caching:</strong> Enabled
                </div>
            </div>
        </div>

        <div class="warning">
            <h3>Next Steps:</h3>
            <ol>
                <li>Install MySQL database server</li>
                <li>Install Node.js runtime environment</li>
                <li>Configure SSL certificates for HTTPS</li>
                <li>Set up your web application</li>
                <li>Configure monitoring and logging</li>
            </ol>
        </div>

        <div class="info">
            <h3>🔧 Management Commands:</h3>
            <ul>
                <li><code>sudo systemctl status nginx</code> - Check service status</li>
                <li><code>sudo nginx -t</code> - Test configuration</li>
                <li><code>sudo systemctl reload nginx</code> - Reload configuration</li>
                <li><code>sudo tail -f /var/log/nginx/access.log</code> - Monitor access logs</li>
                <li><code>sudo tail -f /var/log/nginx/error.log</code> - Monitor error logs</li>
            </ul>
        </div>

        <div class="timestamp">
            <p>Server Time: <span id="server-time"></span></p>
            <script>
                document.getElementById('server-time').textContent = new Date().toLocaleString();
            </script>
        </div>
    </div>
</body>
</html>
EOF

# Set proper permissions
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

# ============================================================================
# Configure Nginx Main Settings
# ============================================================================
print_status "Configuring Nginx main settings..."

# Backup original nginx.conf
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup

# Create optimized nginx.conf
cat > /etc/nginx/nginx.conf << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    # Basic Settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;

    # MIME Types
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log;

    # Gzip Settings
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Rate Limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=login:10m rate=1r/s;

    # File Upload Limits
    client_max_body_size 10M;
    client_body_timeout 60s;
    client_header_timeout 60s;

    # Include site configurations
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

# ============================================================================
# Enable and Start Nginx
# ============================================================================
print_status "Enabling and starting Nginx..."

# Test Nginx configuration
nginx -t

# Enable and start Nginx
systemctl enable nginx
systemctl start nginx

# ============================================================================
# Create Management Scripts
# ============================================================================
print_status "Creating management scripts..."

# Nginx status script
cat > /usr/local/bin/nginx-status.sh << 'EOF'
#!/bin/bash

echo "=== Nginx Status Report ==="
echo "Date: $(date)"
echo ""

echo "=== Service Status ==="
systemctl is-active nginx
systemctl status nginx --no-pager -l

echo ""
echo "=== Configuration Test ==="
nginx -t

echo ""
echo "=== Active Connections ==="
ss -tuln | grep :80

echo ""
echo "=== Recent Access Logs ==="
tail -10 /var/log/nginx/access.log

echo ""
echo "=== Recent Error Logs ==="
tail -10 /var/log/nginx/error.log

echo ""
echo "=== Nginx Version ==="
nginx -v
EOF

chmod +x /usr/local/bin/nginx-status.sh

# ============================================================================
# Final Configuration
# ============================================================================
print_status "Nginx installation and configuration completed!"

echo ""
echo "=== Installation Summary ==="
echo "Nginx Web Server: Running on port 80"
echo "Security Headers: Configured"
echo "Gzip Compression: Enabled"
echo "Static File Caching: Configured"
echo "Logging: Configured"
echo ""
echo "=== Access Information ==="
echo "Web Interface: http://$(curl -s ifconfig.me)"
echo "Health Check: http://$(curl -s ifconfig.me)/health"
echo ""
echo "=== Management Commands ==="
echo "Status Check: /usr/local/bin/nginx-status.sh"
echo "Reload Config: sudo systemctl reload nginx"
echo "View Logs: sudo tail -f /var/log/nginx/access.log"
echo ""
print_warning "Next: Run install_mysql.sh to set up the database server" 