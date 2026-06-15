// lib/screens/insurance_screen.dart
// Insurance Hub — full CRUD: add, collect payment, refund, delete.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_theme.dart';
import '../models/insurance_ledger.dart';
import '../models/tenant.dart';
import '../providers/app_providers.dart';
import '../repositories/supabase_repository.dart';

class InsuranceScreen extends ConsumerWidget {
  const InsuranceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgersAsync = ref.watch(insuranceLedgersStreamProvider);
    final tenantsAsync = ref.watch(tenantsStreamProvider(1)); // all tenants

    return Scaffold(
      body: ledgersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (ledgers) {
          return tenantsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _buildContent(context, ref, ledgers, {}),
            data: (tenants) {
              final tenantMap = <String, Tenant>{for (final t in tenants) t.id: t};
              return _buildContent(context, ref, ledgers, tenantMap);
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

  Widget _buildContent(BuildContext context, WidgetRef ref,
      List<InsuranceLedger> ledgers, Map<String, Tenant> tenantMap) {
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
                onCollect: () => _showCollectPayment(context, ref, l),
                onRefund: () => _showRefund(context, ref, l),
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
                isSettled: true,
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
  final VoidCallback? onCollect;
  final VoidCallback? onRefund;
  final VoidCallback? onDelete;
  final bool isSettled;

  const _InsuranceCard({
    required this.ledger,
    this.tenant,
    this.onCollect,
    this.onRefund,
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
          // Show detail / actions
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
                Text(tenant?.name ?? 'Unknown', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Agreed: ${ledger.totalAgreedAmount.toStringAsFixed(0)} LE'),
                Text('Paid: ${ledger.amountPaidSoFar.toStringAsFixed(0)} LE'),
                Text('Remaining: ${ledger.remainingBalance.toStringAsFixed(0)} LE'),
                Text('Status: ${ledger.status}'),
                if (ledger.dueDateForRemaining != null)
                  Text('Due: ${ledger.dueDateForRemaining!.day}/${ledger.dueDateForRemaining!.month}/${ledger.dueDateForRemaining!.year}'),
                const SizedBox(height: 16),
                if (!isSettled) ...[
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    if (onCollect != null)
                      ElevatedButton.icon(
                        onPressed: () { Navigator.pop(ctx); onCollect!(); },
                        icon: const Icon(Icons.payments, size: 18),
                        label: const Text('Collect'),
                      ),
                    if (onRefund != null)
                      ElevatedButton.icon(
                        onPressed: () { Navigator.pop(ctx); onRefund!(); },
                        icon: const Icon(Icons.replay, size: 18),
                        label: const Text('Refund'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, foregroundColor: Colors.white),
                      ),
                  ]),
                  const SizedBox(height: 8),
                ],
                if (onDelete != null)
                  TextButton.icon(
                    onPressed: () { Navigator.pop(ctx); onDelete!(); },
                    icon: const Icon(Icons.delete, color: AppColors.danger),
                    label: const Text('Delete Record', style: TextStyle(color: AppColors.danger)),
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
                  Text(tenant?.name ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  if (tenant != null)
                    Text('Room ${tenant!.roomId ?? '—'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
    final tenantsAsync = ref.watch(tenantsFutureProvider(1));

    return AlertDialog(
      title: const Text('Create Insurance Record'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Tenant selector
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
