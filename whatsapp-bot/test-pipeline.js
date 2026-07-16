// test-pipeline.js - Test full pipeline: make tenant unpaid -> run bot -> verify message sent
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function testPipeline() {
  console.log('[PIPELINE] Starting full pipeline test...\n');

  // 1. Get a tenant with phone number to test
  const { data: tenants, error: tErr } = await supabase
    .from('tenants')
    .select('id, name, phone, room_id, building_id, payment_status, rent_amount, due_date')
    .neq('phone', '')
    .neq('phone', null)
    .limit(5);

  if (tErr) throw tErr;

  if (!tenants || tenants.length === 0) {
    console.log('[PIPELINE] No tenants with phone found');
    return;
  }

  // Pick first tenant with valid Egyptian phone
  const testTenant = tenants.find(t => {
    const phone = t.phone.replace(/[\s\-\(\)]/g, '').replace(/^\+/, '');
    const formatted = phone.startsWith('0') ? '20' + phone.substring(1) : phone;
    return /^201[0125]\d{8}$/.test(formatted);
  });

  if (!testTenant) {
    console.log('[PIPELINE] No tenant with valid Egyptian phone');
    return;
  }

  console.log('[PIPELINE] Test tenant:', testTenant.name, testTenant.phone, 'Room:', testTenant.room_id, 'Amount:', testTenant.rent_amount);

  // 2. Get room number
  let roomNumber = '?';
  if (testTenant.room_id) {
    const { data: room } = await supabase.from('rooms').select('room_number').eq('id', testTenant.room_id).single();
    roomNumber = room?.room_number || '?';
  }

  // 3. Make tenant unpaid (if not already)
  if (testTenant.payment_status !== 'unpaid') {
    console.log('[PIPELINE] Setting tenant to unpaid...');
    const { error: upErr } = await supabase
      .from('tenants')
      .update({ payment_status: 'unpaid' })
      .eq('id', testTenant.id);
    if (upErr) throw upErr;
    console.log('[PIPELINE] Tenant set to unpaid');
  } else {
    console.log('[PIPELINE] Tenant already unpaid');
  }

  // 4. Clear any existing whatsapp_logs for this billing period
  const now = new Date();
  const billingPeriodKey = now.getFullYear() + '-' + String(now.getMonth() + 1).padStart(2, '0');
  
  console.log('[PIPELINE] Clearing previous logs for billing period:', billingPeriodKey);
  await supabase
    .from('whatsapp_logs')
    .delete()
    .eq('tenant_id', testTenant.id)
    .eq('message_type', 'debt_reminder');

  // 5. Run the actual sendRentReminders logic
  console.log('[PIPELINE] Running sendRentReminders logic...');
  
  const { data: tenants2, error: tErr2 } = await supabase
    .from('tenants')
    .select('id, name, phone, room_id, building_id, due_date, rent_amount')
    .eq('status', 'active')
    .eq('payment_status', 'unpaid');

  if (tErr2) throw tErr2;

  if (!tenants2 || tenants2.length === 0) {
    console.log('[PIPELINE] No unpaid tenants');
    return;
  }

  console.log('[PIPELINE] Found', tenants2.length, 'unpaid tenant(s)');

  // Get room numbers
  const roomIds = [...new Set(tenants2.map(t => t.room_id).filter(Boolean))];
  const { data: rooms } = await supabase.from('rooms').select('id, room_number').in('id', roomIds);
  const roomMap = Object.fromEntries(rooms.map(r => [r.id, r.room_number]));

  // Check logs for current billing period
  const tenantIds = tenants2.map(t => t.id);
  const { data: logs } = await supabase
    .from('whatsapp_logs')
    .select('tenant_id, metadata')
    .eq('message_type', 'debt_reminder')
    .eq('status', 'sent')
    .in('tenant_id', tenantIds);

  const sentThisPeriod = new Set();
  for (const log of logs) {
    try {
      const meta = typeof log.metadata === 'string' ? JSON.parse(log.metadata) : log.metadata;
      if (meta && meta.billing_period_key === billingPeriodKey) {
        sentThisPeriod.add(log.tenant_id);
      }
    } catch (e) {}
  }

  console.log('[PIPELINE] Already sent this period:', sentThisPeriod.size);

  const tenantsToNotify = tenants2.filter(t => !sentThisPeriod.has(t.id));
  if (tenantsToNotify.length === 0) {
    console.log('[PIPELINE] All already notified for this billing period');
    return;
  }

  // Find our test tenant in the list
  const ourTenant = tenantsToNotify.find(t => t.id === testTenant.id);
  if (!ourTenant) {
    console.log('[PIPELINE] Our test tenant already notified, picking first unpaid');
    // Pick first
    if (tenantsToNotify.length > 0) {
      await sendTestMessage(tenantsToNotify[0], roomMap, billingPeriodKey);
    }
    return;
  }

  await sendTestMessage(ourTenant, roomMap, billingPeriodKey);
}

