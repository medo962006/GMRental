// lib/repositories/supabase_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/room.dart';
import '../models/tenant.dart';
import '../models/masareef.dart';
import '../models/task_routine.dart';
import '../models/operational_cost.dart';
import '../models/whatsapp_log.dart';

class SupabaseRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // ════════════════════════════════════════════════════════
  // ROOMS
  // ════════════════════════════════════════════════════════

  Stream<List<Room>> watchRooms() {
    return _client
        .from('rooms')
        .stream(primaryKey: ['id'])
        .order('room_number')
        .map((data) => data.map((e) => Room.fromJson(e)).toList());
  }

  Future<List<Room>> getRooms() async {
    final data = await _client.from('rooms').select().order('room_number');
    return (data as List).map((e) => Room.fromJson(e)).toList();
  }

  Future<Room> addRoom(Room room) async {
    final data = await _client.from('rooms').insert({
      'room_number': room.roomNumber,
      'status': room.status,
      'monthly_rent': room.monthlyRent,
    }).select().single();
    return Room.fromJson(data);
  }

  Future<Room> updateRoom(Room room) async {
    final data = await _client.from('rooms').update({
      'room_number': room.roomNumber,
      'status': room.status,
      'monthly_rent': room.monthlyRent,
    }).eq('id', room.id).select().single();
    return Room.fromJson(data);
  }

  Future<void> deleteRoom(int id) async {
    await _client.from('rooms').delete().eq('id', id);
  }

  // ════════════════════════════════════════════════════════
  // TENANTS  (with Phase 2 auto-trigger on archive)
  // ════════════════════════════════════════════════════════

  Stream<List<Tenant>> watchTenants() {
    return _client
        .from('tenants')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data.map((e) => Tenant.fromJson(e)).toList());
  }

  Future<List<Tenant>> getTenants() async {
    final data = await _client.from('tenants').select().order('created_at', ascending: false);
    return (data as List).map((e) => Tenant.fromJson(e)).toList();
  }

  Future<List<Tenant>> getActiveTenants() async {
    final data = await _client.from('tenants').select().eq('status', 'active').order('created_at', ascending: false);
    return (data as List).map((e) => Tenant.fromJson(e)).toList();
  }

  Future<List<Tenant>> getUnpaidTenants() async {
    final data = await _client.from('tenants').select().eq('status', 'active').eq('payment_status', 'unpaid').order('due_date');
    return (data as List).map((e) => Tenant.fromJson(e)).toList();
  }

  Future<Tenant> addTenant(Tenant tenant) async {
    final data = await _client.from('tenants').insert({
      'name': tenant.name,
      'phone': tenant.phone,
      'gender': tenant.gender,
      'room_id': tenant.roomId,
      'status': tenant.status,
      'insurance_amount': tenant.insuranceAmount,
      'insurance_returned': tenant.insuranceReturned,
      'payment_status': tenant.paymentStatus,
      'due_date': tenant.dueDate?.toIso8601String().split('T').first,
    }).select().single();
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
      'status': tenant.status,
      'insurance_amount': tenant.insuranceAmount,
      'insurance_returned': tenant.insuranceReturned,
      'payment_status': tenant.paymentStatus,
      'due_date': tenant.dueDate?.toIso8601String().split('T').first,
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
    await _client.from('tenants').delete().eq('id', id);
  }

  Future<void> markTenantPaid(String id) async {
    await _client.from('tenants').update({'payment_status': 'paid'}).eq('id', id);
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

  Future<Map<String, dynamic>> getDashboardStats() async {
    final tenants = await getActiveTenants();
    final expenses = await getMasareef();
    final rooms = await getRooms();
    final opCosts = await getOperationalCosts();
    final pendingTasks = await getPendingTasks();

    final totalRentExpected =
        rooms.where((r) => r.isOccupied).fold(0.0, (sum, r) => sum + r.monthlyRent);

    final totalRentCollected =
        tenants.where((t) => t.isPaid).fold(0.0, (sum, t) {
          final room = rooms.firstWhere(
            (r) => r.id == t.roomId,
            orElse: () => Room(id: 0, roomNumber: '', status: 'void', monthlyRent: 0),
          );
          return sum + room.monthlyRent;
        });

    final totalRentDue =
        tenants.where((t) => t.isUnpaid).fold(0.0, (sum, t) {
          final room = rooms.firstWhere(
            (r) => r.id == t.roomId,
            orElse: () => Room(id: 0, roomNumber: '', status: 'void', monthlyRent: 0),
          );
          return sum + room.monthlyRent;
        });

    final paidCount = tenants.where((t) => t.isPaid).length;
    final unpaidCount = tenants.where((t) => t.isUnpaid).length;
    final totalExpenses = expenses.fold(0.0, (sum, e) => sum + e.amount);
    final totalOpCosts = opCosts.fold(0.0, (sum, c) => sum + c.amount);

    final now = DateTime.now();
    final overdueTenants = tenants.where((t) {
      if (t.isPaid) return false;
      if (t.dueDate == null) return false;
      return t.dueDate!.isBefore(now);
    }).toList();

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
      'totalRentDue': totalRentDue,
      'totalExpenses': totalExpenses,
      'totalOpCosts': totalOpCosts,
      'totalCosts': totalExpenses + totalOpCosts,
      'netBalance': totalRentCollected - totalExpenses - totalOpCosts,
      'pendingTasks': pendingTasks.length,
    };
  }
}
