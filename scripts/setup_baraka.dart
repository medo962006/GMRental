// scripts/setup_baraka.dart
// Run with: dart run scripts/setup_baraka.dart
// This sets up the Baraka building database with rooms and tenants.

import 'dart:convert';
import 'package:http/http.dart' as http;

const supabaseUrl = 'https://sfkymoimtjgafvbclnqy.supabase.co';
const supabaseKey = 'sb_publishable_L1gku764fsbQWnoeMPH1qg_C2cJuISC';

final headers = {
  'apikey': supabaseKey,
  'Authorization': 'Bearer $supabaseKey',
  'Content-Type': 'application/json',
  'Prefer': 'return=representation',
};

Future<List<dynamic>> fetch(String table, {String? params}) async {
  final url = '$supabaseUrl/rest/v1/$table${params ?? '?select=*'}';
  final res = await http.get(Uri.parse(url), headers: headers);
  if (res.statusCode >= 400) throw Exception('GET $table failed: ${res.body}');
  return jsonDecode(res.body) as List<dynamic>;
}

Future<List<dynamic>> insert(String table, List<Map<String, dynamic>> rows) async {
  final url = '$supabaseUrl/rest/v1/$table';
  final res = await http.post(Uri.parse(url),
      headers: {...headers, 'Prefer': 'return=representation'},
      body: jsonEncode(rows));
  if (res.statusCode >= 400) {
    print('INSERT $table ERROR: ${res.statusCode} ${res.body}');
    throw Exception('INSERT $table failed');
  }
  return jsonDecode(res.body) as List<dynamic>;
}

Future<void> updateRoom(int id, Map<String, dynamic> data) async {
  final url = '$supabaseUrl/rest/v1/rooms?id=eq.$id';
  final res = await http.patch(Uri.parse(url), headers: headers, body: jsonEncode(data));
  if (res.statusCode >= 400) print('UPDATE room $id ERROR: ${res.body}');
}

