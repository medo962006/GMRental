// test_notifications.dart
// Run with: dart test_notifications.dart
// Or from WSL: dart run test_notifications.dart
//
// This script creates test notifications in Supabase directly.
// Useful for testing the notification screen without waiting for real triggers.

import 'dart:convert';
import 'dart:io';

// Supabase config — matches app_config.dart
const String supabaseUrl = 'https://bqqpfldaeeahdmccxqxv.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlhdCI6MTczMjI3NTQ2MywiZXhwIjoyMDQ3NjM1NDYzfQ.hq4CrIFQv7i3p6r5FJz5f2vE7sVJpaxDJpo1EsVU50';

Future<void> main() async {
  print('🔔 Hostel Manager — Notification Test Tool');
  print('==========================================\n');

  final client = HttpClient();

  // Test 1: Create a rent_due notification
  print('📌 Test 1: Creating rent_due notification...');
  await _createNotification(
    client,
    title: 'Rent Due: Room 9S',
    body: 'Ahmed\'s rent is 3 days overdue. Please collect payment.',
    category: 'rent_due',
  );

  // Test 2: Create an insurance_alert notification
  print('📌 Test 2: Creating insurance_alert notification...');
  await _createNotification(
    client,
    title: 'Ta2meen Reminder',
    body: 'Insurance payment of 500 LE is due today.',
    category: 'insurance_alert',
  );

  // Test 3: Create a task_pending notification
  print('📌 Test 3: Creating task_pending notification...');
  await _createNotification(
    client,
    title: 'Pending Task: Fix AC in Room 3F',
    body: 'Task "Fix AC in Room 3F" has been pending for 48h. Assigned to: Maintenance',
    category: 'task_pending',
  );

  // Test 4: Create a payment_received notification
  print('📌 Test 4: Creating payment_received notification...');
  await _createNotification(
    client,
    title: 'Payment Received',
    body: 'Mohamed paid 1500 LE for Room 5G. Receipt #1234.',
    category: 'payment_received',
  );

  // Test 5: Create a tenant_checkout notification
  print('📌 Test 5: Creating tenant_checkout notification...');
  await _createNotification(
    client,
    title: 'Tenant Checkout: Room 2S',
    body: 'Sara has checked out. Room needs cleaning and inspection.',
    category: 'tenant_checkout',
  );

  print('\n✅ All test notifications created!');
  print('   Open the app → Notifications tab to see them.');
  print('   Categories tested: rent_due, insurance_alert, task_pending, payment_received, tenant_checkout');

  client.close();
}

Future<void> _createNotification(
  HttpClient client, {
  required String title,
  required String body,
  required String category,
}) async {
  try {
    final request = await client.postUrl(Uri.parse('$supabaseUrl/rest/v1/admin_notifications'));
    request.headers.set('apikey', supabaseAnonKey);
    request.headers.set('Authorization', 'Bearer $supabaseAnonKey');
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Prefer', 'return=representation');

    final payload = jsonEncode({
      'title': title,
      'body': body,
      'category': category,
    });

    request.write(payload);
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      print('   ✅ Created: $title ($category)');
    } else {
      print('   ❌ Failed: $title — ${response.statusCode}: $responseBody');
    }
  } catch (e) {
    print('   ❌ Error: $title — $e');
  }
}
