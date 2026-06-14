// lib/providers/app_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/supabase_repository.dart';
import '../models/room.dart';
import '../models/tenant.dart';
import '../models/masareef.dart';
import '../models/task_routine.dart';
import '../models/operational_cost.dart';
import '../models/whatsapp_log.dart';
import '../models/insurance_ledger.dart';
import '../models/admin_notification.dart';

// ── Repository ──────────────────────────────────────

final supabaseRepositoryProvider = Provider<SupabaseRepository>((ref) {
  return SupabaseRepository();
});

// ── Navigation ──────────────────────────────────────

final selectedIndexProvider = StateProvider<int>((ref) => 0);

// ── Building Selection ──────────────────────────────
// Building 1 = Main (Supabase), Building 2 = Second (local data)
final currentBuildingIdProvider = StateProvider<int>((ref) => 1);

// ── Rooms ───────────────────────────────────────────

final roomsStreamProvider = StreamProvider<List<Room>>((ref) {
  return ref.watch(supabaseRepositoryProvider).watchRooms();
});

final roomsFutureProvider = FutureProvider<List<Room>>((ref) {
  return ref.watch(supabaseRepositoryProvider).getRooms();
});

// ── Tenants ─────────────────────────────────────────

final tenantsStreamProvider = StreamProvider<List<Tenant>>((ref) {
  return ref.watch(supabaseRepositoryProvider).watchTenants();
});

final tenantsFutureProvider = FutureProvider<List<Tenant>>((ref) {
  return ref.watch(supabaseRepositoryProvider).getTenants();
});

final unpaidTenantsProvider = FutureProvider<List<Tenant>>((ref) {
  return ref.watch(supabaseRepositoryProvider).getUnpaidTenants();
});

// ── Masareef ────────────────────────────────────────

final masareefStreamProvider = StreamProvider<List<Masareef>>((ref) {
  return ref.watch(supabaseRepositoryProvider).watchMasareef();
});

final masareefFutureProvider = FutureProvider<List<Masareef>>((ref) {
  return ref.watch(supabaseRepositoryProvider).getMasareef();
});

// ── Phase 2: Task Routines ──────────────────────────

final taskRoutinesStreamProvider = StreamProvider<List<TaskRoutine>>((ref) {
  return ref.watch(supabaseRepositoryProvider).watchTaskRoutines();
});

final taskRoutinesFutureProvider = FutureProvider<List<TaskRoutine>>((ref) {
  return ref.watch(supabaseRepositoryProvider).getTaskRoutines();
});

final pendingTasksProvider = FutureProvider<List<TaskRoutine>>((ref) {
  return ref.watch(supabaseRepositoryProvider).getPendingTasks();
});

// ── Phase 2: Operational Costs ──────────────────────

final operationalCostsStreamProvider = StreamProvider<List<OperationalCost>>((ref) {
  return ref.watch(supabaseRepositoryProvider).watchOperationalCosts();
});

final operationalCostsFutureProvider = FutureProvider<List<OperationalCost>>((ref) {
  return ref.watch(supabaseRepositoryProvider).getOperationalCosts();
});

// ── Phase 3: WhatsApp Logs ──────────────────────────

final whatsAppLogsStreamProvider = StreamProvider<List<WhatsAppLog>>((ref) {
  return ref.watch(supabaseRepositoryProvider).watchWhatsAppLogs();
});

final whatsAppLogsFutureProvider = FutureProvider<List<WhatsAppLog>>((ref) {
  return ref.watch(supabaseRepositoryProvider).getWhatsAppLogs();
});

// ── Dashboard ───────────────────────────────────────

final dashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(supabaseRepositoryProvider).getDashboardStats();
});

// ── Phase 3.7: Insurance Ledger ─────────────────────

final insuranceLedgersStreamProvider =
    StreamProvider<List<InsuranceLedger>>((ref) {
  return ref.watch(supabaseRepositoryProvider).watchInsuranceLedgers();
});

final insuranceLedgersFutureProvider =
    FutureProvider<List<InsuranceLedger>>((ref) {
  return ref.watch(supabaseRepositoryProvider).getInsuranceLedgers();
});

// ── Phase 3.7: Admin Notifications ──────────────────

final adminNotificationsStreamProvider =
    StreamProvider<List<AdminNotification>>((ref) {
  return ref.watch(supabaseRepositoryProvider).watchAdminNotifications();
});

final adminNotificationsFutureProvider =
    FutureProvider<List<AdminNotification>>((ref) {
  return ref.watch(supabaseRepositoryProvider).getAdminNotifications();
});
