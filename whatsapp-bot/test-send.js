// test-send.js - Send test WhatsApp message
require('dotenv').config();
const { Client, LocalAuth } = require('whatsapp-web.js');
const qrcode = require('qrcode-terminal');
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
    clientId: BOT_NAME + '_test',
    dataPath: './.wwebjs_auth_test'
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
      '--remote-debugging-port=9223',
      '--remote-debugging-address=0.0.0.0',
    ],
    executablePath: process.env.CHROME_PATH || '/usr/bin/google-chrome-stable',
  },
  webVersionCache: {
    type: 'remote',
    remotePath: 'https://raw.githubusercontent.com/wppconnect-team/wa-version/main/html/2.2412.54.html'
  },
  authTimeoutMs: 120000,
  qrTimeoutMs: 60000,
  restartOnAuthFail: true,
});

client.on('qr', (qr) => {
  console.log('\n[TEST] Scan QR code:');
  qrcode.generate(qr, { small: true });
});

client.on('ready', async () => {
  console.log('\n[TEST] Bot ready! Sending test message...');
  
  const testNumber = '201015326547'; // 01015326547 -> 201015326547
  const message = '🧪 Test message from Hostel Bot!\n\nإذا وصلتك هذه الرسالة، فالбот يعمل بشكل صحيح.\n\nTime: ' + new Date().toLocaleString('ar-EG', { timeZone: 'Africa/Cairo' });
  
  try {
    await client.sendMessage(testNumber + '@c.us', message);
    console.log('[TEST] ✅ Test message sent successfully to ' + testNumber);
  } catch (err) {
    console.error('[TEST] ❌ Failed to send:', err.message);
  }
  
  await client.destroy();
  process.exit(0);
});

client.on('auth_failure', (msg) => {
  console.error('[TEST] Auth failed:', msg);
  process.exit(1);
});

client.initialize().catch(err => {
  console.error('[TEST] Init error:', err);
  process.exit(1);
});

console.log('[TEST] Starting test client...');