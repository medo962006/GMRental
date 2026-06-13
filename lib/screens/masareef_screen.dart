// lib/screens/masareef_screen.dart
// CRUD screen for managing expenses (Arabic: مصاريف = Masareef).
// Responsive: desktop shows DataTable, mobile shows card list.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../models/masareef.dart';
import '../providers/app_providers.dart';


class MasareefScreen extends ConsumerWidget {
  const MasareefScreen({super.key});

  static const double _desktopBreakpoint = 900.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masareefAsync = ref.watch(masareefStreamProvider);
    final isDesktop = MediaQuery.of(context).size.width > _desktopBreakpoint;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Masareef (Expenses)'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(masareefStreamProvider);
        },
        child: masareefAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Error loading expenses',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('$err', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(masareefStreamProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (expenses) {
            return CustomScrollView(
              slivers: [
                // ── Running Total Header ─────────────────
                SliverToBoxAdapter(
                  child: _buildTotalHeader(context, expenses),
                ),
                // ── Monthly Summary ──────────────────────
                if (expenses.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildMonthlySummary(context, expenses),
                  ),
                // ── Expense List ─────────────────────────
                if (expenses.isEmpty)
                  SliverFillRemaining(
                    child: _buildEmptyState(context),
                  )
                else if (isDesktop)
                  SliverToBoxAdapter(
                    child: _buildDesktopTable(context, ref, expenses),
                  )
                else
                  _buildMobileList(context, ref, expenses),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // RUNNING TOTAL HEADER
  // ══════════════════════════════════════════════════════

  Widget _buildTotalHeader(BuildContext context, List<Masareef> expenses) {
    final total = expenses.fold(0.0, (sum, e) => sum + e.amount);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet,
              color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Expenses',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatCurrency(total)} ${AppConfig.currency}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${expenses.length} items',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // MONTHLY SUMMARY
  // ══════════════════════════════════════════════════════

  Widget _buildMonthlySummary(BuildContext context, List<Masareef> expenses) {
    // Group by year-month
    final Map<String, List<Masareef>> grouped = {};
    for (final e in expenses) {
      final key = '${e.dateIncurred.year}-${e.dateIncurred.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(e);
    }

    // Sort keys descending (most recent first)
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    // Take top 3 months
    final topMonths = sortedKeys.take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Monthly Summary',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              ...topMonths.map((key) {
                final monthExpenses = grouped[key]!;
                final monthTotal =
                    monthExpenses.fold(0.0, (sum, e) => sum + e.amount);
                final parts = key.split('-');
                final year = parts[0];
                final monthNum = int.parse(parts[1]);
                final monthName = _monthName(monthNum);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month,
                          size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$monthName $year',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        '${_formatCurrency(monthTotal)} ${AppConfig.currency}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // EMPTY STATE
  // ══════════════════════════════════════════════════════

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No expenses yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add your first expense.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // DESKTOP TABLE
  // ══════════════════════════════════════════════════════

  Widget _buildDesktopTable(
      BuildContext context, WidgetRef ref, List<Masareef> expenses) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Title')),
              DataColumn(label: Text('Amount')),
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Actions')),
            ],
            rows: expenses.map((expense) {
              return DataRow(
                cells: [
                  DataCell(Text(
                    expense.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )),
                  DataCell(Text(
                    '${_formatCurrency(expense.amount)} ${AppConfig.currency}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  )),
                  DataCell(_buildCategoryBadge(expense.category)),
                  DataCell(Text(_formatDate(expense.dateIncurred))),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          tooltip: 'Edit',
                          onPressed: () =>
                              _showAddEditDialog(context, ref, expense: expense),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              size: 20, color: Colors.red),
                          tooltip: 'Delete',
                          onPressed: () =>
                              _confirmDelete(context, ref, expense),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // MOBILE CARD LIST
  // ══════════════════════════════════════════════════════

  Widget _buildMobileList(
      BuildContext context, WidgetRef ref, List<Masareef> expenses) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final expense = expenses[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Title + Category badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            expense.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        _buildCategoryBadge(expense.category),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Amount row
                    Row(
                      children: [
                        Icon(Icons.attach_money,
                            size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatCurrency(expense.amount)} ${AppConfig.currency}',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Date row
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(expense.dateIncurred),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () =>
                              _showAddEditDialog(context, ref, expense: expense),
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Edit'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () =>
                              _confirmDelete(context, ref, expense),
                          icon: const Icon(Icons.delete,
                              size: 18, color: Colors.red),
                          label: const Text('Delete',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        childCount: expenses.length,
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // CATEGORY BADGE
  // ══════════════════════════════════════════════════════

  Widget _buildCategoryBadge(String category) {
    final color = _getCategoryColor(category);
    final label = category[0].toUpperCase() + category.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'utilities':
        return Colors.blue;
      case 'maintenance':
        return Colors.orange;
      case 'food':
        return Colors.green;
      case 'cleaning':
        return Colors.teal;
      case 'other':
        return Colors.purple;
      case 'general':
      default:
        return Colors.indigo;
    }
  }

  // ══════════════════════════════════════════════════════
  // ADD / EDIT DIALOG
  // ══════════════════════════════════════════════════════

  void _showAddEditDialog(BuildContext context, WidgetRef ref,
      {Masareef? expense}) {
    showDialog(
      context: context,
      builder: (ctx) => _MasareefFormDialog(
        expense: expense,
        onSave: (Masareef savedExpense) async {
          final repo = ref.read(supabaseRepositoryProvider);
          try {
            if (expense == null) {
              await repo.addMasareef(savedExpense);
            } else {
              await repo.updateMasareef(savedExpense);
            }
            if (ctx.mounted) {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(expense == null
                      ? 'Expense "${savedExpense.title}" added'
                      : 'Expense "${savedExpense.title}" updated'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text('Error: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // DELETE CONFIRMATION
  // ══════════════════════════════════════════════════════

  void _confirmDelete(BuildContext context, WidgetRef ref, Masareef expense) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text(
            'Are you sure you want to delete "${expense.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final repo = ref.read(supabaseRepositoryProvider);
              try {
                await repo.deleteMasareef(expense.id);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${expense.title} deleted'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting expense: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════

  String _formatCurrency(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }
    return amount.toStringAsFixed(2);
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month - 1];
  }
}

// ══════════════════════════════════════════════════════
// MASAREEF FORM DIALOG (StatefulWidget)
// ══════════════════════════════════════════════════════

class _MasareefFormDialog extends StatefulWidget {
  final Masareef? expense;
  final Function(Masareef) onSave;

  const _MasareefFormDialog({this.expense, required this.onSave});

  @override
  State<_MasareefFormDialog> createState() => _MasareefFormDialogState();
}

class _MasareefFormDialogState extends State<_MasareefFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;

  String _selectedCategory = 'general';
  late DateTime _selectedDate;

  static const List<String> _categories = [
    'general',
    'utilities',
    'maintenance',
    'food',
    'cleaning',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.expense?.title ?? '');
    _amountController = TextEditingController(
        text: widget.expense != null && widget.expense!.amount > 0
            ? widget.expense!.amount.toString()
            : '');
    _selectedCategory = widget.expense?.category ?? 'general';
    _selectedDate = widget.expense?.dateIncurred ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.expense != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Expense' : 'Add New Expense'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Electricity bill',
                    prefixIcon: Icon(Icons.title),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Title is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Amount
                TextFormField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    hintText: 'e.g. 250',
                    prefixIcon: const Icon(Icons.attach_money),
                    suffixText: AppConfig.currency,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Amount is required';
                    }
                    final parsed = double.tryParse(val.trim());
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a valid positive amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Category Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category),
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.map((c) {
                    final color = _getCategoryColor(c);
                    return DropdownMenuItem(
                      value: c,
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(c[0].toUpperCase() + c.substring(1)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedCategory = val);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Date Picker
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date Incurred',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final expense = Masareef(
                id: widget.expense?.id ?? '',
                title: _titleController.text.trim(),
                amount: double.parse(_amountController.text.trim()),
                category: _selectedCategory,
                dateIncurred: _selectedDate,
                createdAt: widget.expense?.createdAt ?? DateTime.now(),
              );
              widget.onSave(expense);
            }
          },
          child: Text(isEditing ? 'Update' : 'Add'),
        ),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'utilities':
        return Colors.blue;
      case 'maintenance':
        return Colors.orange;
      case 'food':
        return Colors.green;
      case 'cleaning':
        return Colors.teal;
      case 'other':
        return Colors.purple;
      case 'general':
      default:
        return Colors.indigo;
    }
  }
}