Future<void> main() async {
  print('═══ Baraka Building Database Setup ═══\n');

  // ── 1. Update all existing rooms to building_id = 1 ──
  print('Step 1: Updating existing rooms to building_id=1...');
  final existingRooms = await fetch('rooms');
  for (final r in existingRooms) {
    await updateRoom(r['id'] as int, {'building_id': 1});
  }
  print('  Updated ${existingRooms.length} rooms.\n');

  // ── 2. Check if Baraka rooms already exist ──
  final allRooms = await fetch('rooms', params: '?select=*,building_id');
  final barakaRooms = allRooms.where((r) => r['building_id'] == 2).toList();
  if (barakaRooms.isNotEmpty) {
    print('Baraka already has ${barakaRooms.length} rooms. Skipping room creation.');
    print('Delete them first if you want to re-create.\n');
  } else {
    // ── 3. Create Baraka rooms ──
    print('Step 2: Creating Baraka rooms...');
    final barakaRoomData = [
      // Ground floor
      {'room_number': 'B1G', 'status': 'void', 'monthly_rent': 8000, 'building_id': 2, 'floor': 'G'},
      {'room_number': 'B2G', 'status': 'void', 'monthly_rent': 8000, 'building_id': 2, 'floor': 'G'},
      {'room_number': 'B3G', 'status': 'void', 'monthly_rent': 8000, 'building_id': 2, 'floor': 'G'},
      {'room_number': 'B4G', 'status': 'void', 'monthly_rent': 8500, 'building_id': 2, 'floor': 'G'},
      {'room_number': 'B5G', 'status': 'void', 'monthly_rent': 8500, 'building_id': 2, 'floor': 'G'},
      {'room_number': 'B6G', 'status': 'void', 'monthly_rent': 8500, 'building_id': 2, 'floor': 'G'},
      // First floor
      {'room_number': 'B1F', 'status': 'void', 'monthly_rent': 9000, 'building_id': 2, 'floor': 'F'},
      {'room_number': 'B2F', 'status': 'void', 'monthly_rent': 9000, 'building_id': 2, 'floor': 'F'},
      {'room_number': 'B3F', 'status': 'void', 'monthly_rent': 9000, 'building_id': 2, 'floor': 'F'},
      {'room_number': 'B4F', 'status': 'void', 'monthly_rent': 9500, 'building_id': 2, 'floor': 'F'},
      {'room_number': 'B5F', 'status': 'void', 'monthly_rent': 9500, 'building_id': 2, 'floor': 'F'},
      {'room_number': 'B6F', 'status': 'void', 'monthly_rent': 9500, 'building_id': 2, 'floor': 'F'},
      // Second floor
      {'room_number': 'B1S', 'status': 'void', 'monthly_rent': 10000, 'building_id': 2, 'floor': 'S'},
      {'room_number': 'B2S', 'status': 'void', 'monthly_rent': 10000, 'building_id': 2, 'floor': 'S'},
      {'room_number': 'B3S', 'status': 'void', 'monthly_rent': 10000, 'building_id': 2, 'floor': 'S'},
      {'room_number': 'B4S', 'status': 'void', 'monthly_rent': 10500, 'building_id': 2, 'floor': 'S'},
      {'room_number': 'B5S', 'status': 'void', 'monthly_rent': 10500, 'building_id': 2, 'floor': 'S'},
      {'room_number': 'B6S', 'status': 'void', 'monthly_rent': 10500, 'building_id': 2, 'floor': 'S'},
    ];
    final createdRooms = await insert('rooms', barakaRoomData);
    print('  Created ${createdRooms.length} Baraka rooms.\n');

    // ── 4. Create sample Baraka tenants ──
    print('Step 3: Creating sample Baraka tenants...');
    // Map rooms by number for easy lookup
    final roomMap = <String, int>{};
    for (final r in createdRooms) {
      roomMap[r['room_number'] as String] = r['id'] as int;
    }

    final now = DateTime.now().toIso8601String();
    final barakaTenants = [
      {
        'name': 'أحمد محمد',
        'phone': '010-12345678',
        'gender': 'male',
        'room_id': roomMap['B1G'],
        'building_id': 2,
        'status': 'active',
        'insurance_amount': 5000.0,
        'insurance_returned': false,
        'payment_status': 'unpaid',
        'due_date': '2026-07-01',
        'lease_start_date': '2026-06-15',
        'created_at': now,
      },
      {
        'name': 'محمد علي',
        'phone': '011-23456789',
        'gender': 'male',
        'room_id': roomMap['B2G'],
        'building_id': 2,
        'status': 'active',
        'insurance_amount': 5000.0,
        'insurance_returned': false,
        'payment_status': 'paid',
        'due_date': '2026-07-01',
        'lease_start_date': '2026-06-10',
        'created_at': now,
      },
      {
        'name': 'سارة أحمد',
        'phone': '012-34567890',
        'gender': 'female',
        'room_id': roomMap['B1F'],
        'building_id': 2,
        'status': 'active',
        'insurance_amount': 6000.0,
        'insurance_returned': false,
        'payment_status': 'unpaid',
        'due_date': '2026-07-05',
        'lease_start_date': '2026-06-01',
        'created_at': now,
      },
      {
        'name': 'خالد إبراهيم',
        'phone': '015-45678901',
        'gender': 'male',
        'room_id': roomMap['B1S'],
        'building_id': 2,
        'status': 'active',
        'insurance_amount': 7000.0,
        'insurance_returned': false,
        'payment_status': 'unpaid',
        'due_date': '2026-07-10',
        'lease_start_date': '2026-05-20',
        'created_at': now,
      },
    ];
    final createdTenants = await insert('tenants', barakaTenants);
    print('  Created ${createdTenants.length} Baraka tenants.\n');

    // ── 5. Create insurance ledger for Baraka tenants ──
    print('Step 4: Creating Baraka insurance ledger...');
    final insuranceData = [
      {
        'tenant_id': createdTenants[0]['id'],
        'total_agreed_amount': 5000.0,
        'amount_paid_so_far': 2000.0,
        'due_date_for_remaining': '2026-08-01',
        'status': 'partial',
      },
      {
        'tenant_id': createdTenants[2]['id'],
        'total_agreed_amount': 6000.0,
        'amount_paid_so_far': 0.0,
        'due_date_for_remaining': '2026-07-15',
        'status': 'partial',
      },
    ];
    await insert('insurance_ledger', insuranceData);
    print('  Created ${insuranceData.length} insurance records.\n');
  }

  // ── 6. Summary ──
  print('═══ Setup Complete ═══');
  final finalRooms = await fetch('rooms', params: '?select=building_id');
  final mainCount = finalRooms.where((r) => r['building_id'] == 1).length;
  final barakaCount = finalRooms.where((r) => r['building_id'] == 2).length;
  print('Main Building: $mainCount rooms');
  print('Baraka: $barakaCount rooms');

  final allTenants = await fetch('tenants', params: '?select=building_id');
  final mainTenants = allTenants.where((t) => t['building_id'] == 1).length;
  final barakaTenants = allTenants.where((t) => t['building_id'] == 2).length;
  print('Main Building: $mainTenants tenants');
  print('Baraka: $barakaTenants tenants');
}
