// lib/screens/operational_costs_screen.dart
// Phase 3.7: Op. Costs — design system overhaul.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_theme.dart';
import '../models/operational_cost.dart';
import '../providers/app_providers.dart';
import '../services/auth_guard.dart';
import '../models/operational_cost.dart';

class OperationalCostsScreen extends ConsumerWidget {
  const OperationalCostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final costsAsync = ref.watch(operationalCostsStreamProvider);

    return Scaffold(
      body: costsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (costs) {
          final total = costs.fold(0.0, (s, c) => s + c.amount);
          final salary = costs.where((c) => c.isSalary).fold(0.0, (s, c) => s + c.amount);
          final ads = costs.where((c) => c.isAdSpend).fold(0.0, (s, c) => s + c.amount);
          final subs = costs.where((c) => c.isSubscription).fold(0.0, (s, c) => s + c.amount);

          return Column(
            children: [
              // Summary banner
              Container(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _summaryChip('Total', total, AppColors.primary, Icons.account_balance),
                    const SizedBox(width: 8),
                    _summaryChip('Salaries', salary, AppColors.secondary, Icons.people),
                    const SizedBox(width: 8),
                    _summaryChip('Ad Spend', ads, AppColors.warning, Icons.campaign),
                    const SizedBox(width: 8),
                    _summaryChip('Subs', subs, AppColors.success, Icons.subscriptions),
                  ]),
                ),
              ),
              const Divider(height: 1),
              // Cost list
              Expanded(
                child: costs.isEmpty
                    ? const Center(
                        child: Text('No operational costs recorded',
                            style: TextStyle(color: AppColors.textSecondary)))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        itemCount: costs.length,
                        itemBuilder: (_, i) => _CostCard(cost: costs[i]),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String costType = 'other';
    DateTime billingDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Operational Cost'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Electricity bill',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                decoration: const InputDecoration(
                  labelText: 'Amount (LE)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: costType,
                decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'salary', child: Text('Salary')),
                  DropdownMenuItem(value: 'ad_spend', child: Text('Ad Spend')),
                  DropdownMenuItem(value: 'subscription', child: Text('Subscription')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setDialogState(() => costType = v!),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: billingDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setDialogState(() => billingDate = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Billing Date', border: OutlineInputBorder()),
                  child: Text('${billingDate.year}-${billingDate.month.toString().padLeft(2, '0')}-${billingDate.day.toString().padLeft(2, '0')}'),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                final amount = double.tryParse(amountCtrl.text.trim());
                if (amount == null || amount <= 0) return;

                if (!await showPasswordDialog(context, ref)) return;

                final repo = ref.read(supabaseRepositoryProvider);
                try {
                  await repo.addOperationalCost(OperationalCost(
                    id: '',
                    title: titleCtrl.text.trim(),
                    amount: amount,
                    costType: costType,
                    billingDate: billingDate,
                    createdAt: DateTime.now(),
                  ));
                  ref.invalidate(operationalCostsStreamProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(String label, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${amount.toStringAsFixed(0)} LE',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
        ]),
      ]),
    );
  }
}

class _CostCard extends ConsumerWidget {
  final OperationalCost cost;
  const _CostCard({required this.cost});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _typeColor(cost.costType);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppDecorations.card(context),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_typeIcon(cost.costType), size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cost.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(children: [
                    _typeBadge(cost.costType),
                    const SizedBox(width: 6),
                    Text('${cost.billingDate.day}/${cost.billingDate.month}/${cost.billingDate.year}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ]),
                ],
              ),
            ),
            Text('${cost.amount.toStringAsFixed(0)} LE',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () async {
                if (!await showPasswordDialog(context, ref)) return;
                await ref.read(supabaseRepositoryProvider).deleteOperationalCost(cost.id);
                ref.invalidate(operationalCostsStreamProvider);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeBadge(String type) {
    final c = _typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(type, style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.w600)),
    );
  }

  Color _typeColor(String type) {
    return type == 'salary' ? AppColors.secondary
        : type == 'ad_spend' ? AppColors.warning
        : type == 'subscription' ? AppColors.success
        : AppColors.textSecondary;
  }

  IconData _typeIcon(String type) {
    return type == 'salary' ? Icons.people
        : type == 'ad_spend' ? Icons.campaign
        : type == 'subscription' ? Icons.subscriptions
        : Icons.attach_money;
  }
}
