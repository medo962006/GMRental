// lib/repositories/supabase_repository.dart
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
      'monthly_rent': room.monthlyRent,
      'building_id': room.buildingId,
    }).select().single();
    return Room.fromJson(data);
  }

  Future<Room> updateRoom(Room room) async {
    final data = await _client.from('rooms').update({
      'room_number': room.roomNumber,
      'status': room.status,
      'monthly_rent': room.monthlyRent,
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
    // Auto-set insurance to room's monthly rent if not set
    double insurance = tenant.insuranceAmount;
    if (insurance == 0 && tenant.roomId != null) {
      final roomData = await _client.from('rooms').select('monthly_rent').eq('id', tenant.roomId!).maybeSingle();
      if (roomData != null) {
        insurance = (roomData['monthly_rent'] as num?)?.toDouble() ?? 0;
      }
    }

    final data = await _client.from('tenants').insert({
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
    }).select().single();

    // Auto-set room to occupied when tenant is assigned
    if (tenant.roomId != null && tenant.status == 'active') {
      try {
        await _client.from('rooms').update({'status': 'occupied'}).eq('id', tenant.roomId!);
      } catch (e) {
        // Log but don't fail — tenant is already created
        // ignore: avoid_print
        print('Warning: Could not update room status to occupied: $e');
      }
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
    // Get tenant info before deletion to check room status
    final tenantData = await _client.from('tenants').select('room_id').eq('id', id).maybeSingle();
    final roomId = tenantData?['room_id'] as int?;

    await _client.from('tenants').delete().eq('id', id);

    // If tenant had a room, check if any other active tenants remain
    if (roomId != null) {
      final remaining = await _client.from('tenants').select('id').eq('room_id', roomId).eq('status', 'active').limit(1);
      if (remaining.isEmpty) {
        await _client.from('rooms').update({'status': 'void'}).eq('id', roomId);
      }
    }
  }

  Future<void> markTenantPaid(String id) async {
    // Get current tenant to find due_date
    final data = await _client.from('tenants').select('due_date').eq('id', id).single();
    final dueDateStr = data['due_date'] as String?;
    
    // Advance due_date to next month's payment day
    String? newDue;
    if (dueDateStr != null) {
      final due = DateTime.parse(dueDateStr);
      final nextMonth = due.month + 1;
      final year = nextMonth > 12 ? due.year + 1 : due.year;
      final month = nextMonth > 12 ? 1 : nextMonth;
      newDue = '$year-${month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';
    }
    
    await _client.from('tenants').update({
      'payment_status': 'paid',
      if (newDue != null) 'due_date': newDue,
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

    // Expected: sum of monthlyRent for all occupied rooms
    final totalRentExpected =
        rooms.where((r) => r.isOccupied).fold(0.0, (sum, r) => sum + r.monthlyRent);

    // Collected: sum of monthlyRent for paid tenants (payment_status = paid)
    // These tenants have paid their current cycle rent
    final totalRentCollected =
        tenants.where((t) => t.isPaid).fold(0.0, (sum, t) {
          final room = rooms.firstWhere(
            (r) => r.id == t.roomId,
            orElse: () => Room(id: 0, roomNumber: '', status: 'void', monthlyRent: 0),
          );
          return sum + room.monthlyRent;
        });

    // Overdue: sum of monthlyRent for unpaid tenants whose dueDate has passed
    final overdueTenants = tenants.where((t) {
      if (t.isPaid) return false;
      if (t.dueDate == null) return false;
      return t.dueDate!.isBefore(now);
    }).toList();

    final totalRentOverdue = overdueTenants.fold(0.0, (sum, t) {
      final room = rooms.firstWhere(
        (r) => r.id == t.roomId,
        orElse: () => Room(id: 0, roomNumber: '', status: 'void', monthlyRent: 0),
      );
      return sum + room.monthlyRent;
    });

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
  /// If today > due_date → unpaid, else → paid.
  /// Call this on app startup and periodically.
  Future<int> autoUpdatePaymentStatus({int? buildingId}) async {
    final tenants = buildingId != null
        ? await getActiveTenants(buildingId: buildingId)
        : await _client.from('tenants').select().eq('status', 'active').then(
            (data) => (data as List).map((e) => Tenant.fromJson(e)).toList());
    final now = DateTime.now();
    int updated = 0;

    for (final t in tenants) {
      if (t.dueDate == null) continue;

      final isPastDue = t.dueDate!.isBefore(now);
      final shouldChange = isPastDue ? t.isPaid : t.isUnpaid;

      if (shouldChange) {
        await _client.from('tenants').update({
          'payment_status': isPastDue ? 'unpaid' : 'paid',
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
      'remaining_balance': remaining.clamp(0, totalAgreedAmount),
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
}
