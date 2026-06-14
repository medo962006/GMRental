// lib/screens/operational_costs_screen.dart
// Mobile-first operational costs tracking.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/operational_cost.dart';
import '../providers/app_providers.dart';

class OperationalCostsScreen extends ConsumerWidget {
  const OperationalCostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final costsAsync = ref.watch(operationalCostsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Operational Costs'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
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
              // Summary — horizontal scrollable chips on mobile
              Container(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _summaryChip('Total', total, Colors.purple, Icons.account_balance),
                      const SizedBox(width: 8),
                      _summaryChip('Salaries', salary, Colors.blue, Icons.people),
                      const SizedBox(width: 8),
                      _summaryChip('Ad Spend', ads, Colors.orange, Icons.campaign),
                      const SizedBox(width: 8),
                      _summaryChip('Subs', subs, Colors.green, Icons.subscriptions),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              // Cost list
              Expanded(
                child: costs.isEmpty
                    ? const Center(
                        child: Text('No operational costs recorded',
                            style: TextStyle(color: Colors.grey)))
                    : RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(operationalCostsStreamProvider),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          itemCount: costs.length,
                          itemBuilder: (_, i) => _buildCostCard(context, ref, costs[i]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Cost'),
      ),
    );
  }

  Widget _summaryChip(String label, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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

  Widget _buildCostCard(BuildContext context, WidgetRef ref, OperationalCost c) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Type icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _typeColor(c.costType).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_typeIcon(c.costType), size: 20, color: _typeColor(c.costType)),
            ),
            const SizedBox(width: 12),
            // Title + date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(children: [
                    _typeBadge(c.costType),
                    const SizedBox(width: 6),
                    Text('${c.billingDate.day}/${c.billingDate.month}/${c.billingDate.year}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ]),
                ],
              ),
            ),
            // Amount + delete
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${c.amount.toStringAsFixed(0)} LE',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _confirmDelete(context, ref, c),
                ),
              ],
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
      child: Text(type,
          style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.w600)),
    );
  }

  Color _typeColor(String type) {
    return type == 'salary'
        ? Colors.blue
        : type == 'ad_spend'
            ? Colors.orange
            : type == 'subscription'
                ? Colors.green
                : Colors.grey;
  }

  IconData _typeIcon(String type) {
    return type == 'salary'
        ? Icons.people
        : type == 'ad_spend'
            ? Icons.campaign
            : type == 'subscription'
                ? Icons.subscriptions
                : Icons.attach_money;
  }

  void _showAddDialog(BuildContext context, WidgetRef ref, {OperationalCost? cost}) {
    final titleCtrl = TextEditingController(text: cost?.title ?? '');
    final amountCtrl = TextEditingController(text: cost?.amount.toString() ?? '');
    String costType = cost?.costType ?? 'other';
    DateTime billingDate = cost?.billingDate ?? DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(cost == null ? 'Add Cost' : 'Edit Cost'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(labelText: 'Amount (LE)', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number),
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
                onChanged: (v) => setDialogState(() => costType = v ?? 'other'),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                      context: ctx,
                      initialDate: billingDate,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030));
                  if (picked != null) setDialogState(() => billingDate = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Billing Date', border: OutlineInputBorder()),
                  child: Text('${billingDate.day}/${billingDate.month}/${billingDate.year}'),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty || amountCtrl.text.trim().isEmpty) return;
                final repo = ref.read(supabaseRepositoryProvider);
                final newCost = OperationalCost(
                  id: cost?.id ?? '',
                  title: titleCtrl.text.trim(),
                  amount: double.tryParse(amountCtrl.text) ?? 0,
                  costType: costType,
                  billingDate: billingDate,
                  createdAt: cost?.createdAt ?? DateTime.now(),
                );
                if (cost == null) {
                  await repo.addOperationalCost(newCost);
                } else {
                  await repo.updateOperationalCost(newCost);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(cost == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, OperationalCost cost) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Cost'),
        content: Text('Delete "${cost.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await ref.read(supabaseRepositoryProvider).deleteOperationalCost(cost.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
