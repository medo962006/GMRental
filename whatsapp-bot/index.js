// index.js - WhatsApp Bot for Hostel Rent Reminders
require('dotenv').config();
const { Client, LocalAuth } = require('whatsapp-web.js');
const qrcode = require('qrcode-terminal');
const { createClient } = require('@supabase/supabase-js');
const cron = require('node-cron');

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
// HELPER: Get current billing period (e.g., "October 2025")
// ============================================================
function getBillingPeriod(date = new Date()) {
  const months = ['January', 'February', 'March', 'April', 'May', 'June', 
                  'July', 'August', 'September', 'October', 'November', 'December'];
  return months[date.getMonth()] + ' ' + date.getFullYear();
}

function formatDate(date = new Date()) {
  return date.toLocaleDateString('en-GB', { timeZone: TIMEZONE, day: '2-digit', month: '2-digit', year: 'numeric' });
}

// ============================================================
// BILINGUAL MESSAGE TEMPLATE
// ============================================================
function buildMessage(tenant, roomNumber, amount, billingPeriod, todayStr) {
  const currencySymbol = 'LE ';
  const bankName = 'Ahmed\'s Hostel Bank';
  const accountNumber = '1234567890';

  const arMessage = 
    'مرحبًا ! 👋\n\n' +
    'تذكير تلقائي سريع بأن إيجار شهر ' + billingPeriod + ' مستحق اليوم (' + todayStr + ').\n\n' +
    '📌 تفاصيل الدفع:\n\n' +
    'المبلغ المستحق: ' + currencySymbol + amount + '\n\n' +
    'الغرفة/السرير: ' + roomNumber + '\n\n' +
    '💳 طريقة الدفع:\n' +
    'يمكنك الدفع بسهولة عبر التحويل إلى ' + bankName + ' (حساب رقم: ' + accountNumber + ') أو تفضل بزيارة مكتب الاستقبال.\n\n' +
    'ملاحظة: إذا قمت بالتحويل اليوم بالفعل، يرجى الرد على هذه الرسالة بإرسال صورة من الإيصال لتحديث حسابك. شكراً لك!';

  const enMessage = 
    'Hey 👋!\n\n' +
    'This is a quick, automated reminder that your rent for ' + billingPeriod + ' is due today (' + todayStr + ').\n\n' +
    '📌 Payment Details:\n\n' +
    'Amount Due: ' + currencySymbol + amount + '\n\n' +
    'Room/Bed: ' + roomNumber + '\n\n' +
    '💳 How to pay:\n' +
    'You can make a quick transfer to ' + bankName + ' (Account: ' + accountNumber + ') or stop by the front desk.\n\n' +
    'Note: If you have already made the transfer today, please reply to this message with a screenshot of your receipt so we can update your account. If you need any assistance, just let us know!\n\n' +
    'Thank you, and have a great day! 😊';

  return arMessage + '\n\n---\n\n' + enMessage;
}

