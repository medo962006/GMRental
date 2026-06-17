// lib/screens/insurance_screen.dart
// Insurance Hub — per-building, auto-create, full CRUD, edit values.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_theme.dart';
import '../models/insurance_ledger.dart';
import '../models/tenant.dart';
import '../models/room.dart';
import '../providers/app_providers.dart';
import '../repositories/supabase_repository.dart';

class InsuranceScreen extends ConsumerStatefulWidget {
  const InsuranceScreen({super.key});

  @override
  ConsumerState<InsuranceScreen> createState() => _InsuranceScreenState();
}

class _InsuranceScreenState extends ConsumerState<InsuranceScreen> {
  bool _autoCreated = false;

  @override
  Widget build(BuildContext context) {
    final buildingId = ref.watch(currentBuildingIdProvider);
    final ledgersAsync = ref.watch(insuranceLedgersStreamProvider);
    final tenantsAsync = ref.watch(tenantsStreamProvider(buildingId));
    final roomsAsync = ref.watch(roomsStreamProvider(buildingId));

    return Scaffold(
      body: ledgersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allLedgers) {
          return tenantsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('Error loading tenants')),
            data: (tenants) {
              return roomsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('Error loading rooms')),
                data: (rooms) {
                  // Filter ledgers to this building's tenants
                  final tenantIds = tenants.map((t) => t.id).toSet();
                  final ledgers = allLedgers.where((l) => tenantIds.contains(l.tenantId)).toList();
                  final tenantMap = <String, Tenant>{for (final t in tenants) t.id: t};
                  final roomMap = <int, Room>{for (final r in rooms) r.id: r};

                  // Auto-create insurance ledgers for tenants that don't have one
                  _autoCreateIfNeeded(tenants, rooms, allLedgers);

                  return _buildContent(context, ref, ledgers, tenantMap, roomMap, buildingId);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Insurance'),
      ),
    );
  }

  /// Auto-create insurance ledgers for active tenants that don't have one.
  /// Amount = room rent, fully paid.
  void _autoCreateIfNeeded(List<Tenant> tenants, List<Room> rooms, List<InsuranceLedger> allLedgers) {
    if (_autoCreated) return;
    _autoCreated = true;

    final existingTenantIds = allLedgers.map((l) => l.tenantId).toSet();
    final roomMap = <int, Room>{for (final r in rooms) r.id: r};
    final repo = ref.read(supabaseRepositoryProvider);

    for (final tenant in tenants) {
      if (!tenant.isActive) continue;
      if (existingTenantIds.contains(tenant.id)) continue;
      if (tenant.roomId == null) continue;

      final room = roomMap[tenant.roomId];
      if (room == null) continue;

      final rent = tenant.insuranceAmount;
      if (rent <= 0) continue;
      // Fire and forget — don't block the UI
      repo.createInsuranceLedger(
        tenantId: tenant.id,
        totalAgreedAmount: rent,
        amountPaidSoFar: rent,
      ).catchError((_) {
        // Silent — will retry on next build if needed
      });
    }
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<InsuranceLedger> ledgers,
    Map<String, Tenant> tenantMap,
    Map<int, Room> roomMap,
    int buildingId,
  ) {
    final totalAgreed = ledgers.fold(0.0, (s, l) => s + l.totalAgreedAmount);
    final totalPaid = ledgers.fold(0.0, (s, l) => s + l.amountPaidSoFar);
    final totalOwed = ledgers.fold(0.0, (s, l) => s + l.remainingBalance);
    final withRemaining = ledgers.where((l) => l.hasRemaining).toList();
    final overdueCount = withRemaining.where((l) => l.isOverdue).length;
    final paid = ledgers.where((l) => l.status == 'fully_paid' || !l.hasRemaining).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Building indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Building: ${buildingId == 1 ? "Gawy" : "Baraka"}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.secondary),
            ),
          ),
          const SizedBox(height: 16),

          // Financial Overview
          Container(
            decoration: AppDecorations.card(context),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Insurance Overview',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(height: 16),
                Row(children: [
                  _finCol('Total Agreed', totalAgreed, AppColors.primary),
                  const SizedBox(width: 16),
                  _finCol('Collected', totalPaid, AppColors.success),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  _finCol('Outstanding', totalOwed, AppColors.danger),
                  const SizedBox(width: 16),
                  _finCol('Overdue', overdueCount.toDouble(), AppColors.warning, isCount: true),
                ]),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Active Balances',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
              if (overdueCount > 0)
                AppBadge.unpaid(label: '$overdueCount overdue'),
            ],
          ),
          const SizedBox(height: 12),

          // Ledger cards
          if (withRemaining.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(children: [
                  Icon(Icons.check_circle, size: 48, color: AppColors.success),
                  SizedBox(height: 8),
                  Text('All insurance settled', style: TextStyle(color: AppColors.textSecondary)),
                ]),
              ),
            )
          else
            ...withRemaining.map((l) {
              final tenant = tenantMap[l.tenantId];
              return _InsuranceCard(
                ledger: l,
                tenant: tenant,
                roomDisplay: tenant?.roomId != null
                    ? (roomMap[tenant!.roomId]?.displayRoomNumber ?? '${tenant!.roomId}')
                    : '—',
                onCollect: () => _showCollectPayment(context, ref, l),
                onRefund: () => _showRefund(context, ref, l),
                onEdit: () => _showEdit(context, ref, l),
                onDelete: () => _confirmDelete(context, ref, l),
              );
            }),

          // Fully paid section
          if (paid.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Settled',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
            const SizedBox(height: 12),
            ...paid.map((l) {
              final tenant = tenantMap[l.tenantId];
              return _InsuranceCard(
                ledger: l,
                tenant: tenant,
                roomDisplay: tenant?.roomId != null
                    ? (roomMap[tenant!.roomId]?.displayRoomNumber ?? '${tenant!.roomId}')
                    : '—',
                isSettled: true,
                onEdit: () => _showEdit(context, ref, l),
                onDelete: () => _confirmDelete(context, ref, l),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _finCol(String label, double value, Color color, {bool isCount = false}) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(isCount ? '${value.toInt()}' : '${value.toStringAsFixed(0)} LE',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  // ── Create Insurance ──────────────────────────────
  void _showCreateForm(BuildContext ctx, WidgetRef ref) {
    showDialog(
      context: ctx,
      builder: (dCtx) => _InsuranceCreateForm(onCreated: () {
        ref.invalidate(insuranceLedgersStreamProvider);
      }),
    );
  }

  // ── Collect Payment ───────────────────────────────
  void _showCollectPayment(BuildContext ctx, WidgetRef ref, InsuranceLedger ledger) {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Collect Payment'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Remaining: ${ledger.remainingBalance.toStringAsFixed(0)} LE',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 12),
          TextField(
            controller: amountCtrl,
            decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesCtrl,
            decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              if (amount <= 0) return;
              try {
                await ref.read(supabaseRepositoryProvider).collectInsurancePayment(
                  insuranceId: ledger.id,
                  amount: amount,
                  notes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
                );
                if (dCtx.mounted) Navigator.pop(dCtx);
                ref.invalidate(insuranceLedgersStreamProvider);
              } catch (e) {
                if (dCtx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Collect'),
          ),
        ],
      ),
    );
  }

  // ── Edit Insurance ────────────────────────────────
  void _showEdit(BuildContext ctx, WidgetRef ref, InsuranceLedger ledger) {
    final agreedCtrl = TextEditingController(text: ledger.totalAgreedAmount.toStringAsFixed(0));
    final paidCtrl = TextEditingController(text: ledger.amountPaidSoFar.toStringAsFixed(0));

    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Edit Insurance'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: agreedCtrl,
            decoration: const InputDecoration(
              labelText: 'Total Agreed Amount (LE)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: paidCtrl,
            decoration: const InputDecoration(
              labelText: 'Amount Paid So Far (LE)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          Text(
            'Remaining will auto-calculate: agreed − paid',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final agreed = double.tryParse(agreedCtrl.text) ?? 0;
              final paid = double.tryParse(paidCtrl.text) ?? 0;
              if (agreed <= 0) return;
              try {
                await ref.read(supabaseRepositoryProvider).updateInsuranceLedger(
                  id: ledger.id,
                  totalAgreedAmount: agreed,
                  amountPaidSoFar: paid,
                );
                if (dCtx.mounted) Navigator.pop(dCtx);
                ref.invalidate(insuranceLedgersStreamProvider);
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Insurance updated')),
                  );
                }
              } catch (e) {
                if (dCtx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ── Refund ────────────────────────────────────────
  void _showRefund(BuildContext ctx, WidgetRef ref, InsuranceLedger ledger) {
    final refundCtrl = TextEditingController(text: ledger.amountPaidSoFar.toString());
    final deductCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Process Refund'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Paid so far: ${ledger.amountPaidSoFar.toStringAsFixed(0)} LE',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 12),
          TextField(
            controller: refundCtrl,
            decoration: const InputDecoration(labelText: 'Refund Amount', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: deductCtrl,
            decoration: const InputDecoration(labelText: 'Deduction (if any)', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesCtrl,
            decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final refund = double.tryParse(refundCtrl.text) ?? 0;
              final deduct = double.tryParse(deductCtrl.text) ?? 0;
              if (refund <= 0) return;
              try {
                await ref.read(supabaseRepositoryProvider).processInsuranceRefund(
                  insuranceId: ledger.id,
                  refundAmount: refund,
                  deductionAmount: deduct,
                  deductionNotes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
                );
                if (dCtx.mounted) Navigator.pop(dCtx);
                ref.invalidate(insuranceLedgersStreamProvider);
              } catch (e) {
                if (dCtx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Process'),
          ),
        ],
      ),
    );
  }

  // ── Delete ────────────────────────────────────────
  void _confirmDelete(BuildContext ctx, WidgetRef ref, InsuranceLedger ledger) {
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Delete Insurance Record'),
        content: const Text('This will permanently delete this insurance record and all its transactions. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              try {
                await ref.read(supabaseRepositoryProvider).deleteInsuranceLedger(ledger.id);
                if (dCtx.mounted) Navigator.pop(dCtx);
                ref.invalidate(insuranceLedgersStreamProvider);
              } catch (e) {
                if (dCtx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// INSURANCE CARD
// ════════════════════════════════════════════════════════

class _InsuranceCard extends StatelessWidget {
  final InsuranceLedger ledger;
  final Tenant? tenant;
  final String roomDisplay;
  final VoidCallback? onCollect;
  final VoidCallback? onRefund;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isSettled;

  const _InsuranceCard({
    required this.ledger,
    this.tenant,
    this.roomDisplay = '—',
    this.onCollect,
    this.onRefund,
    this.onEdit,
    this.onDelete,
    this.isSettled = false,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = ledger.isOverdue;
    final progress = ledger.totalAgreedAmount > 0
        ? (ledger.amountPaidSoFar / ledger.totalAgreedAmount).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppDecorations.card(context),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (ctx) => Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Handle
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                Text(tenant?.name ?? 'Unknown',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Room $roomDisplay',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 12),

                // Details
                _detailRow('Agreed', '${ledger.totalAgreedAmount.toStringAsFixed(0)} LE'),
                _detailRow('Paid', '${ledger.amountPaidSoFar.toStringAsFixed(0)} LE'),
                _detailRow('Remaining', '${ledger.remainingBalance.toStringAsFixed(0)} LE'),
                _detailRow('Status', ledger.status),
                if (ledger.dueDateForRemaining != null)
                  _detailRow('Due', _fmt(ledger.dueDateForRemaining)),

                const SizedBox(height: 16),

                // Action buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if (onEdit != null)
                      ElevatedButton.icon(
                        onPressed: () { Navigator.pop(ctx); onEdit!(); },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                      ),
                    if (!isSettled && onCollect != null)
                      ElevatedButton.icon(
                        onPressed: () { Navigator.pop(ctx); onCollect!(); },
                        icon: const Icon(Icons.payments, size: 18),
                        label: const Text('Collect'),
                      ),
                    if (!isSettled && onRefund != null)
                      ElevatedButton.icon(
                        onPressed: () { Navigator.pop(ctx); onRefund!(); },
                        icon: const Icon(Icons.replay, size: 18),
                        label: const Text('Refund'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warning, foregroundColor: Colors.white),
                      ),
                    if (onDelete != null)
                      TextButton.icon(
                        onPressed: () { Navigator.pop(ctx); onDelete!(); },
                        icon: const Icon(Icons.delete, color: AppColors.danger),
                        label: const Text('Delete', style: TextStyle(color: AppColors.danger)),
                      ),
                  ],
                ),
              ]),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: isSettled ? AppColors.successBg : AppColors.infoBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isSettled ? Icons.check_circle : Icons.shield,
                    size: 18,
                    color: isSettled ? AppColors.success : AppColors.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tenant?.name ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text('Room $roomDisplay',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ])),
                if (isSettled)
                  AppBadge.paid(label: 'Settled')
                else if (isOverdue)
                  AppBadge.unpaid(label: 'OVERDUE')
                else
                  AppBadge.partial(label: ledger.status),
              ]),

              const SizedBox(height: 12),

              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${ledger.amountPaidSoFar.toStringAsFixed(0)} paid',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.successText)),
                Text('${ledger.remainingBalance.toStringAsFixed(0)} owed',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: isOverdue ? AppColors.dangerText : AppColors.textSecondary)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppColors.mutedPastel.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation(
                      isSettled ? AppColors.success : (isOverdue ? AppColors.danger : AppColors.secondary)),
                ),
              ),

              if (ledger.dueDateForRemaining != null && !isSettled) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.event, size: 12, color: isOverdue ? AppColors.danger : AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('Due: ${_fmt(ledger.dueDateForRemaining)}',
                      style: TextStyle(fontSize: 11,
                          color: isOverdue ? AppColors.danger : AppColors.textSecondary,
                          fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal)),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  String _fmt(DateTime? d) => d == null ? '—' : '${d.day}/${d.month}/${d.year}';
}

// ════════════════════════════════════════════════════════
// CREATE INSURANCE FORM
// ════════════════════════════════════════════════════════

class _InsuranceCreateForm extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _InsuranceCreateForm({required this.onCreated});

  @override
  ConsumerState<_InsuranceCreateForm> createState() => _InsuranceCreateFormState();
}

class _InsuranceCreateFormState extends ConsumerState<_InsuranceCreateForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _dueDateCtrl = TextEditingController();
  Tenant? _selectedTenant;
  DateTime? _dueDate;

  @override
  Widget build(BuildContext context) {
    final buildingId = ref.watch(currentBuildingIdProvider);
    final tenantsAsync = ref.watch(tenantsFutureProvider(buildingId));

    return AlertDialog(
      title: const Text('Create Insurance Record'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            tenantsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('Error loading tenants'),
              data: (tenants) {
                final active = tenants.where((t) => t.isActive).toList();
                return DropdownButtonFormField<Tenant>(
                  value: _selectedTenant,
                  decoration: const InputDecoration(labelText: 'Tenant', border: OutlineInputBorder()),
                  items: active.map((t) => DropdownMenuItem(
                    value: t,
                    child: Text('${t.name} (Room ${t.roomId ?? '—'})'),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedTenant = v),
                  validator: (v) => v == null ? 'Select a tenant' : null,
                );
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountCtrl,
              decoration: const InputDecoration(labelText: 'Total Agreed Amount (LE)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter valid amount' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dueDateCtrl,
              decoration: const InputDecoration(
                labelText: 'Due Date (optional)',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) {
                  setState(() {
                    _dueDate = d;
                    _dueDateCtrl.text = '${d.day}/${d.month}/${d.year}';
                  });
                }
              },
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            if (_selectedTenant == null) return;

            try {
              await ref.read(supabaseRepositoryProvider).createInsuranceLedger(
                tenantId: _selectedTenant!.id,
                totalAgreedAmount: double.parse(_amountCtrl.text),
                dueDateForRemaining: _dueDate,
              );
              if (mounted) {
                Navigator.pop(context);
                widget.onCreated();
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