async function sendTestMessage(tenant, roomMap, billingPeriodKey) {
  console.log('\n[PIPELINE] Sending to:', tenant.name, '| Phone:', tenant.phone, '| Room:', tenant.room_id);
  
  if (!tenant.phone || tenant.phone.trim() === '') {
    console.log('[PIPELINE] No phone');
    return;
  }

  const roomNum = tenant.room_id ? (roomMap[tenant.room_id] || '?') : '?';
  const amount = tenant.rent_amount || 0;
  
  // Build message (same as index.js)
  const billingPeriodLabel = getBillingPeriod();
  const todayStr = formatDate();
  const message = buildMessage(tenant, roomNum, amount, billingPeriodLabel, todayStr);

  console.log('[PIPELINE] Message preview:');
  console.log(message.substring(0, 200) + '...');

  let formattedPhone = tenant.phone.replace(/[\s\-\(\)]/g, '').replace(/^\+/, '');
  if (formattedPhone.startsWith('0')) formattedPhone = '20' + formattedPhone.substring(1);

  if (!/^201[0125]\d{8}$/.test(formattedPhone)) {
    console.log('[PIPELINE] Invalid phone:', tenant.phone);
    return;
  }

  // Initialize WhatsApp client for this test
  const { Client, LocalAuth } = require('whatsapp-web.js');
  const testClient = new Client({
    authStrategy: new LocalAuth({
      clientId: 'HostelManagerBot_test',
      dataPath: './.wwebjs_auth_test'
    }),
    puppeteer: {
      headless: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage', '--disable-gpu', '--no-zygote', '--disable-web-security', '--disable-site-isolation-trials', '--remote-debugging-port=9225'],
      executablePath: process.env.CHROME_PATH || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe'
    },
    webVersionCache: { type: 'remote', remotePath: 'https://raw.githubusercontent.com/wppconnect-team/wa-version/main/html/2.2412.54.html' },
    authTimeoutMs: 180000,
    qrTimeoutMs: 120000,
    restartOnAuthFail: true
  });

  return new Promise((resolve, reject) => {
    let resolved = false;
    
    testClient.on('qr', (qr) => {
      console.log('\n[PIPELINE] Scan QR code:');
      require('qrcode-terminal').generate(qr, { small: true });
    });

    testClient.on('ready', async () => {
      console.log('[PIPELINE] Bot ready, sending message...');
      
      try {
        await testClient.sendMessage(formattedPhone + '@c.us', message);
        console.log('[PIPELINE] ✅ Message sent to', tenant.name, '(' + formattedPhone + ')');
        
        // Log to database
        await supabase.from('whatsapp_logs').insert({
          tenant_id: tenant.id,
          message_type: 'debt_reminder',
          message_body: message,
          status: 'sent',
          sent_at: new Date().toISOString(),
          metadata: {
            billing_period_key: billingPeriodKey,
            billing_period_label: getBillingPeriod(),
            amount: amount,
            room_number: roomNum
          }
        });
        
        console.log('[PIPELINE] Logged to whatsapp_logs');
        
        // Verify by fetching back
        const { data: verify } = await supabase
          .from('whatsapp_logs')
          .select('*')
          .eq('tenant_id', tenant.id)
          .eq('message_type', 'debt_reminder')
          .eq('status', 'sent')
          .order('sent_at', { ascending: false })
          .limit(1);
        
        if (verify && verify.length > 0) {
          console.log('[PIPELINE] Verified in DB:', verify[0].metadata);
        }
        
        await testClient.destroy();
        resolved = true;
        resolve();
      } catch (err) {
        console.error('[PIPELINE] ❌ Failed:', err.message);
        await testClient.destroy();
        resolved = true;
        reject(err);
      }
    });

    testClient.on('auth_failure', (msg) => {
      console.error('[PIPELINE] Auth failed:', msg);
      if (!resolved) { resolved = true; reject(new Error(msg)); }
    });

    testClient.on('disconnected', (reason) => {
      console.log('[PIPELINE] Disconnected:', reason);
    });

    testClient.initialize().catch(err => {
      console.error('[PIPELINE] Init error:', err.message);
      if (!resolved) { resolved = true; reject(err); }
    });

    setTimeout(() => {
      if (!resolved) { resolved = true; reject(new Error('Timeout')); }
    }, 180000);
  });
}

// Helper functions (copied from index.js)
function getBillingPeriod() {
  const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  const now = new Date();
  return months[now.getMonth()] + ' ' + now.getFullYear();
}

function formatDate(date = new Date()) {
  return date.toLocaleDateString('en-GB', { timeZone: 'Africa/Cairo', day: '2-digit', month: '2-digit', year: 'numeric' });
}

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

// Run test
testPipeline().then(() => {
  console.log('\n[PIPELINE] Done');
  process.exit(0);
}).catch(err => {
  console.error('[PIPELINE] Error:', err.message);
  process.exit(1);
});