// ============================================================
// MESSAGE SENDING WITH PAYMENT CYCLE DEDUPLICATION
// ============================================================
async function sendRentReminders() {
  console.log('\n[SEND] Running reminders for billing period: ' + getBillingPeriod());

  // Get current billing period key (e.g., "2025-10")
  const now = new Date();
  const billingPeriodKey = now.getFullYear() + '-' + String(now.getMonth() + 1).padStart(2, '0');
  const billingPeriodLabel = getBillingPeriod(now);
  const todayStr = formatDate(now);

  // 1. Get unpaid tenants
  const { data: tenants, error: tenantsError } = await supabase
    .from('tenants')
    .select('id, name, phone, room_id, building_id, due_date, rent_amount')
    .eq('status', 'active')
    .eq('payment_status', 'unpaid');

  if (tenantsError) throw tenantsError;
  if (!tenants || tenants.length === 0) {
    console.log('[SEND] No unpaid tenants found');
    return;
  }

  console.log('[SEND] Found ' + tenants.length + ' unpaid tenant(s)');

  // 2. Get room numbers
  const roomIds = [...new Set(tenants.map(t => t.room_id).filter(Boolean))];
  const { data: rooms, error: roomsError } = await supabase
    .from('rooms')
    .select('id, room_number')
    .in('id', roomIds);

  if (roomsError) throw roomsError;
  const roomMap = Object.fromEntries(rooms.map(r => [r.id, r.room_number]));

  // 3. Check DEDUPLICATION: already sent for THIS billing period
  const tenantIds = tenants.map(t => t.id);
  const { data: logs, error: logsError } = await supabase
    .from('whatsapp_logs')
    .select('tenant_id, metadata')
    .eq('message_type', 'debt_reminder')
    .eq('status', 'sent')
    .in('tenant_id', tenantIds);

  if (logsError) throw logsError;

  // Filter logs for current billing period
  const sentThisPeriod = new Set();
  for (const log of logs) {
    try {
      const meta = typeof log.metadata === 'string' ? JSON.parse(log.metadata) : log.metadata;
      if (meta && meta.billing_period_key === billingPeriodKey) {
        sentThisPeriod.add(log.tenant_id);
      }
    } catch (e) {
      // ignore malformed metadata
    }
  }
  console.log('[SEND] ' + sentThisPeriod.size + ' already received reminder for ' + billingPeriodLabel);

  const tenantsToNotify = tenants.filter(t => !sentThisPeriod.has(t.id));
  if (tenantsToNotify.length === 0) {
    console.log('[SEND] All unpaid tenants already notified for ' + billingPeriodLabel);
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
    const amount = tenant.rent_amount || 0;
    const message = buildMessage(tenant, roomNum, amount, billingPeriodLabel, formatDate());

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
        sent_at: new Date().toISOString(),
        metadata: {
          billing_period_key: billingPeriodKey,
          billing_period_label: billingPeriodLabel,
          amount: amount,
          room_number: roomNum
        }
      });
      console.log('[OK] Sent to ' + tenant.name + ' (' + formattedPhone + ') | Room: ' + roomNum + ' | Amount: ' + currencySymbol + amount);
      sent++;
      await new Promise(r => setTimeout(r, 2000));
    } catch (err) {
      console.error('[ERROR] Failed to send to ' + tenant.name + ': ' + err.message);
      await supabase.from('whatsapp_logs').insert({
        tenant_id: tenant.id,
        message_type: 'debt_reminder',
        message_body: message,
        status: 'failed',
        sent_at: new Date().toISOString(),
        metadata: {
          billing_period_key: billingPeriodKey,
          error: err.message
        }
      });
      failed++;
    }
  }

  console.log('\n[SEND] Summary: ' + sent + ' sent, ' + failed + ' failed, ' + skipped + ' skipped');
}

// ============================================================
// CRON SCHEDULING with CATCH-UP
// ============================================================
let cronJob = null;

function startCron() {
  console.log('\n[CRON] Scheduling daily at ' + CRON_SCHEDULE + ' (' + TIMEZONE + ')');
  
  // Schedule with timezone
  cronJob = cron.schedule(CRON_SCHEDULE, async () => {
    console.log('\n[CRON] Triggered at ' + new Date().toLocaleString('en-US', { timeZone: TIMEZONE }));
    await sendRentReminders();
  }, {
    scheduled: true,
    timezone: TIMEZONE
  });
  
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

  // CATCH-UP LOGIC: If RUN_ON_START or if we missed today's run, run now
  if (RUN_ON_START) {
    console.log('[RUN] RUN_ON_START=true - Running reminders now...');
    await sendRentReminders();
  } else {
    // Check if we already ran today
    const today = new Date().toLocaleDateString('en-CA', { timeZone: TIMEZONE }); // YYYY-MM-DD
    const { data: todayLogs } = await supabase
      .from('whatsapp_logs')
      .select('id')
      .eq('message_type', 'debt_reminder')
      .eq('status', 'sent')
      .gte('sent_at', today + 'T00:00:00')
      .lte('sent_at', today + 'T23:59:59')
      .limit(1);
    
    if (!todayLogs || todayLogs.length === 0) {
      console.log('[CATCH-UP] No reminders sent today - running catch-up...');
      await sendRentReminders();
    } else {
      console.log('[CATCH-UP] Already ran today - skipping');
    }
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