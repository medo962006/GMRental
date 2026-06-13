// lib/screens/dashboard_screen.dart
// Debt Collection Dashboard for Mr. Emad (manager)
// Responsive: desktop shows wide tables, mobile shows card lists.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../models/tenant.dart';
import '../models/masareef.dart';
import '../providers/app_providers.dart';
import '../services/pdf_report_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const double _desktopBreakpoint = 900.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final masareefAsync = ref.watch(masareefStreamProvider);
    final isDesktop = MediaQuery.of(context).size.width > _desktopBreakpoint;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF Report',
            onPressed: () => _exportPdfReport(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(masareefStreamProvider);
        },
        child: statsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Error loading dashboard',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('$err', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(dashboardStatsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (stats) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Summary Cards ──────────────────────────
              _buildSummaryCards(context, stats, isDesktop),
              const SizedBox(height: 24),

              // ── Overdue Tenants ───────────────────────
              _buildSectionHeader(context, 'Overdue Tenants', Icons.warning,
                  Colors.red),
              const SizedBox(height: 8),
              _buildOverdueSection(
                  context, stats['overdueTenants'] as List<Tenant>, isDesktop),
              const SizedBox(height: 24),

              // ── Recent Expenses ───────────────────────
              _buildSectionHeader(
                  context, 'Recent Expenses', Icons.receipt_long, Colors.orange),
              const SizedBox(height: 8),
              _buildExpensesSection(context, masareefAsync, isDesktop),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _exportPdfReport(context, ref),
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text('Export PDF'),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // EXPORT PDF REPORT
  // ══════════════════════════════════════════════════════

  Future<void> _exportPdfReport(BuildContext context, WidgetRef ref) async {
    // Show loading snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('Generating report...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      final repo = ref.read(supabaseRepositoryProvider);

      // Fetch all needed data
      final rooms = await repo.getRooms();
      final tenants = await repo.getTenants();
      final masareefList = await repo.getMasareef();
      final opCosts = await repo.getOperationalCosts();

      // Get stats
      final stats = ref.read(dashboardStatsProvider).valueOrNull ?? {};

      await PdfReportService.generateAndPrint(
        dashboardStats: stats,
        tenants: tenants,
        rooms: rooms,
        expenses: masareefList,
        opCosts: opCosts,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF report generated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ══════════════════════════════════════════════════════
  // SUMMARY CARDS
  // ══════════════════════════════════════════════════════

  Widget _buildSummaryCards(
      BuildContext context, Map<String, dynamic> stats, bool isDesktop) {
    final cards = [
      _StatCardData(
        'Total Rooms',
        '${stats['totalRooms']}',
        Icons.meeting_room,
        Colors.blue,
      ),
      _StatCardData(
        'Occupied',
        '${stats['occupiedRooms']}',
        Icons.check_circle,
        Colors.green,
      ),
      _StatCardData(
        'Void',
        '${stats['voidRooms']}',
        Icons.cancel,
        Colors.grey,
      ),
      _StatCardData(
        'Total Tenants',
        '${stats['totalTenants']}',
        Icons.people,
        Colors.indigo,
      ),
      _StatCardData(
        'Paid',
        '${stats['paidTenants']}',
        Icons.paid,
        Colors.green,
      ),
      _StatCardData(
        'Unpaid',
        '${stats['unpaidTenants']}',
        Icons.money_off,
        Colors.red,
      ),
      _StatCardData(
        'Rent Expected',
        '${_formatCurrency(stats['totalRentExpected'])} ${AppConfig.currency}',
        Icons.account_balance_wallet,
        Colors.teal,
      ),
      _StatCardData(
        'Rent Collected',
        '${_formatCurrency(stats['totalRentCollected'] ?? 0)} ${AppConfig.currency}',
        Icons.payments,
        Colors.green,
      ),
      _StatCardData(
        'Rent Due',
        '${_formatCurrency(stats['totalRentDue'] ?? 0)} ${AppConfig.currency}',
        Icons.warning_amber,
        Colors.red,
      ),
      _StatCardData(
        'Total Expenses',
        '${_formatCurrency(stats['totalExpenses'])} ${AppConfig.currency}',
        Icons.trending_down,
        Colors.orange,
      ),
      _StatCardData(
        'Net Balance',
        '${_formatCurrency(stats['netBalance'] ?? 0)} ${AppConfig.currency}',
        Icons.balance,
        (stats['netBalance'] ?? 0) >= 0 ? Colors.green : Colors.red,
      ),
      _StatCardData(
        'Tasks Pending',
        '${stats['pendingTasks'] ?? 0}',
        Icons.checklist,
        Colors.orange,
      ),
      _StatCardData(
        'Total Op. Costs',
        '${_formatCurrency(stats['totalOpCosts'] ?? 0)} ${AppConfig.currency}',
        Icons.account_balance,
        Colors.purple,
      ),
    ];

    if (isDesktop) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards.map((c) => _buildStatCard(context, c, 200)).toList(),
      );
    } else {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildStatCard(context, cards[0], null)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard(context, cards[1], null)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard(context, cards[2], null)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildStatCard(context, cards[3], null)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard(context, cards[4], null)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard(context, cards[5], null)),
            ],
          ),
          const SizedBox(height: 8),
          _buildStatCard(context, cards[6], null),
          const SizedBox(height: 8),
          _buildStatCard(context, cards[7], null),
          const SizedBox(height: 8),
          _buildStatCard(context, cards[8], null),
          const SizedBox(height: 8),
          _buildStatCard(context, cards[9], null),
          const SizedBox(height: 8),
          _buildStatCard(context, cards[10], null),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildStatCard(context, cards[11], null)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard(context, cards[12], null)),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildStatCard(
      BuildContext context, _StatCardData data, double? width) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(data.icon, color: data.color, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                data.value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: data.color,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // OVERDUE TENANTS
  // ══════════════════════════════════════════════════════

  Widget _buildOverdueSection(
      BuildContext context, List<Tenant> overdue, bool isDesktop) {
    if (overdue.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[400], size: 32),
              const SizedBox(width: 12),
              Text(
                'No overdue tenants. All clear!',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.green[700],
                    ),
              ),
            ],
          ),
        ),
      );
    }

    if (isDesktop) {
      return Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Phone')),
              DataColumn(label: Text('Due Date')),
              DataColumn(label: Text('Days Overdue')),
              DataColumn(label: Text('Action')),
            ],
            rows: overdue.map((t) {
              final daysOverdue = t.dueDate != null
                  ? DateTime.now().difference(t.dueDate!).inDays
                  : 0;
              return DataRow(
                cells: [
                  DataCell(Text(t.name)),
                  DataCell(Text(t.phone)),
                  DataCell(Text(t.dueDate != null
                      ? '${t.dueDate!.year}-${t.dueDate!.month.toString().padLeft(2, '0')}-${t.dueDate!.day.toString().padLeft(2, '0')}'
                      : 'N/A')),
                  DataCell(
                    Text(
                      '$daysOverdue days',
                      style: const TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.phone, color: Colors.green),
                      tooltip: 'Call ${t.name}',
                      onPressed: () => _makePhoneCall(t.phone),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      );
    }

    return Column(
      children: overdue.map((t) {
        final daysOverdue = t.dueDate != null
            ? DateTime.now().difference(t.dueDate!).inDays
            : 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.red[100],
              child: Icon(Icons.person, color: Colors.red[700]),
            ),
            title: Text(t.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.phone),
                Text(
                  'Due: ${t.dueDate != null ? "${t.dueDate!.year}-${t.dueDate!.month.toString().padLeft(2, '0')}-${t.dueDate!.day.toString().padLeft(2, '0')}" : "N/A"} · $daysOverdue days overdue',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.phone, color: Colors.green),
              onPressed: () => _makePhoneCall(t.phone),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ══════════════════════════════════════════════════════
  // RECENT EXPENSES
  // ══════════════════════════════════════════════════════

  Widget _buildExpensesSection(BuildContext context,
      AsyncValue<List<Masareef>> masareefAsync, bool isDesktop) {
    return masareefAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error loading expenses: $err'),
        ),
      ),
      data: (allExpenses) {
        final expenses = allExpenses.take(5).toList();
        if (expenses.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Icon(Icons.receipt_long,
                      color: Colors.grey[400], size: 32),
                  const SizedBox(width: 12),
                  Text(
                    'No expenses recorded yet.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
          );
        }

        if (isDesktop) {
          return Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Title')),
                  DataColumn(label: Text('Category')),
                  DataColumn(label: Text('Amount')),
                  DataColumn(label: Text('Date')),
                ],
                rows: expenses.map((e) {
                  return DataRow(
                    cells: [
                      DataCell(Text(e.title)),
                      DataCell(_buildCategoryChip(e.category)),
                      DataCell(Text(
                        '${_formatCurrency(e.amount)} ${AppConfig.currency}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )),
                      DataCell(Text(
                          '${e.dateIncurred.year}-${e.dateIncurred.month.toString().padLeft(2, '0')}-${e.dateIncurred.day.toString().padLeft(2, '0')}')),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        }

        return Column(
          children: expenses.map((e) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange[100],
                  child: Icon(Icons.receipt, color: Colors.orange[700]),
                ),
                title: Text(e.title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    '${e.category} · ${e.dateIncurred.year}-${e.dateIncurred.month.toString().padLeft(2, '0')}-${e.dateIncurred.day.toString().padLeft(2, '0')}'),
                trailing: Text(
                  '${_formatCurrency(e.amount)} ${AppConfig.currency}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                    fontSize: 16,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String category) {
    return Chip(
      label: Text(
        category,
        style: const TextStyle(fontSize: 12),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  String _formatCurrency(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }
    return amount.toStringAsFixed(2);
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

// ══════════════════════════════════════════════════════
// INTERNAL DATA CLASS
// ══════════════════════════════════════════════════════

class _StatCardData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  _StatCardData(this.label, this.value, this.icon, this.color);
}
