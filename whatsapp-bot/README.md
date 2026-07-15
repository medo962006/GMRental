# Hostel WhatsApp Bot - README

## Overview
This bot sends daily rent reminders to unpaid tenants at 12:00 PM Egypt Time.
It tracks sent messages in Supabase to avoid duplicate reminders.

## Features
- ✅ Runs daily at 12:00 PM Egypt Time (handles DST automatically)
- ✅ Only sends to unpaid tenants (`payment_status = 'unpaid'`)
- ✅ Tracks sent messages in `whatsapp_logs` - no duplicates
- ✅ Supports multiple phone numbers per tenant (tries each until success)
- ✅ Logs all activity to Supabase
- ✅ Arabic message template
- ✅ Docker & systemd deployment ready

## Quick Start

### 1. Configure Environment
```bash
cd whatsapp-bot
cp .env.example .env
# Edit .env with your Supabase credentials
```

### 2. Run Locally (Development)
```bash
# Install dependencies (skip Chrome download - use system Chrome)
PUPPETEER_SKIP_DOWNLOAD=true npm install

# Or use the npm script
npm run install:chrome

# Start the bot
npm start
```

### 3. First Run - QR Code
On first run, scan the QR code in the terminal with WhatsApp on your phone.
The session is saved in `.wwebjs_auth/` for subsequent runs.

### 4. Deploy to VPS

#### Option A: Docker (Recommended)
```bash
cd whatsapp-bot
cp .env.example .env
# Edit .env
docker-compose up -d --build
docker-compose logs -f  # Watch logs, scan QR code on first run
```

#### Option B: Systemd (Direct on VPS)
```bash
# On your VPS
./deploy.sh root your-vps-ip /opt/hostel-whatsapp-bot

# Then check logs
journalctl -u hostel-whatsapp-bot -f
```

## Configuration

### Required Environment Variables
| Variable | Description |
|----------|-------------|
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key (bypasses RLS) |
| `BOT_NAME` | WhatsApp client ID for session storage |

### Supabase Tables Required
- `tenants` (id, name, phone, room_id, payment_status, insurance_amount, status)
- `rooms` (id, room_number)
- `whatsapp_logs` (id, tenant_id, message_type, message_body, status, sent_at)

### Custom Message Template
Add to `.env`:
```env
REMINDER_TEMPLATE=Your custom Arabic message with {name} and {room_number}
```

## How It Works

1. **Daily at 12:00 PM Egypt Time**: Cron triggers `sendRentReminders()`
2. **Fetch unpaid tenants**: Queries Supabase for `payment_status = 'unpaid'`
3. **Check logs**: For each tenant, checks `whatsapp_logs` for existing `debt_reminder` with `status = 'sent'`
4. **Skip if sent**: If already sent, logs "Skipping" and continues
5. **Format phones**: Parses phone strings (handles `/`, `-`, `\` separators)
6. **Send via WhatsApp**: Tries each phone number until success
6. **Log result**: Inserts record into `whatsapp_logs`

## Phone Number Format
The bot accepts various formats and normalizes them:
- `012-80763221/011-10975480` → tries both numbers
- `01035163406` → converts to `201035163406@c.us`
- `01555512556--01555512557` → tries both
- `01044606124\01131802332` → tries both

## Monitoring

### Local/Docker
```bash
docker-compose logs -f whatsapp-bot
```

### Systemd
```bash
journalctl -u hostel-whatsapp-bot -f
```

## Troubleshooting

### QR Code not showing
- Ensure terminal supports ANSI colors
- Try `npm start 2>&1 | tee bot.log`

### Chrome/Puppeteer issues
- Use `PUPPETEER_SKIP_DOWNLOAD=true` and install Chrome system-wide
- On Ubuntu: `apt-get install -y google-chrome-stable`
- Set `PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome-stable`

### Rate limiting
- Bot waits 3 seconds between tenants
- Tries each phone with 1 second delay
- WhatsApp Web.js handles connection automatically

### Session lost
- Delete `.wwebjs_auth/` folder
- Restart bot and re-scan QR code

## File Structure
```
whatsapp-bot/
├── index.js           # Main bot logic
├── package.json       # Dependencies
├── Dockerfile         # Docker image
├── docker-compose.yml # Docker compose
├── deploy.sh          # VPS deployment script
├── test.js            # Configuration test
├── .env.example       # Environment template
├── .env               # Your config (not in git)
├── .wwebjs_auth/      # WhatsApp session (not in git)
└── data/              # Docker volume mount
```

## License
Internal use only.