#!/bin/bash

# DevSecOps Application Deployment Script
# This script deploys the sample Express.js application

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

print_status "Starting DevSecOps application deployment..."

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    print_error "Node.js is not installed. Please run install_nodejs.sh first."
    exit 1
fi

# Check if PM2 is installed
if ! command -v pm2 &> /dev/null; then
    print_error "PM2 is not installed. Please run install_nodejs.sh first."
    exit 1
fi

# ============================================================================
# Create Application Files
# ============================================================================
print_status "Creating application files..."

# Navigate to app directory
cd /var/www/app

# Create package.json
cat > package.json << 'EOF'
{
  "name": "devsecops-app",
  "version": "1.0.0",
  "description": "Sample DevSecOps application with security best practices",
  "main": "app.js",
  "scripts": {
    "start": "node app.js",
    "dev": "nodemon app.js",
    "pm2": "pm2 start ecosystem.config.js --env production",
    "test": "echo \"No tests specified\" && exit 0",
    "lint": "eslint . --ext .js",
    "lint:fix": "eslint . --ext .js --fix"
  },
  "dependencies": {
    "express": "^4.18.2",
    "mysql2": "^3.6.0",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "dotenv": "^16.3.1",
    "express-rate-limit": "^7.1.5",
    "express-validator": "^7.0.1",
    "bcryptjs": "^2.4.3",
    "jsonwebtoken": "^9.0.2",
    "morgan": "^1.10.0",
    "compression": "^1.7.4"
  },
  "devDependencies": {
    "nodemon": "^3.0.1",
    "eslint": "^8.55.0",
    "prettier": "^3.1.0"
  },
  "keywords": ["devsecops", "nodejs", "express", "security"],
  "author": "DevSecOps Team",
  "license": "MIT",
  "engines": {
    "node": ">=18.0.0",
    "npm": ">=8.0.0"
  }
}
EOF

# Create main application file
cat > app.js << 'EOF'
const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const compression = require('compression');
const morgan = require('morgan');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Security middleware
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            styleSrc: ["'self'", "'unsafe-inline'"],
            scriptSrc: ["'self'"],
            imgSrc: ["'self'", "data:", "https:"],
        },
    },
}));

// Rate limiting
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // limit each IP to 100 requests per windowMs
    message: 'Too many requests from this IP, please try again later.',
    standardHeaders: true,
    legacyHeaders: false,
});
app.use(limiter);

// Compression middleware
app.use(compression());

// Logging middleware
app.use(morgan('combined'));

// CORS configuration
app.use(cors({
    origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
    credentials: true
}));

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Database connection pool
const dbConfig = {
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'app_user',
    password: process.env.DB_PASSWORD || 'SecurePassword123!',
    database: process.env.DB_NAME || 'app_db',
    port: process.env.DB_PORT || 3306,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
    acquireTimeout: 60000,
    timeout: 60000,
    reconnect: true
};

let pool;

// Initialize database connection
async function initDatabase() {
    try {
        pool = mysql.createPool(dbConfig);
        await pool.execute('SELECT 1');
        console.log('Database connected successfully');
    } catch (error) {
        console.error('Database connection failed:', error.message);
        // Don't exit, allow app to run without database
    }
}

// ============================================================================
// Routes
// ============================================================================

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        version: process.env.npm_package_version || '1.0.0',
        environment: process.env.NODE_ENV || 'development'
    });
});

// Main API endpoint
app.get('/', (req, res) => {
    res.json({
        message: 'DevSecOps API is running!',
        timestamp: new Date().toISOString(),
        environment: process.env.NODE_ENV || 'development',
        version: process.env.npm_package_version || '1.0.0',
        endpoints: {
            health: '/health',
            status: '/api/status',
            users: '/api/users',
            projects: '/api/projects'
        }
    });
});

