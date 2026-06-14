// lib/screens/insurance_screen.dart
// Phase 3.7: Ta2meen Hub — design system overhaul with progress indicators.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_theme.dart';
import '../models/insurance_ledger.dart';
import '../models/tenant.dart';
import '../providers/app_providers.dart';

class InsuranceScreen extends ConsumerWidget {
  const InsuranceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgersAsync = ref.watch(insuranceLedgersFutureProvider);
    final tenantsAsync = ref.watch(tenantsStreamProvider);

    return Scaffold(
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
    final withRemaining = ledgers.where((l) => l.hasRemaining).toList();

    if (withRemaining.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 48, color: AppColors.success),
            SizedBox(height: 12),
            Text('All insurance settled',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: withRemaining.length,
      itemBuilder: (_, i) {
        final ledger = withRemaining[i];
        final tenant = tenantMap[ledger.tenantId];
        return _InsuranceCard(ledger: ledger, tenant: tenant, ref: ref);
      },
    );
  }
}

class _InsuranceCard extends StatelessWidget {
  final InsuranceLedger ledger;
  final Tenant? tenant;
  final WidgetRef ref;

  const _InsuranceCard({required this.ledger, this.tenant, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isOverdue = ledger.isOverdue;
    final progress = ledger.totalAgreedAmount > 0
        ? ledger.amountPaidSoFar / ledger.totalAgreedAmount
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppDecorations.card(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: name + overdue badge
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.infoBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shield, color: AppColors.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tenant?.name ?? 'Unknown',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: AppColors.neutralDark)),
                      if (tenant != null)
                        Text('Room ${tenant!.roomId ?? '—'}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (isOverdue)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.dangerBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('OVERDUE',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.dangerText)),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${ledger.amountPaidSoFar.toStringAsFixed(0)} LE paid',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.successText)),
                    Text('${ledger.remainingBalance.toStringAsFixed(0)} LE owed',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isOverdue ? AppColors.dangerText : AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: AppColors.mutedPastel.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        isOverdue ? AppColors.danger : AppColors.secondary),
                  ),
                ),
              ],
            ),

            if (ledger.dueDateForRemaining != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.event, size: 14,
                      color: isOverdue ? AppColors.danger : AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('Due: ${_fmtDate(ledger.dueDateForRemaining)}',
                      style: TextStyle(
                          fontSize: 12,
                          color: isOverdue ? AppColors.danger : AppColors.textSecondary,
                          fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal)),
                ],
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showCollectDialog(ref, ledger),
                    icon: const Icon(Icons.payments, size: 16),
                    label: const Text('Collect', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _showRefundDialog(ref, ledger, tenant),
                    icon: const Icon(Icons.replay, size: 16),
                    label: const Text('Refund', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCollectDialog(WidgetRef ref, InsuranceLedger ledger) {
    final ctrl = TextEditingController();
    // Dialog implementation — simplified
  }

  void _showRefundDialog(WidgetRef ref, InsuranceLedger ledger, Tenant? tenant) {
    final refundCtrl = TextEditingController(text: ledger.remainingBalance.toStringAsFixed(0));
    final deductCtrl = TextEditingController();
    // Dialog implementation — simplified
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day}/${d.month}/${d.year}';
  }
}
