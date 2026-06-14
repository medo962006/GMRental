// lib/screens/insurance_screen.dart
// Insurance Hub — financial overview + progress indicators.
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
            error: (_, __) => _buildContent(context, ref, ledgers, {}),
            data: (tenants) {
              final tenantMap = <String, Tenant>{for (final t in tenants) t.id: t};
              return _buildContent(context, ref, ledgers, tenantMap);
            },
          );
        },
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Financial Overview Banner ──
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

          // ── Section Header ──
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

          // ── Ledger Cards ──
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
              return _InsuranceCard(ledger: l, tenant: tenant);
            }),
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
}

class _InsuranceCard extends StatelessWidget {
  final InsuranceLedger ledger;
  final Tenant? tenant;
  const _InsuranceCard({required this.ledger, this.tenant});

  @override
  Widget build(BuildContext context) {
    final isOverdue = ledger.isOverdue;
    final progress = ledger.totalAgreedAmount > 0
        ? (ledger.amountPaidSoFar / ledger.totalAgreedAmount).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppDecorations.card(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: AppColors.infoBg, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.shield, size: 18, color: AppColors.accent),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tenant?.name ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (tenant != null) Text('Room ${tenant!.roomId ?? '—'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ])),
              if (isOverdue) AppBadge.unpaid(label: 'OVERDUE'),
            ]),

            const SizedBox(height: 12),

            // Progress
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${ledger.amountPaidSoFar.toStringAsFixed(0)} paid', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.successText)),
              Text('${ledger.remainingBalance.toStringAsFixed(0)} owed', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isOverdue ? AppColors.dangerText : AppColors.textSecondary)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.mutedPastel.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation(isOverdue ? AppColors.danger : AppColors.secondary),
              ),
            ),

            if (ledger.dueDateForRemaining != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.event, size: 12, color: isOverdue ? AppColors.danger : AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('Due: ${_fmt(ledger.dueDateForRemaining)}',
                    style: TextStyle(fontSize: 11, color: isOverdue ? AppColors.danger : AppColors.textSecondary, fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal)),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime? d) => d == null ? '—' : '${d.day}/${d.month}/${d.year}';
}
