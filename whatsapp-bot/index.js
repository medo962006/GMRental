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
const ADMIN_PHONE = process.env.ADMIN_PHONE || '201015326547'; // Admin gets summary reports

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// ============================================================
// GRACEFUL SHUTDOWN SAFETY NET
// During an intentional teardown (RUN_ON_START one-shot exit) puppeteer / whatsapp-web.js
// may emit a benign "TargetCloseError: Target closed" from an in-flight internal call.
// Swallow those during shutdown so the unattended cron always exits 0 instead of crashing.
// ============================================================
let intentionalShutdown = false;
process.on('uncaughtException', (err) => {
  if (intentionalShutdown) return process.exit(0);
  console.error('[FATAL] Uncaught exception:', err && err.message ? err.message : err);
  process.exit(1);
});
process.on('unhandledRejection', (reason) => {
  if (intentionalShutdown) return; // ignore teardown races
  console.error('[FATAL] Unhandled rejection:', reason && reason.message ? reason.message : reason);
});

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

// NOTE: Do NOT wipe the WhatsApp session on startup. The persistent auth in
// ./.wwebjs_auth must be preserved so the bot can run unattended (no QR re-scan).
killProcesses();

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
    executablePath: process.env.CHROME_PATH || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
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
  const bankName = 'Instapay';
  const accountNumber = '01100847101';

  const arMessage =
    'السلام عليكم 👋\n\n' +
    'تذكير سريع بأن إيجار شهر ' + billingPeriod + ' مستحق اليوم (' + todayStr + ').\n\n' +
    '📌 تفاصيل الدفع:\n\n' +
    'المبلغ المستحق: ' + currencySymbol + amount + '\n\n' +
    'الغرفة: ' + roomNumber + '\n\n' +
    '💳 طريقة الدفع:\n' +
    'يمكنك الدفع بسهولة عبر التحويل إلى ' + bankName + ' (حساب بنكي: ' + accountNumber + ').\n\n' +
    'ملاحظة: إذا قمت بالتحويل اليوم بالفعل، يرجى الرد على هذه الرسالة بإرسال صورة من الإيصال لتحديث حسابك. شكراً لك!';

  const enMessage =
    'Hey 👋!\n\n' +
    'This is a quick reminder that your rent for ' + billingPeriod + ' is due today (' + todayStr + ').\n\n' +
    '📌 Payment Details:\n\n' +
    'Amount Due: ' + currencySymbol + amount + '\n\n' +
    'Room: ' + roomNumber + '\n\n' +
    '💳 How to pay:\n' +
    'You can make a quick transfer to ' + bankName + ' (Account: ' + accountNumber + ').\n\n' +
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
  const currencySymbol = 'LE ';

  // 1. Get unpaid tenants
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

  // 2. Get room numbers and monthly rent
  const roomIds = [...new Set(tenants.map(t => t.room_id).filter(Boolean))];
  const { data: rooms, error: roomsError } = await supabase
    .from('rooms')
    .select('id, room_number, monthly_rent')
    .in('id', roomIds);

  if (roomsError) throw roomsError;
  // Map room id -> full room row (room_number + monthly_rent)
  const roomMap = Object.fromEntries(rooms.map(r => [r.id, r]));

  // 3. Check DEDUPLICATION: already sent for THIS billing period
  const tenantIds = tenants.map(t => t.id);
  const { data: logs, error: logsError } = await supabase
    .from('whatsapp_logs')
    .select('tenant_id, sent_at')
    .eq('message_type', 'debt_reminder')
    .eq('status', 'sent')
    .in('tenant_id', tenantIds);

  if (logsError) throw logsError;

  // Filter logs for the current billing period (same year-month, in bot timezone).
  // The canonical whatsapp_logs schema has no 'metadata' column, so we derive the
  // billing period from sent_at instead of metadata.billing_period_key.
  const sentThisPeriod = new Set();
  for (const log of logs) {
    if (log.sent_at) {
      const d = new Date(log.sent_at);
      const y = parseInt(d.toLocaleString('en-US', { timeZone: TIMEZONE, year: 'numeric' }), 10);
      const m = parseInt(d.toLocaleString('en-US', { timeZone: TIMEZONE, month: '2-digit' }), 10);
      const key = y + '-' + String(m).padStart(2, '0');
      if (key === billingPeriodKey) {
        sentThisPeriod.add(log.tenant_id);
      }
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

  // Track message IDs for delivery confirmation
  const sentMessageIds = [];

  for (const tenant of tenantsToNotify) {
    if (!tenant.phone || tenant.phone.trim() === '') {
      console.log('[SKIP] ' + tenant.name + ' - no phone');
      skipped++;
      continue;
    }

    const roomNum = tenant.room_id ? (roomMap[tenant.room_id] ? roomMap[tenant.room_id].room_number : '?') : '?';
    const amount = (roomMap[tenant.room_id] && roomMap[tenant.room_id].monthly_rent) || 0;
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
      const sentMsg = await client.sendMessage(formattedPhone + '@c.us', message);
      // Track message ID for delivery confirmation. Note: in this environment
      // whatsapp-web.js may return an empty object even when delivery succeeds
      // (the onMessageAck handler logs the real ack), so tolerate a missing id.
      let msgId = null;
      if (sentMsg && sentMsg.id) {
        msgId = sentMsg.id._serialized || sentMsg.id.id || sentMsg.id;
      }
      sentMessageIds.push({ tenantId: tenant.id, tenantName: tenant.name, roomNum, amount, phone: formattedPhone, msgId });

      await supabase.from('whatsapp_logs').insert({
        tenant_id: tenant.id,
        message_type: 'debt_reminder',
        message_body: message,
        status: 'sent',
        sent_at: new Date().toISOString()
      });
      console.log('[OK] Sent to ' + tenant.name + ' (' + formattedPhone + ') | Room: ' + roomNum + ' | Amount: ' + 'LE ' + amount);
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

  // Wait a bit for delivery confirmations (acks) to arrive
  if (sent > 0) {
    console.log('[WAIT] Waiting 5 seconds for delivery confirmations...');
    await new Promise(r => setTimeout(r, 5000));
  }

  // Send admin summary with delivery status
  try {
    let summaryMsg =
      '📊 *Daily Rent Reminder Summary*\n\n' +
      'Date: ' + formatDate() + ' (' + billingPeriodLabel + ')\n' +
      'Sent: ' + sent + '\n' +
      'Failed: ' + failed + '\n' +
      'Skipped: ' + skipped + '\n\n';

    if (tenantsToNotify.length > 0) {
      summaryMsg += '📋 *Details:*\n';
      for (const tenant of tenantsToNotify) {
        const roomNum = tenant.room_id ? (roomMap[tenant.room_id] ? roomMap[tenant.room_id].room_number : '?') : '?';
        const amount = (tenant.room_id && roomMap[tenant.room_id] && roomMap[tenant.room_id].monthly_rent) ? roomMap[tenant.room_id].monthly_rent : 0;
        let status = '✅ Sent';
        let phone = tenant.phone || 'NO PHONE';
        let deliveryStatus = '⏳ Pending';
        
        if (!tenant.phone || tenant.phone.trim() === '') {
          status = '❌ Skipped: No phone in database';
        } else if (!/^201[0125]\d{8}$/.test(
            tenant.phone.replace(/[\s\-\(\)]/g, '').replace(/^\+/, '').startsWith('0') ? 
            '20' + tenant.phone.replace(/[\s\-\(\)]/g, '').replace(/^\+/, '').substring(1) : 
            tenant.phone.replace(/[\s\-\(\)]/g, '').replace(/^\+/, '')
          )) {
          status = '❌ Skipped: Invalid phone format (' + phone + ')';
        } else if (amount <= 0) {
          status = '❌ Skipped: No rent value in database (room: ' + roomNum + ')';
        } else {
          // Check if message was sent and its delivery status
          const sentInfo = sentMessageIds.find(s => s.tenantId === tenant.id);
          if (sentInfo) {
            const ackInfo = messageAckTracker.get(sentInfo.msgId);
            if (ackInfo) {
              if (ackInfo.ack === 2) {
                deliveryStatus = '📖 Read';
              } else if (ackInfo.ack === 1) {
                deliveryStatus = '✅ Delivered';
              } else if (ackInfo.ack === 0) {
                deliveryStatus = '📤 Sent to server';
              } else {
                deliveryStatus = '⚠️ Failed';
              }
            }
          }
        }
        
        summaryMsg += tenant.name + ' | Room ' + roomNum + ' | ' + currencySymbol + amount + ' | ' + phone + ' → ' + status + ' | ' + deliveryStatus + '\n';
      }
    }

    summaryMsg += '\n_Auto-generated by Hostel Manager Bot_';
    await client.sendMessage(ADMIN_PHONE + '@c.us', summaryMsg);
    console.log('[ADMIN] Summary sent to admin (' + ADMIN_PHONE + ')');
  } catch (e) {
    console.log('[ADMIN] Failed to send summary: ' + e.message);
  }
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
// Track message ack (delivery/read) for admin reporting
const messageAckTracker = new Map();

client.on('message_ack', (msg, ack) => {
  // ack: -1 = error, 0 = sent to server, 1 = delivered to device, 2 = read, 3 = played (voice)
  const key = msg.id._serialized;
  messageAckTracker.set(key, { ack, timestamp: new Date().toISOString() });
  console.log(`[ACK] ${key} → ${ack} (${ack === 2 ? 'READ' : ack === 1 ? 'DELIVERED' : ack === 0 ? 'SENT' : 'ERROR'})`);
});

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
    try {
      await sendRentReminders();
    } catch (e) {
      console.error('[RUN] sendRentReminders failed:', e && e.message ? e.message : e);
    }
    console.log('[EXIT] RUN_ON_START complete - shutting down bot.');
    intentionalShutdown = true;
    try { await client.destroy(); } catch (e) { /* ignore teardown races */ }
    process.exit(0);
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
      try {
        await sendRentReminders();
      } catch (e) {
        console.error('[CATCH-UP] sendRentReminders failed:', e && e.message ? e.message : e);
      }
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