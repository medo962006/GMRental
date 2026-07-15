# Dockerfile for Hostel WhatsApp Bot
# Build: docker build -t hostel-whatsapp-bot .
# Run: docker run -d --name hostel-bot --env-file .env -v ./data:/app/.wwebjs_auth hostel-whatsapp-bot

FROM node:20-slim

# Install Chrome dependencies
RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    ca-certificates \
    fonts-liberation \
    libappindicator3-1 \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libxss1 \
    libxtst6 \
    xdg-utils \
    && rm -rf /var/lib/apt/lists/*

# Install Chrome
RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies (skip Chrome download since we installed it)
ENV PUPPETEER_SKIP_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome-stable

RUN npm ci --only=production

# Copy source code
COPY index.js ./
COPY .env.example ./

# Create non-root user for security
RUN groupadd -r botuser && useradd -r -g botuser botuser \
    && mkdir -p /app/.wwebjs_auth \
    && chown -R botuser:botuser /app

# Switch to non-root user
USER botuser

# Expose no ports (this is a background worker)
# The bot connects to WhatsApp Web, not a web server

# Health check - check if process is running
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD pgrep -f "node index.js" || exit 1

# Start the bot
CMD ["node", "index.js"]