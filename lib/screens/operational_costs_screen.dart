// lib/screens/operational_costs_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/operational_cost.dart';
import '../providers/app_providers.dart';

class OperationalCostsScreen extends ConsumerWidget {
  const OperationalCostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final costsAsync = ref.watch(operationalCostsStreamProvider);
    final isDesktop = MediaQuery.of(context).size.width > 900;

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
              // Summary cards
              Padding(
                padding: const EdgeInsets.all(12),
                child: isDesktop
                    ? Row(children: _summaryCards(total, salary, ads, subs))
                    : Column(children: _summaryCards(total, salary, ads, subs)),
              ),
              const Divider(height: 1),
              // Data list/table
              Expanded(
                child: costs.isEmpty
                    ? const Center(child: Text('No operational costs recorded', style: TextStyle(color: Colors.grey)))
                    : RefreshIndicator(
                        onRefresh: () async => ref.invalidate(operationalCostsStreamProvider),
                        child: isDesktop ? _buildDataTable(context, ref, costs) : _buildCardList(context, ref, costs),
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

  List<Widget> _summaryCards(double total, double salary, double ads, double subs) {
    return [
      _summaryCard('Total', total, Colors.purple, Icons.account_balance),
      _summaryCard('Salaries', salary, Colors.blue, Icons.people),
      _summaryCard('Ad Spend', ads, Colors.orange, Icons.campaign),
      _summaryCard('Subscriptions', subs, Colors.green, Icons.subscriptions),
    ];
  }

  Widget _summaryCard(String label, double amount, Color color, IconData icon) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [Icon(icon, color: color, size: 20), const SizedBox(height: 4),
              Text('${amount.toStringAsFixed(0)} LE', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataTable(BuildContext context, WidgetRef ref, List<OperationalCost> costs) {
    return SingleChildScrollView(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Title')),
          DataColumn(label: Text('Amount')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Actions')),
        ],
        rows: costs.map((c) => DataRow(cells: [
          DataCell(Text(c.title)),
          DataCell(Text('${c.amount.toStringAsFixed(0)} LE')),
          DataCell(_typeBadge(c.costType)),
          DataCell(Text('${c.billingDate.day}/${c.billingDate.month}/${c.billingDate.year}')),
          DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _showAddDialog(context, ref, cost: c)),
            IconButton(icon: const Icon(Icons.delete, size: 18), onPressed: () => _confirmDelete(context, ref, c)),
          ])),
        ])).toList(),
      ),
    );
  }

  Widget _buildCardList(BuildContext context, WidgetRef ref, List<OperationalCost> costs) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: costs.length,
      itemBuilder: (_, i) {
        final c = costs[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(c.title),
            subtitle: Row(children: [
              _typeBadge(c.costType),
              const SizedBox(width: 8),
              Text('${c.billingDate.day}/${c.billingDate.month}'),
            ]),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('${c.amount.toStringAsFixed(0)} LE', style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.delete, size: 18), onPressed: () => _confirmDelete(context, ref, c)),
            ]),
          ),
        );
      },
    );
  }

  Widget _typeBadge(String type) {
    final color = type == 'salary' ? Colors.blue : type == 'ad_spend' ? Colors.orange : type == 'subscription' ? Colors.green : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
      child: Text(type, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
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
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Amount (LE)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
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
                  final picked = await showDatePicker(context: ctx, initialDate: billingDate, firstDate: DateTime(2024), lastDate: DateTime(2030));
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
