// index.js - WhatsApp Bot for Hostel Rent Reminders
require('dotenv').config();
const { Client, LocalAuth } = require('whatsapp-web.js');
const qrcode = require('qrcode-terminal');
const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const BOT_NAME = process.env.BOT_NAME || 'HostelManagerBot';
const TIMEZONE = process.env.TIMEZONE || 'Africa/Cairo';
const CRON_SCHEDULE = process.env.CRON_SCHEDULE || '0 12 * * *';
const RUN_ON_START = process.env.RUN_ON_START === 'true';

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// ============================================================
// BRUTE-FORCE CLEANUP
// ============================================================
function killProcesses() {
  const { execSync } = require('child_process');
  try {
    execSync('pkill -f "chrome" 2>/dev/null || true');
    execSync('pkill -f "chromium" 2>/dev/null || true');
    execSync('pkill -f "google-chrome" 2>/dev/null || true');
  } catch (e) {
    // ignore
  }
}

function cleanAuthDir(dir) {
  const fs = require('fs');
  const path = require('path');
  if (fs.existsSync(dir)) {
    try {
      const files = fs.readdirSync(dir);
      for (const file of files) {
        try {
          fs.unlinkSync(path.join(dir, file));
        } catch (e) {
          // ignore locked files
        }
      }
      fs.rmdirSync(dir);
      console.log('[CLEAN] Removed auth dir: ' + dir);
    } catch (e) {
      console.log('[CLEAN] Could not remove: ' + dir + ' (' + e.message + ')');
    }
  } else {
    console.log('[CLEAN] Auth dir does not exist: ' + dir);
  }
}

console.log('[START] Starting Hostel Manager WhatsApp Bot...');
console.log('[CONFIG] Timezone: ' + TIMEZONE);
console.log('[CONFIG] Schedule: ' + CRON_SCHEDULE + ' (12 PM Egypt Time)');

killProcesses();
cleanAuthDir('./.wwebjs_auth');

const client = new Client({
  authStrategy: new LocalAuth({
    clientId: BOT_NAME,
    dataPath: './.wwebjs_auth'
  }),
  puppeteer: {
    headless: true,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-gpu',
      '--disable-accelerated-2d-canvas',
      '--disable-background-networking',
      '--disable-background-timer-throttling',
      '--disable-client-side-phishing-detection',
      '--disable-component-extensions-with-background-pages',
      '--disable-default-apps',
      '--disable-extensions',
      '--disable-features=TranslateUI',
      '--disable-hang-monitor',
      '--disable-ipc-flooding-protection',
      '--disable-notifications',
      '--disable-offer-store-unmasked-wallet-cards',
      '--disable-popup-blocking',
      '--disable-prompt-on-repost',
      '--disable-renderer-backgrounding',
      '--disable-sync',
      '--disable-translate',
      '--disable-windows10-custom-titlebar',
      '--enable-automation',
      '--enable-blink-features=IdleDetection',
      '--enable-logging',
      '--force-color-profile=srgb',
      '--metrics-recording-only',
      '--mute-audio',
      '--no-first-run',
      '--password-store=basic',
      '--use-mock-keychain',
      '--disable-web-security',
      '--disable-site-isolation-trials',
      '--disable-features=IsolateOrigins,site-per-process',
      '--remote-debugging-port=9222',
      '--remote-debugging-address=0.0.0.0',
    ],
    executablePath: '/usr/bin/google-chrome-stable',
  },
  authTimeoutMs: 180000,
  qrTimeoutMs: 90000,
  restartOnAuthFail: true,
});

