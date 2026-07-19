// get-key.js - Prompt for service role key and write .env
const fs = require('fs');
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

console.log('Enter your FULL Supabase service_role key (from Dashboard > Settings > API):\n');

rl.question('Service Role Key: ', (key) => {
  key = key.trim();
  if (!key || key.length < 50) {
    console.error('Key too short. Must be full JWT.');
    process.exit(1);
  }
  
  const envContent = `# ============================================================
# Hostel WhatsApp Bot - Environment Configuration
# ============================================================

# Supabase Configuration
SUPABASE_URL=https://sfkymoimtjgafvbclnqy.supabase.co
SUPABASE_SERVICE_ROLE_KEY=${key}

# Bot Configuration
BOT_NAME=HostelManagerBot

# Optional: Custom Chrome path (Windows default)
# CHROME_PATH=C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe
`;

  fs.writeFileSync('.env', envContent);
  console.log('\n✅ .env written with your key');
  rl.close();
  process.exit(0);
});