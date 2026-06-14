// lib/screens/insurance_screen.dart
// Phase 3.7: Ta2meen (Insurance) Hub — mobile-first.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/insurance_ledger.dart';
import '../models/tenant.dart';
import '../providers/app_providers.dart';
import '../repositories/supabase_repository.dart';

class InsuranceScreen extends ConsumerWidget {
  const InsuranceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgersAsync = ref.watch(insuranceLedgersFutureProvider);
    final tenantsAsync = ref.watch(tenantsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ta2meen — Insurance'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: ledgersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (ledgers) {
          return tenantsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _buildList(context, ref, ledgers, {}),
            data: (tenants) {
              final tenantMap = <String, Tenant>{
                for (final t in tenants) t.id: t
              };
              return _buildList(context, ref, ledgers, tenantMap);
            },
          );
        },
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref,
      List<InsuranceLedger> ledgers, Map<String, Tenant> tenantMap) {
    final withRemaining =
        ledgers.where((l) => l.hasRemaining).toList();

    if (withRemaining.isEmpty) {
      return const Center(
        child: Text('All insurance settled. Nothing pending.',
            style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: withRemaining.length,
      itemBuilder: (_, i) {
        final ledger = withRemaining[i];
        final tenant = tenantMap[ledger.tenantId];
        return _buildInsuranceCard(context, ref, ledger, tenant);
      },
    );
  }

  Widget _buildInsuranceCard(BuildContext context, WidgetRef ref,
      InsuranceLedger ledger, Tenant? tenant) {
    final theme = Theme.of(context);
    final isOverdue = ledger.isOverdue;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isOverdue ? 3 : 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: tenant name + overdue badge
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tenant?.name ?? 'Unknown Tenant',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      if (tenant != null)
                        Text('Room ${tenant.roomId ?? '-'}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                if (isOverdue)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: const Text('OVERDUE',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.red,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Amounts row
            Row(
              children: [
                _amountChip('Total', ledger.totalAgreedAmount, Colors.blue),
                const SizedBox(width: 8),
                _amountChip('Paid', ledger.amountPaidSoFar, Colors.green),
                const SizedBox(width: 8),
                _amountChip(
                    'Owed', ledger.remainingBalance, Colors.red),
              ],
            ),

            if (ledger.dueDateForRemaining != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.event,
                      size: 14,
                      color: isOverdue ? Colors.red : Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Due: ${_fmtDate(ledger.dueDateForRemaining)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isOverdue ? Colors.red : Colors.grey,
                      fontWeight:
                          isOverdue ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showCollectDialog(context, ref, ledger),
                    icon: const Icon(Icons.payments, size: 16),
                    label: const Text('Collect',
                        style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _showRefundDialog(
                        context, ref, ledger, tenant),
                    icon: const Icon(Icons.replay, size: 16),
                    label: const Text('Refund',
                        style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountChip(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${amount.toStringAsFixed(0)} LE',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, color: color)),
        Text(label, style: TextStyle(fontSize: 10, color: color)),
      ]),
    );
  }

  void _showCollectDialog(
      BuildContext context, WidgetRef ref, InsuranceLedger ledger) {
    final ctrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Collect Insurance Payment'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Remaining: ${ledger.remainingBalance.toStringAsFixed(0)} LE',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            decoration: const InputDecoration(
                labelText: 'Amount (LE)', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: notesCtrl,
            decoration: const InputDecoration(
                labelText: 'Notes (optional)', border: OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(ctrl.text.trim());
              if (amount == null || amount <= 0) return;
              try {
                await ref
                    .read(supabaseRepositoryProvider)
                    .collectInsurancePayment(
                      insuranceId: ledger.id,
                      amount: amount,
                      notes:
                          notesCtrl.text.trim().isNotEmpty
                              ? notesCtrl.text.trim()
                              : null,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
                ref.invalidate(insuranceLedgersFutureProvider);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Collect'),
          ),
        ],
      ),
    );
  }

  void _showRefundDialog(BuildContext context, WidgetRef ref,
      InsuranceLedger ledger, Tenant? tenant) {
    final refundCtrl = TextEditingController(
        text: ledger.remainingBalance.toStringAsFixed(0));
    final deductCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Refund — ${tenant?.name ?? 'Tenant'}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                  'Total paid: ${ledger.amountPaidSoFar.toStringAsFixed(0)} LE',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: refundCtrl,
                decoration: const InputDecoration(
                    labelText: 'Refund Amount (LE)',
                    border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: deductCtrl,
                decoration: const InputDecoration(
                    labelText: 'Deduction (LE, optional)',
                    border: OutlineInputBorder(),
                    helperText: 'e.g., damage to room'),
                keyboardType: TextInputType.number,
                onChanged: (_) => setDialogState(() {}),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                    labelText: 'Deduction Notes',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              // Show net refund
              Builder(builder: (context) {
                final refund =
                    double.tryParse(refundCtrl.text) ?? 0;
                final deduct =
                    double.tryParse(deductCtrl.text) ?? 0;
                final net = refund - deduct;
                return Text(
                  'Net refund: ${net.toStringAsFixed(0)} LE',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: net < 0 ? Colors.red : Colors.green,
                  ),
                );
              }),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final refund =
                    double.tryParse(refundCtrl.text) ?? 0;
                final deduct =
                    double.tryParse(deductCtrl.text) ?? 0;
                if (refund <= 0) return;
                try {
                  await ref
                      .read(supabaseRepositoryProvider)
                      .processInsuranceRefund(
                        insuranceId: ledger.id,
                        refundAmount: refund,
                        deductionAmount: deduct,
                        deductionNotes:
                            notesCtrl.text.trim().isNotEmpty
                                ? notesCtrl.text.trim()
                                : null,
                        roomId: tenant?.roomId,
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                  ref.invalidate(insuranceLedgersFutureProvider);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Process Refund'),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '-';
    return '${d.day}/${d.month}/${d.year}';
  }
}
