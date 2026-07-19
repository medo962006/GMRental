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
      '--disable-web-security',
      '--disable-site-isolation-trials',
      '--remote-debugging-port=9223',
    ],
    executablePath: process.env.CHROME_PATH || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  },
  webVersionCache: {
    type: 'remote',
    remotePath: 'https://raw.githubusercontent.com/wppconnect-team/wa-version/main/html/2.2412.54.html'
  },
  authTimeoutMs: 180000,
  qrTimeoutMs: 120000,
  restartOnAuthFail: true,
});

client.on('qr', (qr) => {
  console.log('\n[TEST] Scan QR code:');
  qrcode.generate(qr, { small: true });
});

client.on('ready', async () => {
  console.log('\n[TEST] Bot ready! Sending test message...');
  
  const testNumber = '201015326547'; // 01015326547 -> 201015326547
  const message = '🧪 Test message from Hostel Bot!\n\nإذا وصلت هذه الرسالة، فالбот يعمل بشكل صحيح.\n\nTime: ' + new Date().toLocaleString('ar-EG', { timeZone: 'Africa/Cairo' });
  
  try {
    // First check if number is registered on WhatsApp
    const isRegistered = await client.isRegisteredUser(testNumber + '@c.us');
    console.log('[TEST] Number registered on WhatsApp:', isRegistered);
    
    if (!isRegistered) {
      console.log('[TEST] ❌ Number NOT registered on WhatsApp');
      await client.destroy();
      process.exit(1);
    }
    
    // Get contact info
    const contact = await client.getContactById(testNumber + '@c.us');
    console.log('[TEST] Contact found:', contact.pushname || 'No name', contact.number);
    console.log('[TEST] Contact ID:', contact.id._serialized);
    console.log('[TEST] Is user:', contact.isUser);
    console.log('[TEST] Is group:', contact.isGroup);
    console.log('[TEST] Is WA contact:', contact.isWAContact);
    
    // Check if chat exists
    const chat = await client.getChatById(testNumber + '@c.us');
    console.log('[TEST] Chat found:', chat.name);
    console.log('[TEST] Chat ID:', chat.id._serialized);
    console.log('[TEST] Unread count:', chat.unreadCount);
    
    // Send message and capture result
    console.log('[TEST] Sending message...');
    const sentMsg = await client.sendMessage(testNumber + '@c.us', message);
    console.log('[TEST] ✅ sendMessage returned');
    
    if (sentMsg) {
      console.log('[TEST] Message object:', JSON.stringify({
        id: sentMsg.id?._serialized,
        body: sentMsg.body,
        from: sentMsg.from,
        to: sentMsg.to,
        timestamp: sentMsg.timestamp,
        type: sentMsg.type,
        ack: sentMsg.ack,
        hasMedia: sentMsg.hasMedia
      }, null, 2));
    } else {
      console.log('[TEST] Message sent but no return object (version difference)');
    }
    
    // Wait a bit then check message status
    console.log('[TEST] Waiting 5 seconds for delivery...');
    await new Promise(r => setTimeout(r, 5000));
    
    // Try to get the message back
    if (sentMsg && sentMsg.id) {
      const messages = await chat.fetchMessages({ limit: 5 });
      console.log('[TEST] Recent messages in chat:');
      for (const msg of messages) {
        console.log('[TEST]  -', msg.id._serialized, '|', msg.fromMe ? 'OUT' : 'IN', '|', msg.body?.substring(0, 50));
      }
    } else {
      // Try fetching messages anyway
      try {
        const messages = await chat.fetchMessages({ limit: 5 });
        console.log('[TEST] Recent messages in chat (fallback):');
        for (const msg of messages) {
          console.log('[TEST]  -', msg.id._serialized, '|', msg.fromMe ? 'OUT' : 'IN', '|', msg.body?.substring(0, 50));
        }
      } catch (e) {
        console.error('[TEST] fetchMessages error:', e.message);
      }
    }
    
  } catch (err) {
    console.error('[TEST] ❌ Failed to send:', err.message);
    console.error('[TEST] Stack:', err.stack);
  }
  
  await client.destroy();
  process.exit(0);
});

client.on('auth_failure', (msg) => {
  console.error('[TEST] Auth failed:', msg);
  process.exit(1);
});

client.on('disconnected', (reason) => {
  console.log('[TEST] Disconnected:', reason);
});

client.on('loading_screen', (percent, message) => {
  console.log('[TEST] Loading:', Math.round(percent) + '% - ' + message);
});

// Add delay before initialization to let Chrome stabilize
console.log('[TEST] Waiting 30 seconds for Chrome to fully stabilize...');
setTimeout(() => {
  console.log('[TEST] Starting initialization...');
  client.initialize().catch(err => {
    console.error('[TEST] Init error:', err);
    process.exit(1);
  });
}, 30000);

console.log('[TEST] Starting test client...');