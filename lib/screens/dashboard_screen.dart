// lib/screens/dashboard_screen.dart
// Dashboard — building tabs, compact pie chart, financial overview, overdue tenants.
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_theme.dart';
import '../models/tenant.dart';
import '../models/room.dart';
import '../models/masareef.dart';
import '../models/operational_cost.dart';
import '../providers/app_providers.dart';
import '../services/pdf_report_service.dart';

// ══════════════════════════════════════════════════════════════
// BUILDING TAB NAMES
// ══════════════════════════════════════════════════════════════
const _buildingNames = {1: 'Gawy', 2: 'Baraka'};

// ══════════════════════════════════════════════════════════════
// MAIN DASHBOARD WIDGET
// ══════════════════════════════════════════════════════════════
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buildingId = ref.watch(currentBuildingIdProvider);
    final statsAsync = ref.watch(dashboardStatsProvider(buildingId));
    final roomsAsync = ref.watch(roomsStreamProvider(buildingId));
    final tenantsAsync = ref.watch(tenantsStreamProvider(buildingId));
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
          final tenants = tenantsAsync.when(
            data: (t) => t,
            loading: () => <Tenant>[],
            error: (_, __) => <Tenant>[],
          );
          return _buildContent(context, ref, stats, isDesktop, rooms, tenants, buildingId);
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> stats,
    bool isDesktop,
    List<Room> rooms,
    List<Tenant> tenants,
    int buildingId,
  ) {
    final totalCollected = (stats['totalRentCollected'] as num?)?.toDouble() ?? 0;
    final totalExpected = (stats['totalRentExpected'] as num?)?.toDouble() ?? 0;
    final totalOverdue = (stats['totalRentOverdue'] as num?)?.toDouble() ?? 0;
    final totalUnpaid = (stats['totalRentUnpaid'] as num?)?.toDouble() ?? 0;
    final totalExpenses = (stats['totalExpenses'] as num?)?.toDouble() ?? 0;
    final totalOpCosts = (stats['totalOpCosts'] as num?)?.toDouble() ?? 0;
    final netBalance = (stats['netBalance'] as num?)?.toDouble() ?? 0;
    final overdueTenants = (stats['overdueTenants'] as List?)?.cast<Tenant>() ?? [];

    // Room status counts
    final occupiedCount = rooms.where((r) => r.isOccupied).length;
    final voidCount = rooms.where((r) => r.isVoid).length;
    final maintenanceCount = rooms.where((r) => r.isMaintenance).length;
    final totalRooms = rooms.length;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dashboard', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Building overview and management',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),

          // ── Building Tabs ──
          _BuildingTabs(
            buildingId: buildingId,
            onSelect: (id) => ref.read(currentBuildingIdProvider.notifier).state = id,
          ),
          const SizedBox(height: 20),

          // ── Room Status Pie Chart + Stat Cards (compact) ──
          _RoomStatusSection(
            occupied: occupiedCount,
            voidRooms: voidCount,
            maintenance: maintenanceCount,
            total: totalRooms,
            isDesktop: isDesktop,
          ),
          const SizedBox(height: 24),

          // ── Financial Banner ──
          _FinancialBanner(
            totalCollected: totalCollected,
            totalExpected: totalExpected,
            totalOverdue: totalOverdue,
            totalUnpaid: totalUnpaid,
            totalExpenses: totalExpenses,
            totalOpCosts: totalOpCosts,
            netBalance: netBalance,
            isDesktop: isDesktop,
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
              return _OverdueCard(
                tenant: t,
                roomDisplay: room.displayRoomNumber,
                monthlyRent: t.insuranceAmount,
              );
            }),
          ],

          // ── PDF Export ──
          const SizedBox(height: 24),
          Center(
            child: FilledButton.icon(
              onPressed: () => _exportPdfReport(context, ref, stats, rooms, tenants),
              icon: const Icon(Icons.picture_as_pdf),
              label: Text(kIsWeb ? 'Download Financial Report' : 'Export Financial Report'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdfReport(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> stats,
    List<Room> rooms,
    List<Tenant> tenants,
  ) async {
    // We need masareef + opCosts — fetch them
    final repo = ref.read(supabaseRepositoryProvider);
    final expenses = await repo.getMasareef();
    final opCosts = await repo.getOperationalCosts();

    await PdfReportService.generateAndPrint(
      dashboardStats: stats,
      tenants: tenants,
      rooms: rooms,
      expenses: expenses,
      opCosts: opCosts,
    );
  }
}

// ══════════════════════════════════════════════════════════════
// BUILDING TABS
// ══════════════════════════════════════════════════════════════
class _BuildingTabs extends StatelessWidget {
  final int buildingId;
  final ValueChanged<int> onSelect;
  const _BuildingTabs({required this.buildingId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderMuted),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: _buildingNames.entries.map((entry) {
          final id = entry.key;
          final name = entry.value;
          final selected = buildingId == id;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: selected
                      ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ROOM STATUS SECTION (compact pie chart + stat cards)
// ══════════════════════════════════════════════════════════════
class _RoomStatusSection extends StatelessWidget {
  final int occupied;
  final int voidRooms;
  final int maintenance;
  final int total;
  final bool isDesktop;

  const _RoomStatusSection({
    required this.occupied,
    required this.voidRooms,
    required this.maintenance,
    required this.total,
    required this.isDesktop,
  });

  double _pct(int count) => total == 0 ? 0 : (count / total * 100);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.card(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Compact pie chart — sized relative to card, max 120px
          SizedBox(
            height: isDesktop ? 120 : 100,
            child: Row(
              children: [
                // Pie chart — fixed small size
                SizedBox(
                  width: isDesktop ? 120 : 100,
                  height: isDesktop ? 120 : 100,
                  child: CustomPaint(
                    size: Size(isDesktop ? 120 : 100, isDesktop ? 120 : 100),
                    painter: _PieChartPainter(
                      occupied: occupied,
                      voidRooms: voidRooms,
                      maintenance: maintenance,
                      total: total,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Legend
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _legendDot(AppColors.success, 'Occupied', occupied),
                      const SizedBox(height: 6),
                      _legendDot(Colors.grey, 'Void', voidRooms),
                      const SizedBox(height: 6),
                      _legendDot(AppColors.warning, 'Maintenance', maintenance),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Stat cards row
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Occupied',
                  count: occupied,
                  pct: _pct(occupied),
                  color: AppColors.success,
                  icon: Icons.check_circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  label: 'Void',
                  count: voidRooms,
                  pct: _pct(voidRooms),
                  color: Colors.grey,
                  icon: Icons.crop_square,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  label: 'Maintenance',
                  count: maintenance,
                  pct: _pct(maintenance),
                  color: AppColors.warning,
                  icon: Icons.build,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _legendDot(Color color, String label, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$label ($count)',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// PIE CHART PAINTER (compact donut)
// ══════════════════════════════════════════════════════════════
class _PieChartPainter extends CustomPainter {
  final int occupied;
  final int voidRooms;
  final int maintenance;
  final int total;

  _PieChartPainter({
    required this.occupied,
    required this.voidRooms,
    required this.maintenance,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) {
      final paint = Paint()
        ..color = Colors.grey.shade200
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16;
      final center = Offset(size.width / 2, size.height / 2);
      final radius = min(size.width, size.height) / 2 - 12;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 12;
    final strokeWidth = 18.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background ring
    final bgPaint = Paint()
      ..color = Colors.grey.shade100
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Segments
    final data = [
      _PieSegment(occupied, AppColors.success),
      _PieSegment(voidRooms, Colors.grey.shade500),
      _PieSegment(maintenance, AppColors.warning),
    ];

    double startAngle = -pi / 2;
    for (final segment in data) {
      if (segment.count == 0) continue;
      final sweepAngle = (segment.count / total) * 2 * pi;
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    // Center text
    final totalPainter = TextPainter(
      text: TextSpan(
        text: '$total',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.neutralDark,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    totalPainter.layout();
    totalPainter.paint(
      canvas,
      Offset(center.dx - totalPainter.width / 2, center.dy - totalPainter.height / 2 - 6),
    );

    final labelPainter = TextPainter(
      text: const TextSpan(
        text: 'Rooms',
        style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
      ),
      textDirection: TextDirection.ltr,
    );
    labelPainter.layout();
    labelPainter.paint(
      canvas,
      Offset(center.dx - labelPainter.width / 2, center.dy + 10),
    );
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) =>
      oldDelegate.occupied != occupied ||
      oldDelegate.voidRooms != voidRooms ||
      oldDelegate.maintenance != maintenance ||
      oldDelegate.total != total;
}

class _PieSegment {
  final int count;
  final Color color;
  _PieSegment(this.count, this.color);
}

// ══════════════════════════════════════════════════════════════
// STAT CARD (interactive, tappable)
// ══════════════════════════════════════════════════════════════
class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final double pct;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.count,
    required this.pct,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$label: $count rooms (${pct.toStringAsFixed(1)}%)'),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: Ink(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FINANCIAL BANNER — Collected / Expected / Overdue / Net
// ══════════════════════════════════════════════════════════════
class _FinancialBanner extends StatelessWidget {
  final double totalCollected;
  final double totalExpected;
  final double totalOverdue;
  final double totalUnpaid;
  final double totalExpenses;
  final double totalOpCosts;
  final double netBalance;
  final bool isDesktop;

  const _FinancialBanner({
    required this.totalCollected,
    required this.totalExpected,
    required this.totalOverdue,
    required this.totalUnpaid,
    required this.totalExpenses,
    required this.totalOpCosts,
    required this.netBalance,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.85),
            AppColors.secondary.withValues(alpha: 0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              const Icon(Icons.account_balance_wallet, size: 18, color: Colors.white70),
              const SizedBox(width: 8),
              const Text('Financial Overview',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
              const Spacer(),
              // Collection rate badge
              if (totalExpected > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(totalCollected / totalExpected * 100).toStringAsFixed(0)}% collected',
                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Main row: Collected vs Expected vs Overdue
          if (isDesktop)
            Row(
              children: [
                _finCol('Collected', totalCollected, Icons.check_circle, Colors.green.shade200),
                const SizedBox(width: 20),
                _finCol('Expected', totalExpected, Icons.calendar_month, Colors.white),
                const SizedBox(width: 20),
                _finCol('Overdue', totalOverdue, Icons.warning_amber, Colors.red.shade200),
                const SizedBox(width: 20),
                _finCol('Net Balance', netBalance, netBalance >= 0 ? Icons.trending_up : Icons.trending_down,
                    netBalance >= 0 ? Colors.green.shade200 : Colors.red.shade200),
              ],
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _finCol('Collected', totalCollected, Icons.check_circle, Colors.green.shade200)),
                    const SizedBox(width: 12),
                    Expanded(child: _finCol('Expected', totalExpected, Icons.calendar_month, Colors.white)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _finCol('Overdue', totalOverdue, Icons.warning_amber, Colors.red.shade200)),
                    const SizedBox(width: 12),
                    Expanded(child: _finCol('Net', netBalance, netBalance >= 0 ? Icons.trending_up : Icons.trending_down,
                        netBalance >= 0 ? Colors.green.shade200 : Colors.red.shade200)),
                  ],
                ),
              ],
            ),

          // Sub-line: breakdown
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _miniStat('Unpaid', totalUnpaid),
                const SizedBox(width: 16),
                _miniStat('Masareef', totalExpenses),
                const SizedBox(width: 16),
                _miniStat('Op. Costs', totalOpCosts),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _finCol(String label, double value, IconData icon, Color valueColor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: Colors.white70),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.white60)),
          ]),
          const SizedBox(height: 4),
          Text('${value.toStringAsFixed(0)} LE',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: valueColor,
              )),
        ],
      ),
    );
  }

  Widget _miniStat(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
        Text('${value.toStringAsFixed(0)} LE',
            style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// OVERDUE CARD (enhanced with amount owed)
// ══════════════════════════════════════════════════════════════
class _OverdueCard extends StatelessWidget {
  final Tenant tenant;
  final String roomDisplay;
  final double monthlyRent;

  const _OverdueCard({
    required this.tenant,
    required this.roomDisplay,
    this.monthlyRent = 0,
  });

  @override
  Widget build(BuildContext context) {
    final daysOverdue = tenant.dueDate != null
        ? DateTime.now().difference(tenant.dueDate!).inDays
        : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.dangerBg, AppColors.surface],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.danger.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person, color: AppColors.danger),
            ),
            const SizedBox(width: 12),
            // Name + details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tenant.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.meeting_room,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Text('Room $roomDisplay',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(width: 10),
                      const Icon(Icons.calendar_today,
                          size: 13, color: AppColors.danger),
                      const SizedBox(width: 3),
                      Text('$daysOverdue days overdue',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.dangerText)),
                    ],
                  ),
                ],
              ),
            ),
            // Amount owed + phone
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (monthlyRent > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${monthlyRent.toStringAsFixed(0)} LE due',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                IconButton(
                  icon: const Icon(Icons.phone,
                      size: 18, color: AppColors.success),
                  onPressed: () async {
                    final uri = Uri(scheme: 'tel', path: tenant.phone);
                    try {
                      // url_launcher
                    } catch (_) {}
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
