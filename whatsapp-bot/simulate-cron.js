// simulate-cron.js - Simulate 12 PM cron run
require('dotenv').config();
const { Client, LocalAuth } = require('whatsapp-web.js');
const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const BOT_NAME = process.env.BOT_NAME || 'HostelManagerBot';

const client = new Client({
  authStrategy: new LocalAuth({
    clientId: BOT_NAME + '_sim',
    dataPath: './.wwebjs_auth_sim'
  }),
  puppeteer: {
    headless: true,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-gpu',
      '--no-zygote',
      '--single-process',
      '--disable-web-security',
      '--disable-site-isolation-trials',
      '--disable-features=IsolateOrigins,site-per-process',
      '--remote-debugging-port=9224',
      '--remote-debugging-address=0.0.0.0',
    ],
    executablePath: process.env.CHROME_PATH || '/usr/bin/google-chrome-stable',
  },
  webVersionCache: {
    type: 'remote',
    remotePath: 'https://raw.githubusercontent.com/wppconnect-team/wa-version/main/html/2.2412.54.html'
  },
});

async function runReminders() {
  console.log('\n[SIM] Running simulated 12 PM rent reminders...');
  
  // 1. Get unpaid tenants
  const { data: tenants, error: tenantsError } = await supabase
    .from('tenants')
    .select('id, name, phone, room_id, building_id, due_date')
    .eq('status', 'active')
    .eq('payment_status', 'unpaid');

  if (tenantsError) throw tenantsError;

  if (!tenants || tenants.length === 0) {
    console.log('[SIM] No unpaid tenants found');
    return;
  }

  console.log('[SIM] Found ' + tenants.length + ' unpaid tenant(s)');

  // 2. Get room numbers
  const roomIds = [...new Set(tenants.map(t => t.room_id).filter(Boolean))];
  const { data: rooms, error: roomsError } = await supabase
    .from('rooms')
    .select('id, room_number')
    .in('id', roomIds);

  if (roomsError) throw roomsError;
  const roomMap = Object.fromEntries(rooms.map(r => [r.id, r.room_number]));

  // 3. Get already sent logs
  const tenantIds = tenants.map(t => t.id);
  const { data: logs, error: logsError } = await supabase
    .from('whatsapp_logs')
    .select('tenant_id')
    .eq('message_type', 'debt_reminder')
    .eq('status', 'sent')
    .in('tenant_id', tenantIds);

  if (logsError) throw logsError;

  const sentTenantIds = new Set(logs.map(l => l.tenant_id));
  console.log('[SIM] ' + sentTenantIds.size + ' already received reminder');

  const tenantsToNotify = tenants.filter(t => !sentTenantIds.has(t.id));

  if (tenantsToNotify.length === 0) {
    console.log('[SIM] All unpaid tenants already notified');
    return;
  }

  console.log('[SIM] Sending to ' + tenantsToNotify.length + ' tenant(s)...');

  // 4. Send messages
  let sent = 0, failed = 0, skipped = 0;

  for (const tenant of tenantsToNotify) {
    if (!tenant.phone || tenant.phone.trim() === '') {
      console.log('[SKIP] ' + tenant.name + ' - no phone');
      skipped++;
      continue;
    }

    const roomNum = tenant.room_id ? (roomMap[tenant.room_id] || '?') : '?';
    const message = 'عزيزي ' + tenant.name + ' (غرفة ' + roomNum + ')،\n\nهذا تذكير ودي بأن دفعة الإيجار مستحقة. يرجى سداد المبلغ في أقرب وقت ممكن.\n\nشكراً لتعاونكم.\nإدارة السكن';

    // Format phone
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

  console.log('\n[SIM] Summary: ' + sent + ' sent, ' + failed + ' failed, ' + skipped + ' skipped');
}

client.on('ready', async () => {
  console.log('\n[SIM] Bot ready! Running simulation...');
  await runReminders();
  await client.destroy();
  process.exit(0);
});

client.on('auth_failure', (msg) => {
  console.error('[SIM] Auth failed:', msg);
  process.exit(1);
});

client.on('qr', (qr) => {
  console.log('\n[SIM] Scan QR code:');
  require('qrcode-terminal').generate(qr, { small: true });
});

client.initialize().catch(err => {
  console.error('[SIM] Init error:', err);
  process.exit(1);
});

console.log('[SIM] Starting simulation...');