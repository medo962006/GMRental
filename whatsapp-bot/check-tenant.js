// check-tenant.js
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);

async function check() {
  const { data, error } = await supabase
    .from('tenants')
    .select('id, name, phone, room_id, building_id, payment_status, rent_amount, due_date, status')
    .ilike('name', '%باسنت%');
  
  if (error) {
    console.error('Error:', error);
  } else {
    console.log('Tenant:', JSON.stringify(data, null, 2));
  }
}

check();