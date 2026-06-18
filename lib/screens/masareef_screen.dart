// lib/screens/masareef_screen.dart
// CRUD screen for managing expenses (Arabic: مصاريف = Masareef).
// Responsive: desktop shows DataTable, mobile shows card list.
// Receipt upload: PNG/JPG only, max 20 MB, light compression above 5 MB.

import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import '../models/masareef.dart';
import '../providers/app_providers.dart';
import '../repositories/supabase_repository.dart';
import '../services/auth_guard.dart';

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
    final Map<String, List<Masareef>> grouped = {};
    for (final e in expenses) {
      final key = '${e.dateIncurred.year}-${e.dateIncurred.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(e);
    }

    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
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
              DataColumn(label: Text('Receipt')),
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
                  DataCell(_buildReceiptThumbnail(context, expense)),
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

                    // Receipt thumbnail
                    if (expense.receiptUrl != null &&
                        expense.receiptUrl!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildReceiptThumbnail(context, expense),
                    ],

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
  // RECEIPT THUMBNAIL
  // ══════════════════════════════════════════════════════

  Widget _buildReceiptThumbnail(BuildContext context, Masareef expense) {
    if (expense.receiptUrl == null || expense.receiptUrl!.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, size: 16, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(
              'No receipt',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showReceiptViewer(context, expense),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Image.network(
            expense.receiptUrl!,
            fit: BoxFit.cover,
            width: 48,
            height: 48,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.grey[100],
              child: Icon(Icons.broken_image, size: 20, color: Colors.grey[400]),
            ),
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Container(
                color: Colors.grey[50],
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // RECEIPT VIEWER (full-screen dialog)
  // ══════════════════════════════════════════════════════

  void _showReceiptViewer(BuildContext context, Masareef expense) {
    if (expense.receiptUrl == null || expense.receiptUrl!.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Receipt — ${expense.title}',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Image
            Flexible(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  expense.receiptUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text('Failed to load image',
                            style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
    // Password gate — must pass before dialog opens
    showPasswordDialog(context, ref).then((authenticated) {
      if (!authenticated) return;
      showDialog(
        context: context,
        builder: (ctx) => _MasareefFormDialog(
          expense: expense,
          repo: ref.read(supabaseRepositoryProvider),
          onSave: (Masareef savedExpense, String? error) async {
            if (error != null) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text('Error: $error'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              return;
            }
            ref.invalidate(masareefStreamProvider);
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
          },
        ),
      );
    });
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
              // Password gate for delete
              if (!await showPasswordDialog(context, ref)) return;
              final repo = ref.read(supabaseRepositoryProvider);
              try {
                // Delete receipt from storage first
                if (expense.receiptUrl != null &&
                    expense.receiptUrl!.isNotEmpty) {
                  try {
                    await repo.deleteReceipt(expense.id);
                  } catch (_) {
                    // Continue even if receipt deletion fails
                  }
                }
                await repo.deleteMasareef(expense.id);
                ref.invalidate(masareefStreamProvider);
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
  final void Function(Masareef savedExpense, String? error) onSave;
  final SupabaseRepository repo;

  const _MasareefFormDialog({
    this.expense,
    required this.onSave,
    required this.repo,
  });

  @override
  State<_MasareefFormDialog> createState() => _MasareefFormDialogState();
}

class _MasareefFormDialogState extends State<_MasareefFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;

  String _selectedCategory = 'general';
  late DateTime _selectedDate;

  // Receipt state
  Uint8List? _receiptBytes;
  String? _receiptExtension;
  String? _existingReceiptUrl;
  bool _removeReceipt = false;
  bool _isUploading = false;
  double _uploadProgress = 0;

  static const List<String> _categories = [
    'general',
    'utilities',
    'maintenance',
    'food',
    'cleaning',
    'other',
  ];

  // 20 MB in bytes
  static const int _maxFileSize = 20 * 1024 * 1024;
  // 5 MB compression threshold
  static const int _compressionThreshold = 5 * 1024 * 1024;

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
    _existingReceiptUrl = widget.expense?.receiptUrl;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // ── Image picking ──────────────────────────────────

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );

    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final ext = picked.path.split('.').last.toLowerCase();

    // Validate type
    if (ext != 'png' && ext != 'jpg' && ext != 'jpeg') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only PNG and JPG files are allowed.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Validate size
    if (bytes.length > _maxFileSize) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'File too large (${_formatBytes(bytes.length)}). '
              'Maximum: 20 MB.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _receiptBytes = bytes;
      _receiptExtension = ext == 'jpeg' ? 'jpg' : ext;
      _removeReceipt = false;
    });
  }

  Future<void> _pickReceiptFromCamera() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );

    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final ext = 'jpg'; // Camera always produces JPEG

    if (bytes.length > _maxFileSize) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'File too large (${_formatBytes(bytes.length)}). '
              'Maximum: 20 MB.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _receiptBytes = bytes;
      _receiptExtension = ext;
      _removeReceipt = false;
    });
  }

  void _removeReceiptImage() {
    setState(() {
      _receiptBytes = null;
      _receiptExtension = null;
      _removeReceipt = _existingReceiptUrl != null &&
          _existingReceiptUrl!.isNotEmpty;
    });
  }

  // ── Save with receipt upload ───────────────────────

  Future<void> _saveWithReceipt() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      final repo = widget.repo;

      // Build the expense object
      final expense = Masareef(
        id: widget.expense?.id ?? '',
        title: _titleController.text.trim(),
        amount: double.parse(_amountController.text.trim()),
        category: _selectedCategory,
        dateIncurred: _selectedDate,
        createdAt: widget.expense?.createdAt ?? DateTime.now(),
        receiptUrl: _removeReceipt ? null : (_existingReceiptUrl ?? ''),
      );

      // First save the expense to get an ID
      Masareef savedExpense;
      if (widget.expense == null) {
        savedExpense = await repo.addMasareef(expense);
      } else {
        savedExpense = await repo.updateMasareef(expense);
      }

      setState(() => _uploadProgress = 0.3);

      // Handle receipt upload
      if (_receiptBytes != null && _receiptExtension != null) {
        // Compress if > 5 MB
        var bytes = _receiptBytes!;
        if (bytes.length > _compressionThreshold) {
          setState(() => _uploadProgress = 0.4);
          bytes = await _compressImage(bytes);
        }

        setState(() => _uploadProgress = 0.6);

        // Upload to Supabase Storage
        final receiptUrl = await repo.uploadReceipt(
          expenseId: savedExpense.id,
          fileBytes: bytes,
          fileExtension: _receiptExtension!,
        );

        setState(() => _uploadProgress = 0.9);

        // Update expense with receipt URL
        final updated = savedExpense.copyWith(receiptUrl: receiptUrl);
        await repo.updateMasareef(updated);
        savedExpense = updated;
      } else if (_removeReceipt && widget.expense != null) {
        // Delete old receipt from storage
        try {
          await repo.deleteReceipt(widget.expense!.id);
        } catch (_) {
          // Ignore storage deletion errors
        }
      }

      setState(() => _uploadProgress = 1.0);

      // Notify parent
      if (mounted) {
        widget.onSave(savedExpense, null);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        widget.onSave(widget.expense ?? Masareef(
          id: '', title: '', amount: 0, dateIncurred: DateTime.now(),
          createdAt: DateTime.now(),
        ), e.toString());
      }
    }
  }

  /// Light image compression — downscale large images to reduce file size.
  /// Uses Flutter's image codec to resize to max 1600px.
  Future<Uint8List> _compressImage(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 1600,
        targetHeight: 1600,
      );
      final frame = await codec.getNextFrame();
      final byteData =
          await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final compressed = byteData.buffer.asUint8List();
        // Only use compressed if it's actually smaller
        if (compressed.length < bytes.length) {
          return compressed;
        }
      }
    } catch (_) {
      // Fall through to original bytes
    }
    return bytes;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ── Build ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.expense != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Expense' : 'Add New Expense'),
      content: SizedBox(
        width: 420,
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
                const SizedBox(height: 20),

                // ── Receipt Upload Section ──────────────
                _buildReceiptSection(),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isUploading ? null : _saveWithReceipt,
          child: _isUploading
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: _uploadProgress > 0 ? _uploadProgress : null,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_uploadProgress < 0.4
                        ? 'Saving...'
                        : _uploadProgress < 0.7
                            ? 'Compressing...'
                            : _uploadProgress < 1.0
                                ? 'Uploading...'
                                : 'Done'),
                  ],
                )
              : Text(isEditing ? 'Update' : 'Add'),
        ),
      ],
    );
  }

  // ── Receipt upload UI ──────────────────────────────

  Widget _buildReceiptSection() {
    final hasNewImage = _receiptBytes != null;
    final hasExisting = _existingReceiptUrl != null &&
        _existingReceiptUrl!.isNotEmpty &&
        !_removeReceipt;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Icon(Icons.receipt_long, size: 20, color: Colors.grey[700]),
              const SizedBox(width: 8),
              Text(
                'Receipt Image',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                'PNG/JPG • Max 20 MB',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Existing receipt preview
          if (hasExisting && !hasNewImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: GestureDetector(
                onTap: () => _showReceiptPreview(context),
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.network(
                    _existingReceiptUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[100],
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image,
                                size: 32, color: Colors.grey[400]),
                            const SizedBox(height: 4),
                            Text('Failed to load',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickReceipt,
                    icon: const Icon(Icons.photo_library, size: 18),
                    label: const Text('Replace'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _removeReceiptImage,
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Colors.red),
                    label: const Text('Remove',
                        style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ],

          // New image preview
          if (hasNewImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.memory(
                  _receiptBytes!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${_receiptExtension!.toUpperCase()} • ${_formatBytes(_receiptBytes!.length)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (_receiptBytes!.length > _compressionThreshold) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.amber[300]!),
                    ),
                    child: Text(
                      'Will compress',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.amber[800],
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickReceipt,
                    icon: const Icon(Icons.photo_library, size: 18),
                    label: const Text('Change'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _removeReceiptImage,
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Colors.red),
                    label: const Text('Remove',
                        style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ],

          // No receipt — show upload buttons
          if (!hasExisting && !hasNewImage) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickReceipt,
                    icon: const Icon(Icons.photo_library, size: 18),
                    label: const Text('Gallery'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickReceiptFromCamera,
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: const Text('Camera'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showReceiptPreview(BuildContext context) {
    if (_existingReceiptUrl == null || _existingReceiptUrl!.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Receipt Preview',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  _existingReceiptUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text('Failed to load image',
                            style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
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
}
