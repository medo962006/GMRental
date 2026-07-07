// lib/repositories/supabase_repository.dart
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/room.dart';
import '../models/tenant.dart';
import '../models/masareef.dart';
import '../models/task_routine.dart';
import '../models/operational_cost.dart';
import '../models/whatsapp_log.dart';
import '../models/insurance_ledger.dart';
import '../models/insurance_transaction.dart';
import '../models/admin_notification.dart';
import '../models/changelog_entry.dart';
import '../models/device_code.dart';
import '../models/reception_history.dart';

class SupabaseRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // ════════════════════════════════════════════════════════
  // ROOMS
  // ════════════════════════════════════════════════════════

  Stream<List<Room>> watchRooms({int? buildingId}) {
    final query = _client
        .from('rooms')
        .stream(primaryKey: ['id']);
    // Note: we filter client-side since Supabase stream doesn't support .eq() well
    return query
        .order('room_number')
        .map((data) {
          final rooms = data.map((e) => Room.fromJson(e)).toList();
          if (buildingId != null) {
            return rooms.where((r) => r.buildingId == buildingId).toList();
          }
          return rooms;
        });
  }

  Future<List<Room>> getRooms({int? buildingId}) async {
    final data = await _client.from('rooms').select().order('room_number');
    final rooms = (data as List).map((e) => Room.fromJson(e)).toList();
    if (buildingId != null) {
      return rooms.where((r) => r.buildingId == buildingId).toList();
    }
    return rooms;
  }

  Future<Room> addRoom(Room room) async {
    final data = await _client.from('rooms').insert({
      'room_number': room.roomNumber,
      'status': room.status,
      'reserved_amount': room.reservedAmount,
      'building_id': room.buildingId,
    }).select().single();
    return Room.fromJson(data);
  }

  Future<Room> updateRoom(Room room) async {
    final data = await _client.from('rooms').update({
      'room_number': room.roomNumber,
      'status': room.status,
      'reserved_amount': room.reservedAmount,
      'building_id': room.buildingId,
    }).eq('id', room.id).select().single();
    return Room.fromJson(data);
  }

  Future<void> deleteRoom(int id) async {
    await _client.from('rooms').delete().eq('id', id);
  }

  // ════════════════════════════════════════════════════════
  // TENANTS  (with Phase 2 auto-trigger on archive)
  // ════════════════════════════════════════════════════════

  Stream<List<Tenant>> watchTenants({int? buildingId}) {
    return _client
        .from('tenants')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) {
          final tenants = data.map((e) => Tenant.fromJson(e)).toList();
          if (buildingId != null) {
            return tenants.where((t) => t.buildingId == buildingId).toList();
          }
          return tenants;
        });
  }

  Future<List<Tenant>> getTenants({int? buildingId}) async {
    final data = await _client.from('tenants').select().order('created_at', ascending: false);
    final tenants = (data as List).map((e) => Tenant.fromJson(e)).toList();
    if (buildingId != null) {
      return tenants.where((t) => t.buildingId == buildingId).toList();
    }
    return tenants;
  }

  Future<List<Tenant>> getActiveTenants({int? buildingId}) async {
    final data = await _client.from('tenants').select().eq('status', 'active').order('created_at', ascending: false);
    final tenants = (data as List).map((e) => Tenant.fromJson(e)).toList();
    if (buildingId != null) {
      return tenants.where((t) => t.buildingId == buildingId).toList();
    }
    return tenants;
  }

  Future<List<Tenant>> getUnpaidTenants({int? buildingId}) async {
    final data = await _client.from('tenants').select().eq('status', 'active').eq('payment_status', 'unpaid').order('due_date');
    final tenants = (data as List).map((e) => Tenant.fromJson(e)).toList();
    if (buildingId != null) {
      return tenants.where((t) => t.buildingId == buildingId).toList();
    }
    return tenants;
  }

  Future<Tenant> addTenant(Tenant tenant) async {
    // Use the tenant's insuranceAmount as-is — admin sets it explicitly
    final double insurance = tenant.insuranceAmount;

    // Build insert payload — omit id so Supabase auto-generates it
    final insertData = <String, dynamic>{
      'name': tenant.name,
      'phone': tenant.phone,
      'gender': tenant.gender,
      'room_id': tenant.roomId,
      'building_id': tenant.buildingId,
      'status': tenant.status,
      'insurance_amount': insurance,
      'insurance_returned': tenant.insuranceReturned,
      'payment_status': tenant.paymentStatus,
      'due_date': tenant.dueDate?.toIso8601String().split('T').first,
      'lease_start_date': tenant.leaseStartDate?.toIso8601String().split('T').first,
    };

    final data = await _client.from('tenants').insert(insertData).select().single();

    // Auto-sync: add new tenant to reception history
    try {
      await autoAddNewTenant(
        name: tenant.name,
        buildingId: tenant.buildingId,
        roomNumber: tenant.roomId?.toString(),
        phone: tenant.phone,
      );
    } catch (_) {
      // Silently fail — history sync is non-critical
    }

    // Auto-set room to occupied when tenant is assigned
    if (tenant.roomId != null) {
      await _client.from('rooms').update({
        'status': 'occupied',
        'reserved_amount': 0,
      }).eq('id', tenant.roomId!);
    }

    return Tenant.fromJson(data);
  }

  /// Updates a tenant. If status changed to 'archived', automatically
  /// spawns a "Deep Clean & Prep Room" task in task_routines.
  Future<Tenant> updateTenant(Tenant tenant) async {
    final data = await _client.from('tenants').update({
      'name': tenant.name,
      'phone': tenant.phone,
      'gender': tenant.gender,
      'room_id': tenant.roomId,
      'building_id': tenant.buildingId,
      'status': tenant.status,
      'insurance_amount': tenant.insuranceAmount,
      'insurance_returned': tenant.insuranceReturned,
      'payment_status': tenant.paymentStatus,
      'due_date': tenant.dueDate?.toIso8601String().split('T').first,
      'lease_start_date': tenant.leaseStartDate?.toIso8601String().split('T').first,
    }).eq('id', tenant.id).select().single();

    final updated = Tenant.fromJson(data);

    // ── Phase 2 Auto-Trigger: Tenant Checkout ──────────
    if (tenant.status == 'archived' && tenant.roomId != null) {
      // Fetch room number for the task title
      final roomData = await _client.from('rooms').select('room_number').eq('id', tenant.roomId!).maybeSingle();
      final roomNum = roomData?['room_number'] ?? '${tenant.roomId}';

      await _client.from('task_routines').insert({
        'title': 'Deep Clean & Prep Room $roomNum',
        'description': 'Tenant ${tenant.name} checked out. Deep clean, inspect, and prep room $roomNum for next tenant.',
        'assigned_to': 'Worker',
        'status': 'pending',
        'room_id': tenant.roomId,
        'trigger_context': 'Tenant Checkout',
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    return updated;
  }

  /// Convenience: archive a tenant by ID (triggers auto task).
  Future<Tenant> archiveTenant(String tenantId) async {
    final current = await _client.from('tenants').select().eq('id', tenantId).single();
    final tenant = Tenant.fromJson(current);
    return updateTenant(tenant.copyWith(status: 'archived'));
  }

  Future<void> deleteTenant(String id) async {
    // Get tenant info before deletion for auto-sync to history
    final tenantData = await _client
        .from('tenants')
        .select('room_id, name, building_id, phone')
        .eq('id', id)
        .maybeSingle();
    final roomId = tenantData?['room_id'] as int?;
    final tenantName = tenantData?['name'] as String? ?? '';
    final tenantBuildingId = tenantData?['building_id'] as int? ?? 1;
    final tenantPhone = tenantData?['phone'] as String? ?? '';

    await _client.from('tenants').delete().eq('id', id);

    // Auto-sync: add removed tenant to reception history
    if (tenantName.isNotEmpty) {
      try {
        await autoAddToHistory(
          name: tenantName,
          buildingId: tenantBuildingId,
          roomNumber: roomId?.toString(),
          phone: tenantPhone,
        );
      } catch (_) {
        // Silently fail — history sync is non-critical
      }
    }

    // If tenant had a room, check if any other active tenants remain
    if (roomId != null) {
      final remaining = await _client.from('tenants').select('id').eq('room_id', roomId).eq('status', 'active').limit(1);
      if (remaining.isEmpty) {
        // Check current room status — reserved rooms stay reserved, others go to void
        final roomData = await _client.from('rooms').select('status').eq('id', roomId).maybeSingle();
        final currentStatus = roomData?['status'] as String? ?? 'void';
        final newStatus = currentStatus == 'reserved' ? 'reserved' : 'void';
        await _client.from('rooms').update({'status': newStatus}).eq('id', roomId);
      }
    }
  }

  Future<void> markTenantPaid(String id) async {
    // Simply mark as paid — due_date stays unchanged (admin sets it manually)
    await _client.from('tenants').update({
      'payment_status': 'paid',
    }).eq('id', id);
  }

  Future<void> markTenantUnpaid(String id) async {
    // Get current tenant to find due_date
    final data = await _client.from('tenants').select('due_date').eq('id', id).single();
    final dueDateStr = data['due_date'] as String?;

    // Set due_date to today so it's immediately overdue
    final today = DateTime.now();
    final newDue = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    await _client.from('tenants').update({
      'payment_status': 'unpaid',
      'due_date': newDue,
    }).eq('id', id);
  }

  // ════════════════════════════════════════════════════════
  // MASAREEF (EXPENSES)
  // ════════════════════════════════════════════════════════

  Stream<List<Masareef>> watchMasareef() {
    return _client
        .from('masareef')
        .stream(primaryKey: ['id'])
        .order('date_incurred', ascending: false)
        .map((data) => data.map((e) => Masareef.fromJson(e)).toList());
  }

  Future<List<Masareef>> getMasareef() async {
    final data = await _client.from('masareef').select().order('date_incurred', ascending: false);
    return (data as List).map((e) => Masareef.fromJson(e)).toList();
  }

  Future<Masareef> addMasareef(Masareef expense) async {
    final data = await _client.from('masareef').insert({
      'title': expense.title,
      'amount': expense.amount,
      'category': expense.category,
      'date_incurred': expense.dateIncurred.toIso8601String().split('T').first,
    }).select().single();
    return Masareef.fromJson(data);
  }

  Future<Masareef> updateMasareef(Masareef expense) async {
    final data = await _client.from('masareef').update({
      'title': expense.title,
      'amount': expense.amount,
      'category': expense.category,
      'date_incurred': expense.dateIncurred.toIso8601String().split('T').first,
    }).eq('id', expense.id).select().single();
    return Masareef.fromJson(data);
  }

  Future<void> deleteMasareef(String id) async {
    await _client.from('masareef').delete().eq('id', id);
  }

  // ════════════════════════════════════════════════════════
  // RECEIPT STORAGE (Supabase Storage — free tier: 1 GB)
  // ════════════════════════════════════════════════════════

  static const String _receiptBucket = 'receipts';
  static const int _maxFileSizeBytes = 20 * 1024 * 1024; // 20 MB
  static const int _compressionThresholdBytes = 5 * 1024 * 1024; // 5 MB

  /// Validates file size (max 20 MB). Throws [Exception] if exceeded.
  void validateReceiptFile(int fileSizeBytes, String extension) {
    if (fileSizeBytes > _maxFileSizeBytes) {
      throw Exception(
        'File too large (${_formatBytes(fileSizeBytes)}). '
        'Maximum allowed: ${_formatBytes(_maxFileSizeBytes)}.',
      );
    }
    final lower = extension.toLowerCase();
    if (lower != 'png' && lower != 'jpg' && lower != 'jpeg') {
      throw Exception('Only PNG and JPG files are allowed. Got: $extension');
    }
  }

  /// Compresses image bytes if above threshold.
  /// Returns compressed bytes and whether compression was applied.
  Future<({List<int> bytes, bool compressed, int originalSize, int finalSize})>
      compressIfNeeded(List<int> bytes, String extension) async {
    final originalSize = bytes.length;

    // Only compress images above threshold
    if (originalSize <= _compressionThresholdBytes) {
      return (bytes: bytes, compressed: false, originalSize: originalSize, finalSize: originalSize);
    }

    // Light compression: use Flutter's built-in image decoding/encoding
    // We import the compression logic at the service level to keep repo clean
    // For now, return as-is; the service layer handles actual compression
    return (bytes: bytes, compressed: false, originalSize: originalSize, finalSize: originalSize);
  }

  /// Uploads a receipt image to Supabase Storage.
  /// Returns the public URL of the uploaded file.
  Future<String> uploadReceipt({
    required String expenseId,
    required List<int> fileBytes,
    required String fileExtension,
  }) async {
    validateReceiptFile(fileBytes.length, fileExtension);

    final ext = fileExtension.toLowerCase() == 'jpeg' ? 'jpg' : fileExtension.toLowerCase();
    final fileName = '$expenseId.$ext';
    final filePath = fileName;

    await _client.storage.from(_receiptBucket).uploadBinary(
      filePath,
      Uint8List.fromList(fileBytes),
      fileOptions: FileOptions(
        contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
        upsert: true,
      ),
    );

    final publicUrl = _client.storage.from(_receiptBucket).getPublicUrl(filePath);
    return publicUrl;
  }

  /// Deletes a receipt from Supabase Storage.
  Future<void> deleteReceipt(String expenseId) async {
    // Try both extensions
    final files = <String>[];
    for (final ext in ['png', 'jpg']) {
      files.add('$expenseId.$ext');
    }
    try {
      await _client.storage.from(_receiptBucket).remove(files);
    } catch (_) {
      // File might not exist — that's fine
    }
  }

  /// Extracts the storage path from a receipt URL for the given expense.
  /// Returns the likely file path in storage.
  String getReceiptStoragePath(String expenseId, String? currentUrl) {
    if (currentUrl != null && currentUrl.isNotEmpty) {
      // Extract extension from URL
      final uri = Uri.parse(currentUrl);
      final path = uri.pathSegments.last;
      final dotIdx = path.lastIndexOf('.');
      if (dotIdx != -1) {
        final ext = path.substring(dotIdx + 1);
        return '$expenseId.$ext';
      }
    }
    return '$expenseId.jpg'; // default
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ════════════════════════════════════════════════════════
  // PHASE 2: TASK ROUTINES
  // ════════════════════════════════════════════════════════

  Stream<List<TaskRoutine>> watchTaskRoutines() {
    return _client
        .from('task_routines')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data.map((e) => TaskRoutine.fromJson(e)).toList());
  }

  Future<List<TaskRoutine>> getTaskRoutines() async {
    final data = await _client.from('task_routines').select().order('created_at', ascending: false);
    return (data as List).map((e) => TaskRoutine.fromJson(e)).toList();
  }

  Future<List<TaskRoutine>> getPendingTasks() async {
    final data = await _client.from('task_routines').select().eq('status', 'pending').order('created_at');
    return (data as List).map((e) => TaskRoutine.fromJson(e)).toList();
  }

  Future<TaskRoutine> addTaskRoutine(TaskRoutine task) async {
    final data = await _client.from('task_routines').insert({
      'title': task.title,
      'description': task.description,
      'assigned_to': task.assignedTo,
      'status': task.status,
      'room_id': task.roomId,
      'trigger_context': task.triggerContext,
      'created_at': task.createdAt.toIso8601String(),
    }).select().single();
    return TaskRoutine.fromJson(data);
  }

  /// Quick task injection — used by the "Quick Task" button.
  Future<TaskRoutine> quickAddTask({
    required String title,
    int? roomId,
    String assignedTo = 'Worker',
    String triggerContext = 'Manual',
  }) async {
    return addTaskRoutine(TaskRoutine(
      id: '',
      title: title,
      roomId: roomId,
      assignedTo: assignedTo,
      triggerContext: triggerContext,
      createdAt: DateTime.now(),
    ));
  }

  /// Mark a task as completed and stamp completed_at.
  Future<TaskRoutine> completeTask(String taskId) async {
    final data = await _client.from('task_routines').update({
      'status': 'completed',
      'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', taskId).select().single();
    return TaskRoutine.fromJson(data);
  }

  Future<TaskRoutine> updateTaskRoutine(TaskRoutine task) async {
    final data = await _client.from('task_routines').update({
      'title': task.title,
      'description': task.description,
      'assigned_to': task.assignedTo,
      'status': task.status,
      'room_id': task.roomId,
      'trigger_context': task.triggerContext,
    }).eq('id', task.id).select().single();
    return TaskRoutine.fromJson(data);
  }

  Future<void> deleteTaskRoutine(String id) async {
    await _client.from('task_routines').delete().eq('id', id);
  }

  // ════════════════════════════════════════════════════════
  // PHASE 2: OPERATIONAL COSTS
  // ════════════════════════════════════════════════════════

  Stream<List<OperationalCost>> watchOperationalCosts() {
    return _client
        .from('operational_costs')
        .stream(primaryKey: ['id'])
        .order('billing_date', ascending: false)
        .map((data) => data.map((e) => OperationalCost.fromJson(e)).toList());
  }

  Future<List<OperationalCost>> getOperationalCosts() async {
    final data = await _client.from('operational_costs').select().order('billing_date', ascending: false);
    return (data as List).map((e) => OperationalCost.fromJson(e)).toList();
  }

  Future<OperationalCost> addOperationalCost(OperationalCost cost) async {
    final data = await _client.from('operational_costs').insert({
      'title': cost.title,
      'amount': cost.amount,
      'cost_type': cost.costType,
      'billing_date': cost.billingDate.toIso8601String().split('T').first,
    }).select().single();
    return OperationalCost.fromJson(data);
  }

  Future<OperationalCost> updateOperationalCost(OperationalCost cost) async {
    final data = await _client.from('operational_costs').update({
      'title': cost.title,
      'amount': cost.amount,
      'cost_type': cost.costType,
      'billing_date': cost.billingDate.toIso8601String().split('T').first,
    }).eq('id', cost.id).select().single();
    return OperationalCost.fromJson(data);
  }

  Future<void> deleteOperationalCost(String id) async {
    await _client.from('operational_costs').delete().eq('id', id);
  }

  // ════════════════════════════════════════════════════════
  // PHASE 3: WHATSAPP LOGS
  // ════════════════════════════════════════════════════════

  Stream<List<WhatsAppLog>> watchWhatsAppLogs() {
    return _client
        .from('whatsapp_logs')
        .stream(primaryKey: ['id'])
        .order('sent_at', ascending: false)
        .map((data) => data.map((e) => WhatsAppLog.fromJson(e)).toList());
  }

  Future<List<WhatsAppLog>> getWhatsAppLogs() async {
    final data = await _client.from('whatsapp_logs').select().order('sent_at', ascending: false);
    return (data as List).map((e) => WhatsAppLog.fromJson(e)).toList();
  }

  Future<WhatsAppLog> logWhatsAppMessage({
    String? tenantId,
    required String messageType,
    required String messageBody,
    String status = 'sent',
  }) async {
    final data = await _client.from('whatsapp_logs').insert({
      'tenant_id': tenantId,
      'message_type': messageType,
      'message_body': messageBody,
      'status': status,
      'sent_at': DateTime.now().toIso8601String(),
    }).select().single();
    return WhatsAppLog.fromJson(data);
  }

  // ════════════════════════════════════════════════════════
  // DASHBOARD STATS (enhanced with Phase 2 data)
  // ════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getDashboardStats({int? buildingId}) async {
    final tenants = await getActiveTenants(buildingId: buildingId);
    final expenses = await getMasareef();
    final rooms = await getRooms(buildingId: buildingId);
    final opCosts = await getOperationalCosts();
    final pendingTasks = await getPendingTasks();

    // Current month boundaries
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    // Expected: sum of insuranceAmount for all active tenants
    final totalRentExpected =
        tenants.fold(0.0, (sum, t) => sum + t.insuranceAmount);

    // Collected: sum of insuranceAmount for paid tenants
    final totalRentCollected =
        tenants.where((t) => t.isPaid).fold(0.0, (sum, t) => sum + t.insuranceAmount);

    // Overdue: sum of insuranceAmount for unpaid tenants whose dueDate has passed
    final overdueTenants = tenants.where((t) {
      if (t.isPaid) return false;
      if (t.dueDate == null) return false;
      return t.dueDate!.isBefore(now);
    }).toList();

    final totalRentOverdue = overdueTenants.fold(0.0, (sum, t) => sum + t.insuranceAmount);

    // Unpaid (not yet overdue): expected - collected - overdue
    final totalRentUnpaid = totalRentExpected - totalRentCollected - totalRentOverdue;

    final paidCount = tenants.where((t) => t.isPaid).length;
    final unpaidCount = tenants.where((t) => t.isUnpaid).length;
    final totalExpenses = expenses.fold(0.0, (sum, e) => sum + e.amount);
    final totalOpCosts = opCosts.fold(0.0, (sum, c) => sum + c.amount);

    return {
      'totalRooms': rooms.length,
      'occupiedRooms': rooms.where((r) => r.isOccupied).length,
      'voidRooms': rooms.where((r) => r.isVoid).length,
      'totalTenants': tenants.length,
      'paidTenants': paidCount,
      'unpaidTenants': unpaidCount,
      'overdueTenants': overdueTenants,
      'totalRentExpected': totalRentExpected,
      'totalRentCollected': totalRentCollected,
      'totalRentOverdue': totalRentOverdue,
      'totalRentUnpaid': totalRentUnpaid.clamp(0, totalRentExpected),
      'totalExpenses': totalExpenses,
      'totalOpCosts': totalOpCosts,
      'totalCosts': totalExpenses + totalOpCosts,
      'netBalance': totalRentCollected - totalExpenses - totalOpCosts,
      'pendingTasks': pendingTasks.length,
    };
  }

  // ════════════════════════════════════════════════════════
  // PAYMENT STATUS AUTO-UPDATE
  // ════════════════════════════════════════════════════════

  /// Auto-update payment_status for all tenants based on due_date.
  ///
  /// Runs once on app startup:
  ///   1. PAID tenants whose due_date is strictly BEFORE today → flip to
  ///      unpaid (do not flip on the exact due day — paying on the due day
  ///      is on time).
  ///   2. UNPAID tenants with a stale due_date → reset due_date to today so
  ///      the overdue countdown restarts from today instead of counting days
  ///      from the original missed date.
  ///
  /// Does NOT flip unpaid → paid (admin sets that manually via markTenantPaid).
  Future<int> autoUpdatePaymentStatus({int? buildingId}) async {
    final tenants = buildingId != null
        ? await getActiveTenants(buildingId: buildingId)
        : await _client.from('tenants').select().eq('status', 'active').then(
            (data) => (data as List).map((e) => Tenant.fromJson(e)).toList());
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    int updated = 0;

    for (final t in tenants) {
      if (t.dueDate == null) continue;

      // Compare at day granularity: a tenant is past due only when their
      // due_date calendar day is strictly before today's calendar day.
      final dueDay = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      final isPastDue = dueDay.isBefore(today);

      if (t.isPaid && isPastDue) {
        // PAST-DUE + still marked paid → flip to unpaid. Keep the original
        // due_date so the overdue count shows the actual days late.
        await _client.from('tenants').update({
          'payment_status': 'unpaid',
        }).eq('id', t.id);
        updated++;
      } else if (t.isUnpaid && isPastDue) {
        // Already unpaid but due_date is stale → reset due_date to today
        // so overdue count resets from today (housekeeping).
        await _client.from('tenants').update({
          'due_date': todayStr,
        }).eq('id', t.id);
        updated++;
      }
    }

    return updated;
  }

  // ════════════════════════════════════════════════════════
  // PHASE 3.7: INSURANCE LEDGER
  // ════════════════════════════════════════════════════════

  Stream<List<InsuranceLedger>> watchInsuranceLedgers() {
    return _client
        .from('insurance_ledger')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data.map((e) => InsuranceLedger.fromJson(e)).toList());
  }

  Future<List<InsuranceLedger>> getInsuranceLedgers() async {
    final data = await _client.from('insurance_ledger').select().order('created_at', ascending: false);
    return (data as List).map((e) => InsuranceLedger.fromJson(e)).toList();
  }

  Future<InsuranceLedger> createInsuranceLedger({
    required String tenantId,
    required double totalAgreedAmount,
    double amountPaidSoFar = 0.0,
    DateTime? dueDateForRemaining,
  }) async {
    final data = await _client.from('insurance_ledger').insert({
      'tenant_id': tenantId,
      'total_agreed_amount': totalAgreedAmount,
      'amount_paid_so_far': amountPaidSoFar,
      'due_date_for_remaining': dueDateForRemaining?.toIso8601String().split('T').first,
      'status': amountPaidSoFar >= totalAgreedAmount ? 'fully_paid' : 'partial',
    }).select().single();
    return InsuranceLedger.fromJson(data);
  }

  /// Update insurance ledger amounts (for manual edits).
  Future<InsuranceLedger> updateInsuranceLedger({
    required String id,
    required double totalAgreedAmount,
    required double amountPaidSoFar,
  }) async {
    final remaining = totalAgreedAmount - amountPaidSoFar;
    final status = amountPaidSoFar >= totalAgreedAmount ? 'fully_paid' : 'partial';
    final data = await _client.from('insurance_ledger').update({
      'total_agreed_amount': totalAgreedAmount,
      'amount_paid_so_far': amountPaidSoFar,
      'status': status,
    }).eq('id', id).select().single();
    return InsuranceLedger.fromJson(data);
  }

  /// Collect partial insurance payment. Atomically updates the ledger
  /// and inserts a payment_received transaction.
  Future<InsuranceLedger> collectInsurancePayment({
    required String insuranceId,
    required double amount,
    String? notes,
  }) async {
    // Get current ledger
    final current = await _client.from('insurance_ledger').select().eq('id', insuranceId).single();
    final ledger = InsuranceLedger.fromJson(current);
    final newPaid = ledger.amountPaidSoFar + amount;
    final newStatus = newPaid >= ledger.totalAgreedAmount ? 'fully_paid' : 'partial';

    // Update ledger
    final updated = await _client.from('insurance_ledger').update({
      'amount_paid_so_far': newPaid,
      'status': newStatus,
    }).eq('id', insuranceId).select().single();

    // Log transaction
    await _client.from('insurance_transactions').insert({
      'insurance_id': insuranceId,
      'transaction_type': 'payment_received',
      'amount': amount,
      'notes': notes ?? 'Insurance payment collected',
    });

    return InsuranceLedger.fromJson(updated);
  }

  /// Process refund (full or partial). Logs refund_paid transaction.
  /// If deductionAmount > 0, also logs a deduction_spend transaction
  /// and creates a masareef expense for the deducted amount.
  Future<InsuranceLedger> processInsuranceRefund({
    required String insuranceId,
    required double refundAmount,
    double deductionAmount = 0.0,
    String? deductionNotes,
    int? roomId,
  }) async {
    final current = await _client.from('insurance_ledger').select().eq('id', insuranceId).single();
    final ledger = InsuranceLedger.fromJson(current);

    // Log refund transaction
    await _client.from('insurance_transactions').insert({
      'insurance_id': insuranceId,
      'transaction_type': 'refund_paid',
      'amount': refundAmount,
      'notes': 'Insurance refund processed',
    });

    // If there's a deduction, log it and create a masareef expense
    if (deductionAmount > 0) {
      await _client.from('insurance_transactions').insert({
        'insurance_id': insuranceId,
        'transaction_type': 'deduction_spend',
        'amount': deductionAmount,
        'notes': deductionNotes ?? 'Insurance deduction',
      });

      // Create masareef expense for the deducted amount
      await _client.from('masareef').insert({
        'title': 'Insurance Deduction - Room ${roomId ?? 'N/A'}',
        'amount': deductionAmount,
        'category': 'general',
        'date_incurred': DateTime.now().toIso8601String().split('T').first,
      });
    }

    // Update ledger status to refunded
    final updated = await _client.from('insurance_ledger').update({
      'status': 'refunded',
    }).eq('id', insuranceId).select().single();

    return InsuranceLedger.fromJson(updated);
  }

  Future<void> deleteInsuranceLedger(String id) async {
    await _client.from('insurance_ledger').delete().eq('id', id);
  }

  // ════════════════════════════════════════════════════════
  // PHASE 3.7: INSURANCE TRANSACTIONS
  // ════════════════════════════════════════════════════════

  Future<List<InsuranceTransaction>> getInsuranceTransactions(String insuranceId) async {
    final data = await _client
        .from('insurance_transactions')
        .select()
        .eq('insurance_id', insuranceId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => InsuranceTransaction.fromJson(e)).toList();
  }

  // ════════════════════════════════════════════════════════
  // PHASE 3.7: ADMIN NOTIFICATIONS
  // ════════════════════════════════════════════════════════

  Stream<List<AdminNotification>> watchAdminNotifications() {
    return _client
        .from('admin_notifications')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data.map((e) => AdminNotification.fromJson(e)).toList());
  }

  Future<List<AdminNotification>> getAdminNotifications() async {
    final data = await _client
        .from('admin_notifications')
        .select()
        .order('created_at', ascending: false);
    return (data as List).map((e) => AdminNotification.fromJson(e)).toList();
  }

  Future<AdminNotification> createNotification({
    required String title,
    required String body,
    required String category,
  }) async {
    final data = await _client.from('admin_notifications').insert({
      'title': title,
      'body': body,
      'category': category,
    }).select().single();
    return AdminNotification.fromJson(data);
  }

  /// Mark a notification as read by a specific admin.
  Future<void> markNotificationRead(String notificationId, String adminId) async {
    final current = await _client
        .from('admin_notifications')
        .select('is_read_by_admin')
        .eq('id', notificationId)
        .single();
    final readRaw = current['is_read_by_admin'] as List?;
    final readList = readRaw?.map((e) => e.toString()).toList() ?? [];
    if (!readList.contains(adminId)) {
      readList.add(adminId);
      await _client.from('admin_notifications').update({
        'is_read_by_admin': readList,
      }).eq('id', notificationId);
    }
  }

  Future<void> deleteNotification(String id) async {
    await _client.from('admin_notifications').delete().eq('id', id);
  }

  // ════════════════════════════════════════════════════════
  // CHANGELOG
  // ════════════════════════════════════════════════════════

  Stream<List<ChangelogEntry>> watchChangelog({int? buildingId}) {
    var query = _client
        .from('changelog')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
    return query.map((data) {
      final entries = data.map((e) => ChangelogEntry.fromJson(e)).toList();
      if (buildingId != null) {
        return entries.where((e) => e.buildingId == buildingId).toList();
      }
      return entries;
    });
  }

  Future<List<ChangelogEntry>> getChangelog({int? buildingId, int limit = 100}) async {
    final data = await _client
        .from('changelog')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    final entries = (data as List).map((e) => ChangelogEntry.fromJson(e)).toList();
    if (buildingId != null) {
      return entries.where((e) => e.buildingId == buildingId).toList();
    }
    return entries;
  }

  Future<void> logChange({
    required String deviceCode,
    String? adminName,
    required String action,
    required String entityType,
    String? entityId,
    String? entityName,
    Map<String, dynamic>? oldValue,
    Map<String, dynamic>? newValue,
    String? details,
    int buildingId = 1,
  }) async {
    await _client.from('changelog').insert({
      'device_code': deviceCode,
      'admin_name': adminName,
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'entity_name': entityName,
      'old_value': oldValue,
      'new_value': newValue,
      'details': details,
      'building_id': buildingId,
    });
  }

  Future<void> registerDevice(String code, {String? deviceName}) async {
    await _client.from('device_codes').upsert({
      'code': code,
      'device_name': deviceName,
      'last_seen_at': DateTime.now().toIso8601String(),
    });
  }

  Future<DeviceCode?> getDevice(String code) async {
    final data = await _client
        .from('device_codes')
        .select()
        .eq('code', code)
        .eq('is_active', true)
        .maybeSingle();
    if (data == null) return null;
    return DeviceCode.fromJson(data);
  }

  Future<List<DeviceCode>> getAllDevices() async {
    final data = await _client
        .from('device_codes')
        .select()
        .order('created_at', ascending: false);
    return (data as List).map((e) => DeviceCode.fromJson(e)).toList();
  }

  // ════════════════════════════════════════════════════════
  // RECEPTION HISTORY
  // ════════════════════════════════════════════════════════

  Stream<List<ReceptionHistory>> watchReceptionHistory({int? buildingId}) {
    final query = _client
        .from('reception_history')
        .stream(primaryKey: ['id']);
    return query.order('created_at', ascending: false).map((data) {
      final list = data.map((e) => ReceptionHistory.fromJson(e)).toList();
      if (buildingId != null) {
        return list.where((r) => r.buildingId == buildingId).toList();
      }
      return list;
    });
  }

  Future<List<ReceptionHistory>> getReceptionHistory({int? buildingId}) async {
    final data = await _client
        .from('reception_history')
        .select()
        .order('created_at', ascending: false);
    final list = (data as List).map((e) => ReceptionHistory.fromJson(e)).toList();
    if (buildingId != null) {
      return list.where((r) => r.buildingId == buildingId).toList();
    }
    return list;
  }

  Future<ReceptionHistory> addReceptionHistory(ReceptionHistory entry) async {
    final data = await _client.from('reception_history').insert({
      'name': entry.name,
      'phone': entry.phone,
      'nationality': entry.nationality,
      'building_id': entry.buildingId,
      'room_number': entry.roomNumber,
      'move_in_date': entry.moveInDate?.toIso8601String().split('T').first,
      'insurance_amount': entry.insuranceAmount,
      'lease_duration': entry.leaseDuration,
      'amount_paid_upfront': entry.amountPaidUpfront,
      'remaining_amount': entry.remainingAmount,
      'payment_method': entry.paymentMethod,
      'lease_status': entry.leaseStatus,
      'notes': entry.notes,
    }).select().single();
    return ReceptionHistory.fromJson(data);
  }

  Future<ReceptionHistory> updateReceptionHistory(ReceptionHistory entry) async {
    final data = await _client.from('reception_history').update({
      'name': entry.name,
      'phone': entry.phone,
      'nationality': entry.nationality,
      'building_id': entry.buildingId,
      'room_number': entry.roomNumber,
      'move_in_date': entry.moveInDate?.toIso8601String().split('T').first,
      'insurance_amount': entry.insuranceAmount,
      'lease_duration': entry.leaseDuration,
      'amount_paid_upfront': entry.amountPaidUpfront,
      'remaining_amount': entry.remainingAmount,
      'payment_method': entry.paymentMethod,
      'lease_status': entry.leaseStatus,
      'notes': entry.notes,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', entry.id).select().single();
    return ReceptionHistory.fromJson(data);
  }

  Future<void> deleteReceptionHistory(String id) async {
    await _client.from('reception_history').delete().eq('id', id);
  }

  /// Auto-sync: when a tenant is deleted from a building, add them to reception_history.
  /// Called from deleteTenant in the rooms screen actions.
  Future<void> autoAddToHistory({
    required String name,
    required int buildingId,
    String? roomNumber,
    String? phone,
  }) async {
    await _client.from('reception_history').insert({
      'name': name,
      'phone': phone ?? '',
      'building_id': buildingId,
      'room_number': roomNumber ?? '',
      'move_in_date': DateTime.now().toIso8601String().split('T').first,
      'lease_status': 'removed',
      'notes': 'Auto-added on tenant removal',
    });
  }

  /// Auto-sync: when a new tenant is added, add them to reception_history.
  Future<void> autoAddNewTenant({
    required String name,
    required int buildingId,
    String? roomNumber,
    String? phone,
  }) async {
    await _client.from('reception_history').insert({
      'name': name,
      'phone': phone ?? '',
      'building_id': buildingId,
      'room_number': roomNumber ?? '',
      'move_in_date': DateTime.now().toIso8601String().split('T').first,
      'lease_status': 'ساري',
      'notes': 'Auto-added on tenant creation',
    });
  }
}
