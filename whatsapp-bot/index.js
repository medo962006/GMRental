// index.js - WhatsApp Bot for Hostel Rent Reminders
// Runs at 12 PM Egypt Time, sends reminders to unpaid tenants
// Only sends once per tenant (tracks in whatsapp_logs)

require('dotenv').config();
const { Client, LocalAuth } = require('whatsapp-web.js');
const qrcode = require('qrcode-terminal');
const { createClient } = require('@supabase/supabase-js');
const cron = require('node-cron');

// ============================================================
// CONFIGURATION
// ============================================================
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const BOT_NAME = process.env.BOT_NAME || 'HostelManagerBot';
const CRON_SCHEDULE = process.env.CRON_SCHEDULE || '0 12 * * *'; // 12 PM daily
const TIMEZONE = process.env.TZ || 'Africa/Cairo';

// Validate config
if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('[ERROR] Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env');
  process.exit(1);
}

// Supabase client with service role (bypasses RLS)
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// ============================================================
// WHATSAPP CLIENT SETUP
// ============================================================
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
      '--disable-accelerated-2d-canvas',
      '--disable-gpu',
      '--single-process',
      '--no-zygote',
      '--disable-background-timer-throttling',
      '--disable-backgrounding-occluded-windows',
      '--disable-renderer-backgrounding',
      '--disable-features=TranslateUI',
      '--disable-ipc-flooding-protection',
      '--no-first-run',
      '--no-default-browser-check',
      '--disable-crash-reporter',
      '--disable-breakpad',
      '--disable-extensions',
      '--disable-plugins',
      '--disable-sync',
      '--metrics-recording-only',
      '--mute-audio',
      '--no-default-browser-check',
      '--no-pings',
      '--password-store=basic',
      '--use-mock-keychain',
      '--disable-background-networking',
      '--disable-component-extensions-with-background-pages',
      '--disable-features=TranslateUI,BlinkGenPropertyTrees',
      '--enable-automation',
      '--disable-infobars',
      '--window-size=1280,720',
      '--lang=ar-EG,ar',
      '--user-agent=Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      '--disable-web-security',
      '--disable-features=VizDisplayCompositor',
      '--disable-features=OutOfBlinkCors',
      '--disable-features=IsolateOrigins',
      '--disable-site-isolation-trials',
      '--disable-site-isolation-for-policy',
      '--disable-frame-rate-limit',
      '--disable-field-trial-config',
      '--disable-back-forward-cache',
      '--disable-hang-monitor',
      '--disable-prompt-on-repost',
      '--disable-client-side-phishing-detection',
      '--disable-component-update',
      '--disable-default-apps',
      '--disable-domain-reliability',
      '--disable-features=AudioServiceOutOfProcess',
      '--disable-features=MediaSessionService',
      '--force-color-profile=srgb',
      '--metrics-recording-only',
      '--no-report-upload',
      '--disable-breakpad',
      '--disable-features=RendererCodeIntegrity',
      '--disable-features=SitePerProcess',
      '--disable-features=IsolateOrigins,site-per-process',
      '--remote-debugging-port=9222',
      '--remote-debugging-address=0.0.0.0'
    ],
    executablePath: process.env.CHROME_PATH || '/usr/bin/google-chrome-stable'
  },
  webVersionCache: {
    type: 'remote',
    remotePath: 'https://raw.githubusercontent.com/wppconnect-team/wa-version/main/html/2.2412.54.html'
  }
});

// Track client state
let isReady = false;

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
  console.log(`[BOT] Bot name: ${BOT_NAME}`);
  console.log(`[TIME] Scheduled to run at: ${CRON_SCHEDULE} (${TIMEZONE})`);
  isReady = true;
  
  // Run immediately on startup for testing (optional)
  if (process.env.RUN_ON_START === 'true') {
    console.log('[RUN] RUN_ON_START=true - Running reminders now...');
    await sendRentReminders();
  }
  
  // Schedule the cron job
  scheduleCronJob();
});

client.on('authenticated', () => {
  console.log('[AUTH] Authentication successful!');
});

client.on('auth_failure', (msg) => {
  console.error('[AUTH-ERROR] Authentication failed:', msg);
});

client.on('disconnected', (reason) => {
  console.log('[DISCONNECTED] Client disconnected:', reason);
  isReady = false;
});

client.on('message_ack', (msg, ack) => {
  if (ack < 0) {
    console.warn('[WARN] Message failed (ack: ' + ack + '): ' + msg.id._serialized);
  }
});

// ============================================================
// CORE FUNCTIONS
// ============================================================

/**
 * Send rent reminders to all unpaid tenants who have not received one yet
 */
