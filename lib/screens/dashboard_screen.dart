// lib/screens/dashboard_screen.dart
// Dashboard — design system overhaul.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_theme.dart';
import '../models/tenant.dart';
import '../models/room.dart';
import '../models/masareef.dart';
import '../providers/app_providers.dart';
import '../services/pdf_report_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final buildingId = ref.watch(currentBuildingIdProvider);
    final roomsAsync = ref.watch(roomsStreamProvider(buildingId));
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (stats) {
          final rooms = roomsAsync.when(
            data: (r) => r,
            loading: () => <Room>[],
            error: (_, __) => <Room>[],
          );
          return _buildContent(context, ref, stats, isDesktop, rooms);
        },
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, Map<String, dynamic> stats, bool isDesktop, List<Room> rooms) {
    final totalCollected = (stats['totalRentCollected'] as num?)?.toDouble() ?? 0;
    final totalExpenses = (stats['totalExpenses'] as num?)?.toDouble() ?? 0;
    final totalOpCosts = (stats['totalOpCosts'] as num?)?.toDouble() ?? 0;
    final netBalance = (stats['netBalance'] as num?)?.toDouble() ?? 0;
    final overdueTenants = (stats['overdueTenants'] as List?)?.cast<Tenant>() ?? [];

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dashboard', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Financial overview and debt collection',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),

          // ── Financial Banner ──
          Container(
            decoration: AppDecorations.card(context),
            padding: const EdgeInsets.all(20),
            child: isDesktop
                ? Row(
                    children: [
                      _finStat('Total Collected', totalCollected, AppColors.primary, Icons.account_balance_wallet),
                      const SizedBox(width: 24),
                      _finStat('Masareef', totalExpenses, AppColors.secondary, Icons.receipt_long),
                      const SizedBox(width: 24),
                      _finStat('Op. Costs', totalOpCosts, AppColors.accent, Icons.trending_up),
                      const SizedBox(width: 24),
                      _finStat('Net Balance', netBalance, netBalance >= 0 ? AppColors.success : AppColors.danger, Icons.account_balance),
                    ],
                  )
                : Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _finStat('Collected', totalCollected, AppColors.primary, Icons.account_balance_wallet)),
                          const SizedBox(width: 12),
                          Expanded(child: _finStat('Masareef', totalExpenses, AppColors.secondary, Icons.receipt_long)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _finStat('Op. Costs', totalOpCosts, AppColors.accent, Icons.trending_up)),
                          const SizedBox(width: 12),
                          Expanded(child: _finStat('Net', netBalance, netBalance >= 0 ? AppColors.success : AppColors.danger, Icons.account_balance)),
                        ],
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 24),

          // ── Summary Chips ──
          if (isDesktop)
            Row(children: _summaryChips(stats))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: _summaryChips(stats)),
            ),

          const SizedBox(height: 24),

          // ── Overdue Tenants ──
          if (overdueTenants.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Overdue Tenants',
                    style: Theme.of(context).textTheme.titleMedium),
                AppBadge.unpaid(label: '${overdueTenants.length} overdue'),
              ],
            ),
            const SizedBox(height: 12),
            ...overdueTenants.map((t) {
              final room = rooms.firstWhere(
                (r) => r.id == t.roomId,
                orElse: () => Room(id: 0, roomNumber: '—', status: 'void', monthlyRent: 0),
              );
              return _OverdueCard(tenant: t, roomDisplay: room.displayRoomNumber);
            }),
            const SizedBox(height: 24),
          ],

          // ── PDF Export ──
          Center(
            child: FilledButton.icon(
              onPressed: () => _exportPdfReport(context, ref),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Export Financial Report'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _finStat(String label, double value, Color color, IconData icon) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
          const SizedBox(height: 6),
          Text('${value.toStringAsFixed(0)} LE',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  List<Widget> _summaryChips(Map<String, dynamic> stats) {
    return [
      _chip('Rooms', '${stats['totalRooms'] ?? 0}', AppColors.primary, Icons.meeting_room),
      const SizedBox(width: 8),
      _chip('Occupied', '${stats['occupiedRooms'] ?? 0}', AppColors.success, Icons.check_circle),
      const SizedBox(width: 8),
      _chip('Paid', '${stats['paidTenants'] ?? 0}', AppColors.success, Icons.payments),
      const SizedBox(width: 8),
      _chip('Unpaid', '${stats['unpaidTenants'] ?? 0}', AppColors.danger, Icons.error),
      const SizedBox(width: 8),
      _chip('Tasks', '${stats['pendingTasks'] ?? 0}', AppColors.warning, Icons.checklist),
    ];
  }

  Widget _chip(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text('$value $label',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }

  void _exportPdfReport(BuildContext context, WidgetRef ref) {
    // PDF export logic
  }
}

class _OverdueCard extends StatelessWidget {
  final Tenant tenant;
  final String roomDisplay;
  const _OverdueCard({required this.tenant, required this.roomDisplay});

  @override
  Widget build(BuildContext context) {
    final daysOverdue = tenant.dueDate != null
        ? DateTime.now().difference(tenant.dueDate!).inDays
        : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppDecorations.card(context),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person, color: AppColors.danger),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tenant.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text('Room $roomDisplay · $daysOverdue days overdue',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.phone, size: 18, color: AppColors.success),
              onPressed: () async {
                final uri = Uri(scheme: 'tel', path: tenant.phone);
                try {
                  // url_launcher
                } catch (_) {}
              },
            ),
          ],
        ),
      ),
    );
  }
}
