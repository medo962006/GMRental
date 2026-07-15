#!/usr/bin/env node
// test.js - Test script to verify bot configuration and Supabase connection

require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('❌ Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function testConnection() {
  console.log('🔍 Testing Supabase connection...');
  
  try {
    // Test 1: Check tenants table
    console.log('\n📋 Testing tenants table...');
    const { data: tenants, error: tenantsError } = await supabase
      .from('tenants')
      .select('id, name, phone, payment_status, insurance_amount')
      .limit(5);
    
    if (tenantsError) throw tenantsError;
    console.log(`✅ Found ${tenants.length} sample tenants`);
    tenants.forEach(t => console.log(`   - ${t.name}: ${t.payment_status} | ${t.insurance_amount} EGP | ${t.phone || 'no phone'}`));
    
    // Test 2: Check unpaid tenants
    console.log('\n📋 Testing unpaid tenants query...');
    const { data: unpaid, error: unpaidError } = await supabase
      .from('tenants')
      .select('id, name, phone, room_id, insurance_amount, due_date')
      .eq('status', 'active')
      .eq('payment_status', 'unpaid');
    
    if (unpaidError) throw unpaidError;
    console.log(`✅ Found ${unpaid.length} unpaid tenants`);
    unpaid.forEach(t => console.log(`   - ${t.name} (room ${t.room_id}): ${t.insurance_amount} EGP | phone: ${t.phone || 'none'}`));
    
    // Test 3: Check whatsapp_logs table
    console.log('\n📋 Testing whatsapp_logs table...');
    const { data: logs, error: logsError } = await supabase
      .from('whatsapp_logs')
      .select('id, tenant_id, message_type, sent_at')
      .limit(5);
    
    if (logsError) throw logsError;
    console.log(`✅ Found ${logs.length} sample logs`);
    logs.forEach(l => console.log(`   - ${l.message_type} to tenant ${l.tenant_id} at ${l.sent_at}`));
    
    // Test 4: Check if we can insert a test log
    console.log('\n📋 Testing log insertion...');
    const { data: testLog, error: insertError } = await supabase
      .from('whatsapp_logs')
      .insert({
        tenant_id: tenants[0]?.id || null,
        message_type: 'test',
        message_body: 'Test message from bot verification',
        status: 'sent'
      })
      .select()
      .single();
    
    if (insertError) throw insertError;
    console.log(`✅ Test log inserted: ${testLog.id}`);
    
    // Clean up test log
    await supabase.from('whatsapp_logs').delete().eq('id', testLog.id);
    console.log('✅ Test log cleaned up');
    
    console.log('\n🎉 All tests passed! Bot is ready to run.');
    
  } catch (error) {
    console.error('\n❌ Test failed:', error.message);
    process.exit(1);
  }
}

testConnection();