async function sendRentReminders() {
  if (!isReady) {
    console.log('[WAIT] Bot not ready yet, skipping...');
    return;
  }
  
  console.log('\n[SCAN] Checking for unpaid tenants...');
  const startTime = Date.now();
  
  try {
    // 1. Get all active unpaid tenants
    const { data: tenants, error: tenantsError } = await supabase
      .from('tenants')
      .select('id, name, phone, room_id, building_id, due_date')
      .eq('status', 'active')
      .eq('payment_status', 'unpaid');
    
    if (tenantsError) throw tenantsError;
    
    if (!tenants || tenants.length === 0) {
      console.log('[OK] No unpaid tenants found');
      return;
    }
    
    console.log('[LIST] Found ' + tenants.length + ' unpaid tenant(s)');
    
    // 2. Get room numbers for room_id mapping
    const roomIds = [...new Set(tenants.map(t => t.room_id).filter(Boolean))];
    const { data: rooms, error: roomsError } = await supabase
      .from('rooms')
      .select('id, room_number')
      .in('id', roomIds);
    
    if (roomsError) throw roomsError;
    const roomMap = Object.fromEntries(rooms.map(r => [r.id, r.room_number]));
    
    // 3. Get whatsapp_logs to check who already received a debt_reminder
    const tenantIds = tenants.map(t => t.id);
    const { data: logs, error: logsError } = await supabase
      .from('whatsapp_logs')
      .select('tenant_id')
      .eq('message_type', 'debt_reminder')
      .eq('status', 'sent')
      .in('tenant_id', tenantIds);
    
    if (logsError) throw logsError;
    
    const sentTenantIds = new Set(logs.map(l => l.tenant_id));
    console.log('[LOG] ' + sentTenantIds.size + ' tenant(s) already received a reminder');
    
    // 4. Filter to only those who have not received a reminder
    const tenantsToNotify = tenants.filter(t => !sentTenantIds.has(t.id));
    
    if (tenantsToNotify.length === 0) {
      console.log('[OK] All unpaid tenants have already been notified');
      return;
    }
    
    console.log('[SEND] Sending reminders to ' + tenantsToNotify.length + ' tenant(s)...');
    
    // 5. Send messages
    let sent = 0, failed = 0, skipped = 0;
    
    for (const tenant of tenantsToNotify) {
      if (!tenant.phone || tenant.phone.trim() === '') {
        console.log('[SKIP] Skipping ' + tenant.name + ' - no phone number');
        skipped++;
        continue;
      }
      
      const roomNum = tenant.room_id ? (roomMap[tenant.room_id] || '?') : '?';
      const message = 'عزيزي ' + tenant.name + ' (غرفة ' + roomNum + ')،\n\nهذا تذكير ودي بأن دفعة الإيجار مستحقة. يرجى سداد المبلغ في أقرب وقت ممكن.\n\nشكراً لتعاونكم.\nإدارة السكن';
      
      // Format phone for WhatsApp
      const formattedPhone = formatPhoneForWhatsApp(tenant.phone);
      if (!formattedPhone) {
        console.log('[SKIP] Skipping ' + tenant.name + ' - invalid phone: ' + tenant.phone);
        skipped++;
        continue;
      }
      
      try {
        await client.sendMessage(formattedPhone + '@c.us', message);
        
        // Log success
        await supabase.from('whatsapp_logs').insert({
          tenant_id: tenant.id,
          message_type: 'debt_reminder',
          message_body: message,
          status: 'sent',
          sent_at: new Date().toISOString()
        });
        
        console.log('[OK] Sent to ' + tenant.name + ' (' + formattedPhone + ')');
        sent++;
        
        // Rate limiting - 2 seconds between messages
        await new Promise(r => setTimeout(r, 2000));
        
      } catch (err) {
        console.error('[ERROR] Failed to send to ' + tenant.name + ': ' + err.message);
        
        // Log failure
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
    
    const duration = ((Date.now() - startTime) / 1000).toFixed(1);
    console.log('\n[STATS] Summary: ' + sent + ' sent, ' + failed + ' failed, ' + skipped + ' skipped (' + duration + 's)');
    
  } catch (error) {
    console.error('[ERROR] Error in sendRentReminders:', error.message);
  }
}

/**
 * Format phone number for WhatsApp
 * Input: various formats (012-3456789, +201****6789, 20123456789, etc.)
 * Output: 20XXXXXXXXXX (Egypt country code + number without leading zero)
 */
function formatPhoneForWhatsApp(phone) {
  if (!phone) return null;
  
  // Clean the phone
  let cleaned = phone
    .replace(/[\s\-\(\)]/g, '')  // Remove spaces, dashes, parentheses
    .replace(/^\+/, '');         // Remove leading +
  
  // Handle multiple numbers (take first valid Egyptian mobile)
  const parts = cleaned.split(/[\/\\,;]/);
  
  for (const part of parts) {
    let num = part.trim();
    
    // If starts with 0, replace with 20 (Egypt)
    if (num.startsWith('0')) {
      num = '20' + num.substring(1);
    }
    // If already starts with 20, good
    else if (!num.startsWith('20')) {
      // If it is just 10 digits, assume Egypt
      if (/^1[0125]\d{8}$/.test(num)) {
        num = '20' + num;
      }
    }
    
    // Validate: 20 + 10 digits starting with 10, 11, 12, 15
    if (/^201[0125]\d{8}$/.test(num)) {
      return num;
    }
  }
  
  return null;
}

/**
 * Schedule the cron job
 */
function scheduleCronJob() {
  // Convert schedule to use timezone
  const job = cron.schedule(CRON_SCHEDULE, async () => {
    console.log('\n[CRON] [' + new Date().toLocaleString('en-EG', { timeZone: TIMEZONE }) + '] Running scheduled rent reminders...');
    await sendRentReminders();
  }, {
    scheduled: true,
    timezone: TIMEZONE
  });
  
  console.log('[CRON] Cron job scheduled: ' + CRON_SCHEDULE + ' (' + TIMEZONE + ')');
  return job;
}

// ============================================================
// START THE BOT
// ============================================================

console.log('[START] Starting Hostel Manager WhatsApp Bot...');
console.log('[CONFIG] Timezone: ' + TIMEZONE);
console.log('[CONFIG] Schedule: ' + CRON_SCHEDULE + ' (12 PM Egypt Time)');

client.initialize().catch(err => {
  console.error('[ERROR] Failed to initialize:', err);
  process.exit(1);
});

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('\n[SHUTDOWN] Shutting down...');
  await client.destroy();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  console.log('\n[SHUTDOWN] Shutting down...');
  await client.destroy();
  process.exit(0);
});