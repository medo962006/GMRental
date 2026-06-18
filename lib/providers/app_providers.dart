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
import '../models/insurance_transaction.dart';
import '../models/admin_notification.dart';
import '../models/changelog_entry.dart';
import '../models/device_code.dart';
import '../models/reception_history.dart';

// ── Repository ──────────────────────────────────────

final supabaseRepositoryProvider = Provider<SupabaseRepository>((ref) {
  return SupabaseRepository();
});

// ── Navigation ──────────────────────────────────────

final selectedIndexProvider = StateProvider<int>((ref) => 0);

// ── Building Selection ──────────────────────────────
// Building 1 = Main, Building 2 = Baraka
final currentBuildingIdProvider = StateProvider<int>((ref) => 1);

// ── Rooms (building-aware) ──────────────────────────

final roomsStreamProvider = StreamProvider.family<List<Room>, int>((ref, buildingId) {
  return ref.watch(supabaseRepositoryProvider).watchRooms(buildingId: buildingId);
});

final roomsFutureProvider = FutureProvider.family<List<Room>, int>((ref, buildingId) {
  return ref.watch(supabaseRepositoryProvider).getRooms(buildingId: buildingId);
});

// ── Tenants (building-aware) ────────────────────────

final tenantsStreamProvider = StreamProvider.family<List<Tenant>, int>((ref, buildingId) {
  return ref.watch(supabaseRepositoryProvider).watchTenants(buildingId: buildingId);
});

final tenantsFutureProvider = FutureProvider.family<List<Tenant>, int>((ref, buildingId) {
  return ref.watch(supabaseRepositoryProvider).getTenants(buildingId: buildingId);
});

final unpaidTenantsProvider = FutureProvider.family<List<Tenant>, int>((ref, buildingId) {
  return ref.watch(supabaseRepositoryProvider).getUnpaidTenants(buildingId: buildingId);
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

// ── Reception History ───────────────────────────────

final receptionHistoryStreamProvider =
    StreamProvider.family<List<ReceptionHistory>, int>((ref, buildingId) {
  return ref
      .watch(supabaseRepositoryProvider)
      .watchReceptionHistory(buildingId: buildingId);
});

// ── Dashboard ───────────────────────────────────────

final dashboardStatsProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, buildingId) {
  return ref.watch(supabaseRepositoryProvider).getDashboardStats(buildingId: buildingId);
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

// ── Changelog ──────────────────────────────────────────

final changelogStreamProvider =
    StreamProvider.family<List<ChangelogEntry>, int?>((ref, buildingId) {
  return ref.watch(supabaseRepositoryProvider).watchChangelog(buildingId: buildingId);
});

final changelogFutureProvider =
    FutureProvider.family<List<ChangelogEntry>, int?>((ref, buildingId) {
  return ref.watch(supabaseRepositoryProvider).getChangelog(buildingId: buildingId);
});
