const fs = require('fs');

const envPath = '.env';
if (!fs.existsSync(envPath)) {
  console.error('❌ .env file not found');
  process.exit(1);
}

const content = fs.readFileSync(envPath, 'utf8');
console.log('=== Current .env content ===');
console.log(content);

if (content.includes('YOUR_SERVICE_ROLE_KEY_HERE')) {
  console.log('\n❌ PLACEHOLDER STILL PRESENT!');
  console.log('Edit .env and replace YOUR_SERVICE_ROLE_KEY_HERE with your actual key');
  console.log('\nRun: notepad .env');
  process.exit(1);
} else if (content.includes('SUPABASE_SERVICE_ROLE_KEY=') && content.split('SUPABASE_SERVICE_ROLE_KEY=')[1].split('\n')[0].length > 50) {
  console.log('\n✅ Key appears to be set');
  process.exit(0);
} else {
  console.log('\n❌ Key not found or too short');
  process.exit(1);
}