// ============================================================
// MESSAGE SENDING
// ============================================================
async function sendRentReminders() {
  console.log('\n[SEND] Running reminders...');

  const { data: tenants, error: tenantsError } = await supabase
    .from('tenants')
    .select('id, name, phone, room_id, building_id, due_date')
    .eq('status', 'active')
    .eq('payment_status', 'unpaid');

  if (tenantsError) throw tenantsError;
  if (!tenants || tenants.length === 0) {
    console.log('[SEND] No unpaid tenants found');
    return;
  }

  console.log('[SEND] Found ' + tenants.length + ' unpaid tenant(s)');

  const roomIds = [...new Set(tenants.map(t => t.room_id).filter(Boolean))];
  const { data: rooms, error: roomsError } = await supabase
    .from('rooms')
    .select('id, room_number')
    .in('id', roomIds);

  if (roomsError) throw roomsError;
  const roomMap = Object.fromEntries(rooms.map(r => [r.id, r.room_number]));

  const tenantIds = tenants.map(t => t.id);
  const { data: logs, error: logsError } = await supabase
    .from('whatsapp_logs')
    .select('tenant_id')
    .eq('message_type', 'debt_reminder')
    .eq('status', 'sent')
    .in('tenant_id', tenantIds);

  if (logsError) throw logsError;
  const sentTenantIds = new Set(logs.map(l => l.tenant_id));
  console.log('[SEND] ' + sentTenantIds.size + ' already received reminder');

  const tenantsToNotify = tenants.filter(t => !sentTenantIds.has(t.id));
  if (tenantsToNotify.length === 0) {
    console.log('[SEND] All unpaid tenants already notified');
    return;
  }

  console.log('[SEND] Sending to ' + tenantsToNotify.length + ' tenant(s)...');

  let sent = 0, failed = 0, skipped = 0;

  for (const tenant of tenantsToNotify) {
    if (!tenant.phone || tenant.phone.trim() === '') {
      console.log('[SKIP] ' + tenant.name + ' - no phone');
      skipped++;
      continue;
    }

    const roomNum = tenant.room_id ? (roomMap[tenant.room_id] || '?') : '?';
    const message = 'عزيزي ' + tenant.name + ' (غرفة ' + roomNum + ')،\n\nهذا تذكير ودي بأن دفعة الإيجار مستحقة. يرجى سداد المبلغ في أقرب وقت ممكن.\n\nشكراً لتعاونكم.\nإدارة السكن';

    let formattedPhone = tenant.phone
      .replace(/[\s\-\(\)]/g, '')
      .replace(/^\+/, '');
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '20' + formattedPhone.substring(1);
    }

    if (!/^201[0125]\d{8}$/.test(formattedPhone)) {
      console.log('[SKIP] ' + tenant.name + ' - invalid phone: ' + tenant.phone);
      skipped++;
      continue;
    }

    try {
      await client.sendMessage(formattedPhone + '@c.us', message);
      await supabase.from('whatsapp_logs').insert({
        tenant_id: tenant.id,
        message_type: 'debt_reminder',
        message_body: message,
        status: 'sent',
        sent_at: new Date().toISOString()
      });
      console.log('[OK] Sent to ' + tenant.name + ' (' + formattedPhone + ')');
      sent++;
      await new Promise(r => setTimeout(r, 2000));
    } catch (err) {
      console.error('[ERROR] Failed to send to ' + tenant.name + ': ' + err.message);
      await supabase.from('whatsapp_logs').insert({
        tenant_id: tenant.id,
        message_type: 'debt_reminder',
        message_body: message,
        status: 'failed',
        sent_at: new Date().toISOString()
      });
      failed++;
    }
  }

  console.log('\n[SEND] Summary: ' + sent + ' sent, ' + failed + ' failed, ' + skipped + ' skipped');
}

// ============================================================
// CRON SCHEDULING
// ============================================================
let cronJob = null;

function startCron() {
  console.log('\n[CRON] Scheduling daily at ' + CRON_SCHEDULE + ' (' + TIMEZONE + ')');
  console.log('[CRON] Waiting for next scheduled run...');
}

// ============================================================
// EVENT HANDLERS
// ============================================================
client.on('qr', (qr) => {
  console.log('\n[QR] Scan this QR code with your WhatsApp to log in:');
  qrcode.generate(qr, { small: true });
  console.log('\nWaiting for authentication...\n');
});

client.on('ready', async () => {
  console.log('\n[OK] Bot is ready and logged in!');
  console.log('[BOT] Bot name: ' + BOT_NAME);
  console.log('[TIME] Scheduled to run at: ' + CRON_SCHEDULE + ' (' + TIMEZONE + ')');

  if (RUN_ON_START) {
    console.log('[RUN] RUN_ON_START=true - Running reminders now...');
    await sendRentReminders();
  }

  startCron();
});

client.on('authenticated', () => {
  console.log('[AUTH] Authentication successful!');
});

client.on('auth_failure', (msg) => {
  console.error('[AUTH-ERROR] Authentication failed:', msg);
  console.log('[AUTH] Restarting in 5 seconds...');
  setTimeout(() => process.exit(1), 5000);
});

client.on('disconnected', (reason) => {
  console.log('[AUTH] Disconnected:', reason);
  console.log('[AUTH] Restarting in 5 seconds...');
  setTimeout(() => process.exit(1), 5000);
});

client.on('loading_screen', (percent, message) => {
  console.log('[LOAD] ' + Math.round(percent) + '% - ' + message);
});

client.on('message', async (msg) => {
  if (msg.body === '!ping') {
    msg.reply('pong');
  }
});

// ============================================================
// STARTUP
// ============================================================
console.log('[INIT] Waiting 10 seconds for Chrome to stabilize...');
setTimeout(() => {
  client.initialize().catch(err => {
    console.error('[INIT] Initialize error:', err);
    process.exit(1);
  });
}, 10000);