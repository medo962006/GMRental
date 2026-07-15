#!/bin/bash
# deploy.sh - Deploy the WhatsApp bot to a VPS
# Usage: ./deploy.sh [user@host] [remote_path]

set -e

# Configuration
REMOTE_USER="${1:-root}"
REMOTE_HOST="${2:-your-vps-ip}"
REMOTE_PATH="${3:-/opt/hostel-whatsapp-bot}"
LOCAL_PATH="$(pwd)"

echo "🚀 Deploying Hostel WhatsApp Bot to ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}"

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ .env file not found! Copy .env.example to .env and fill in your values"
    exit 1
fi

# Create remote directory
echo "📁 Creating remote directory..."
ssh ${REMOTE_USER}@${REMOTE_HOST} "mkdir -p ${REMOTE_PATH}"

# Copy files (excluding node_modules and .git)
echo "📤 Copying files..."
rsync -avz --progress \
    --exclude 'node_modules' \
    --exclude '.git' \
    --exclude '.wwebjs_auth' \
    --exclude '.wwebjs_cache' \
    --exclude '*.log' \
    ${LOCAL_PATH}/ ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/

# Install dependencies on remote
echo "📦 Installing dependencies on remote..."
ssh ${REMOTE_USER}@${REMOTE_HOST} "cd ${REMOTE_PATH} && PUPPETEER_SKIP_DOWNLOAD=true npm install --production"

# Install Chrome on remote (if not present)
echo "🌐 Checking Chrome installation..."
ssh ${REMOTE_USER}@${REMOTE_HOST} "
    if ! command -v google-chrome-stable &> /dev/null && ! command -v chromium &> /dev/null; then
        echo 'Installing Chrome...'
        wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add -
        echo 'deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main' > /etc/apt/sources.list.d/google-chrome.list
        apt-get update && apt-get install -y google-chrome-stable
    else
        echo 'Chrome already installed'
    fi
    
    # Install Node.js 22 if not present
    if ! command -v node &> /dev/null || [[ \$(node --version | cut -d'v' -f2 | cut -d'.' -f1) -lt 22 ]]; then
        echo 'Installing Node.js 22...'
        curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
        apt-get install -y nodejs
    else
        echo 'Node.js 22+ already installed'
    fi
"

# Create systemd service
echo "⚙️ Creating systemd service..."
ssh ${REMOTE_USER}@${REMOTE_HOST} "cat > /etc/systemd/system/hostel-whatsapp-bot.service << 'EOF'
[Unit]
Description=Hostel Manager WhatsApp Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${REMOTE_PATH}
Environment=NODE_ENV=production
EnvironmentFile=${REMOTE_PATH}/.env
ExecStart=/usr/bin/node ${REMOTE_PATH}/index.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Resource limits
MemoryLimit=512M
CPUQuota=50%

[Install]
WantedBy=multi-user.target
EOF"

# Reload systemd and enable service
echo "🔄 Reloading systemd and enabling service..."
ssh ${REMOTE_USER}@${REMOTE_HOST} "
    systemctl daemon-reload
    systemctl enable hostel-whatsapp-bot
    systemctl restart hostel-whatsapp-bot
"

echo "✅ Deployment complete!"
echo ""
echo "📋 Useful commands:"
echo "  View logs:     ssh ${REMOTE_USER}@${REMOTE_HOST} 'journalctl -u hostel-whatsapp-bot -f'"
echo "  Restart bot:   ssh ${REMOTE_USER}@${REMOTE_HOST} 'systemctl restart hostel-whatsapp-bot'"
echo "  Stop bot:      ssh ${REMOTE_USER}@${REMOTE_HOST} 'systemctl stop hostel-whatsapp-bot'"
echo "  Status:        ssh ${REMOTE_USER}@${REMOTE_HOST} 'systemctl status hostel-whatsapp-bot'"