// API status endpoint
app.get('/api/status', async (req, res) => {
    try {
        if (!pool) {
            return res.status(503).json({ 
                error: 'Database not connected',
                status: 'degraded'
            });
        }
        
        const [rows] = await pool.execute('SELECT 1 as status');
        res.json({
            status: 'ok',
            database: 'connected',
            data: rows[0],
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({ 
            error: 'Database error', 
            details: error.message,
            status: 'error'
        });
    }
});

// Users endpoint
app.get('/api/users', async (req, res) => {
    try {
        if (!pool) {
            return res.status(503).json({ error: 'Database not connected' });
        }
        
        const [rows] = await pool.execute('SELECT id, username, email, created_at FROM users LIMIT 10');
        res.json({
            users: rows,
            count: rows.length,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({ error: 'Database error', details: error.message });
    }
});

// Projects endpoint
app.get('/api/projects', async (req, res) => {
    try {
        if (!pool) {
            return res.status(503).json({ error: 'Database not connected' });
        }
        
        const [rows] = await pool.execute('SELECT * FROM projects ORDER BY created_at DESC LIMIT 10');
        res.json({
            projects: rows,
            count: rows.length,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({ error: 'Database error', details: error.message });
    }
});

// System information endpoint
app.get('/api/system', (req, res) => {
    const os = require('os');
    res.json({
        platform: os.platform(),
        arch: os.arch(),
        nodeVersion: process.version,
        memory: {
            total: os.totalmem(),
            free: os.freemem(),
            used: os.totalmem() - os.freemem()
        },
        uptime: os.uptime(),
        loadAverage: os.loadavg(),
        timestamp: new Date().toISOString()
    });
});

// 404 handler
app.use((req, res) => {
    res.status(404).json({ 
        error: 'Route not found',
        path: req.path,
        method: req.method,
        timestamp: new Date().toISOString()
    });
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error('Error:', err.stack);
    res.status(500).json({ 
        error: 'Something went wrong!',
        message: process.env.NODE_ENV === 'development' ? err.message : 'Internal server error',
        timestamp: new Date().toISOString()
    });
});

// ============================================================================
// Start Server
// ============================================================================
async function startServer() {
    await initDatabase();
    
    app.listen(PORT, () => {
        console.log(DevSecOps API server running on port ${PORT});
        console.log(Health check: http://localhost:${PORT}/health);
        console.log(API status: http://localhost:${PORT}/api/status);
        console.log(Users API: http://localhost:${PORT}/api/users);
        console.log(Projects API: http://localhost:${PORT}/api/projects);
        console.log(System info: http://localhost:${PORT}/api/system);
        console.log(Environment: ${process.env.NODE_ENV || 'development'});
    });
}

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully');
    if (pool) {
        pool.end();
    }
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('SIGINT received, shutting down gracefully');
    if (pool) {
        pool.end();
    }
    process.exit(0);
});

startServer().catch(console.error);
EOF

# Create PM2 ecosystem file
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'devsecops-app',
    script: 'app.js',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'development',
      PORT: 3000
    },
    env_production: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: '/var/log/pm2/err.log',
    out_file: '/var/log/pm2/out.log',
    log_file: '/var/log/pm2/combined.log',
    time: true,
    max_memory_restart: '1G',
    node_args: '--max-old-space-size=1024',
    watch: false,
    ignore_watch: ['node_modules', 'logs'],
    merge_logs: true,
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z'
  }]
};
EOF

# Create ESLint configuration
cat > .eslintrc.js << 'EOF'
module.exports = {
  env: {
    node: true,
    es2021: true,
  },
  extends: [
    'eslint:recommended',
  ],
  parserOptions: {
    ecmaVersion: 12,
    sourceType: 'module',
  },
  rules: {
    'indent': ['error', 2],
    'linebreak-style': ['error', 'unix'],
    'quotes': ['error', 'single'],
    'semi': ['error', 'always'],
    'no-unused-vars': ['warn'],
    'no-console': ['warn', { allow: ['warn', 'error'] }],
  },
};
EOF

# Create Prettier configuration
cat > .prettierrc << 'EOF'
{
  "semi": true,
  "trailingComma": "es5",
  "singleQuote": true,
  "printWidth": 80,
  "tabWidth": 2
}
EOF

# ============================================================================
# Install Application Dependencies
# ============================================================================
print_status "Installing application dependencies..."
npm install

# ============================================================================
# Create Management Scripts
# ============================================================================
print_status "Creating application management scripts..."

# Application status script
cat > /usr/local/bin/app-status.sh << 'EOF'
#!/bin/bash

echo "=== DevSecOps Application Status Report ==="
echo "Date: $(date)"
echo ""

echo "=== PM2 Status ==="
sudo -u ubuntu pm2 status

echo ""
echo "=== Application Logs ==="
sudo -u ubuntu pm2 logs devsecops-app --lines 10

echo ""
echo "=== Active Ports ==="
netstat -tuln | grep :3000

echo ""
echo "=== Process Information ==="
ps aux | grep node | grep -v grep

echo ""
echo "=== Application Directory ==="
ls -la /var/www/app/

echo ""
echo "=== Environment File ==="
if [ -f "/var/www/app/.env" ]; then
    echo "Environment file exists"
else
    echo "Environment file not found"
fi
EOF

chmod +x /usr/local/bin/app-status.sh

# Application restart script
cat > /usr/local/bin/restart-app.sh << 'EOF'
#!/bin/bash

echo "Restarting DevSecOps application..."
sudo -u ubuntu pm2 restart devsecops-app

if [ $? -eq 0 ]; then
    echo "Application restarted successfully!"
    echo "Check status with: /usr/local/bin/app-status.sh"
else
    echo "Application restart failed!"
    exit 1
fi
EOF

chmod +x /usr/local/bin/restart-app.sh

# Application deployment script
cat > /usr/local/bin/deploy-app.sh << 'EOF'
#!/bin/bash

echo "Deploying DevSecOps application..."

# Navigate to app directory
cd /var/www/app

# Pull latest changes (if using git)
if [ -d ".git" ]; then
    echo "Pulling latest changes from git..."
    git pull origin main
fi

# Install dependencies
echo "Installing dependencies..."
npm install --production

# Restart application
echo "Restarting application..."
sudo -u ubuntu pm2 restart devsecops-app

if [ $? -eq 0 ]; then
    echo "Application deployed successfully!"
    echo "Check status with: /usr/local/bin/app-status.sh"
else
    echo "Application deployment failed!"
    exit 1
fi
EOF

chmod +x /usr/local/bin/deploy-app.sh

# ============================================================================
# Start Application with PM2
# ============================================================================
print_status "Starting application with PM2..."
sudo -u ubuntu pm2 start ecosystem.config.js --env production
sudo -u ubuntu pm2 save

# ============================================================================
# Final Configuration
# ============================================================================
print_status "DevSecOps application deployment completed!"

echo ""
echo "=== Deployment Summary ==="
echo "Express.js Application: Deployed and running"
echo "Security Middleware: Helmet, CORS, Rate Limiting"
echo "Logging: Morgan and PM2 logs configured"
echo "Database Integration: MySQL connection configured"
echo "PM2 Process Manager: Application managed"
echo ""
echo "=== Application Information ==="
echo "Application URL: http://$(curl -s ifconfig.me):3000"
echo "Health Check: http://$(curl -s ifconfig.me):3000/health"
echo "API Status: http://$(curl -s ifconfig.me):3000/api/status"
echo "Users API: http://$(curl -s ifconfig.me):3000/api/users"
echo "Projects API: http://$(curl -s ifconfig.me):3000/api/projects"
echo "System Info: http://$(curl -s ifconfig.me):3000/api/system"
echo ""
echo "=== Management Commands ==="
echo "App Status: /usr/local/bin/app-status.sh"
echo "Restart App: /usr/local/bin/restart-app.sh"
echo "Deploy Updates: /usr/local/bin/deploy-app.sh"
echo "View Logs: sudo -u ubuntu pm2 logs devsecops-app"
echo "PM2 Monitor: sudo -u ubuntu pm2 monit"
echo ""
echo "=== Development Commands ==="
echo "Development Mode: cd /var/www/app && npm run dev"
echo "Lint Code: cd /var/www/app && npm run lint"
echo "Format Code: cd /var/www/app && npm run lint:fix"
echo ""
