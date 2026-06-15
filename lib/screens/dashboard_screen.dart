// lib/screens/dashboard_screen.dart
// Dashboard — building tabs, pie chart, room list, financial overview, overdue tenants.
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_theme.dart';
import '../models/tenant.dart';
import '../models/room.dart';
import '../models/masareef.dart';
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

          // ── Room Status Pie Chart + Stat Cards ──
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
            totalExpenses: totalExpenses,
            totalOpCosts: totalOpCosts,
            netBalance: netBalance,
            isDesktop: isDesktop,
          ),
          const SizedBox(height: 24),

          // ── All Rooms List ──
          Text('All Rooms', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _RoomsListByFloor(
            rooms: rooms,
            tenants: tenants,
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
                monthlyRent: room.monthlyRent,
              );
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

  void _exportPdfReport(BuildContext context, WidgetRef ref) {
    // PDF export logic
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
// ROOM STATUS SECTION (pie chart + stat cards)
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
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Pie chart
          SizedBox(
            height: isDesktop ? 200 : 160,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: CustomPaint(
                    size: Size(isDesktop ? 200 : 160, isDesktop ? 200 : 160),
                    painter: _PieChartPainter(
                      occupied: occupied,
                      voidRooms: voidRooms,
                      maintenance: maintenance,
                      total: total,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _legendDot(AppColors.success, 'Occupied', occupied),
                      const SizedBox(height: 8),
                      _legendDot(Colors.grey, 'Void', voidRooms),
                      const SizedBox(height: 8),
                      _legendDot(AppColors.warning, 'Maintenance', maintenance),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
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
// PIE CHART PAINTER
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
      // Draw empty grey circle
      final paint = Paint()
        ..color = Colors.grey.shade200
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24;
      final center = Offset(size.width / 2, size.height / 2);
      final radius = size.width / 2 - 16;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;
    final strokeWidth = 28.0;
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
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.neutralDark,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    totalPainter.layout();
    totalPainter.paint(
      canvas,
      Offset(center.dx - totalPainter.width / 2, center.dy - totalPainter.height / 2 - 8),
    );

    final labelPainter = TextPainter(
      text: const TextSpan(
        text: 'Rooms',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      textDirection: TextDirection.ltr,
    );
    labelPainter.layout();
    labelPainter.paint(
      canvas,
      Offset(center.dx - labelPainter.width / 2, center.dy + 12),
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
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                '$count',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
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
// FINANCIAL BANNER (gradient)
// ══════════════════════════════════════════════════════════════
class _FinancialBanner extends StatelessWidget {
  final double totalCollected;
  final double totalExpenses;
  final double totalOpCosts;
  final double netBalance;
  final bool isDesktop;

  const _FinancialBanner({
    required this.totalCollected,
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
      child: isDesktop
          ? Row(
              children: [
                _finStat('Total Collected', totalCollected, Icons.account_balance_wallet),
                const SizedBox(width: 24),
                _finStat('Masareef', totalExpenses, Icons.receipt_long),
                const SizedBox(width: 24),
                _finStat('Op. Costs', totalOpCosts, Icons.trending_up),
                const SizedBox(width: 24),
                _finStat('Net Balance', netBalance,
                    netBalance >= 0 ? Icons.check_circle : Icons.warning),
              ],
            )
          : Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _finStat('Collected', totalCollected, Icons.account_balance_wallet)),
                    const SizedBox(width: 12),
                    Expanded(child: _finStat('Masareef', totalExpenses, Icons.receipt_long)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _finStat('Op. Costs', totalOpCosts, Icons.trending_up)),
                    const SizedBox(width: 12),
                    Expanded(child: _finStat('Net', netBalance,
                        netBalance >= 0 ? Icons.check_circle : Icons.warning)),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _finStat(String label, double value, IconData icon) {
    final isPositive = netBalance >= 0;
    final valueColor = icon == Icons.check_circle || icon == Icons.warning
        ? (isPositive ? Colors.green.shade200 : Colors.red.shade200)
        : Colors.white;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: Colors.white70),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.white60)),
          ]),
          const SizedBox(height: 6),
          Text('${value.toStringAsFixed(0)} LE',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: valueColor,
              )),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ROOMS LIST GROUPED BY FLOOR
// ══════════════════════════════════════════════════════════════
class _RoomsListByFloor extends StatelessWidget {
  final List<Room> rooms;
  final List<Tenant> tenants;

  const _RoomsListByFloor({required this.rooms, required this.tenants});

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      return Container(
        decoration: AppDecorations.card(context),
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: Text('No rooms found for this building',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    // Group by floor
    final Map<String, List<Room>> grouped = {};
    for (final room in rooms) {
      grouped.putIfAbsent(room.floor, () => []).add(room);
    }

    // Sort floors by floorOrder
    final sortedFloors = grouped.keys.toList()
      ..sort((a, b) {
        final orderA = _floorOrderKey(a);
        final orderB = _floorOrderKey(b);
        return orderA.compareTo(orderB);
      });

    // Build tenant lookup by roomId
    final Map<int, Tenant> tenantByRoom = {};
    for (final t in tenants) {
      if (t.roomId != null) {
        tenantByRoom[t.roomId!] = t;
      }
    }

    return Column(
      children: sortedFloors.map((floor) {
        final floorRooms = grouped[floor]!;
        floorRooms.sort((a, b) => a.roomNumber.compareTo(b.roomNumber));
        final floorLabel = floorRooms.isNotEmpty ? floorRooms.first.floorLabel : floor;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Floor $floorLabel',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${floorRooms.length} rooms',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            ...floorRooms.map((room) {
              final tenant = tenantByRoom[room.id];
              return _RoomCard(room: room, tenant: tenant);
            }),
          ],
        );
      }).toList(),
    );
  }

  int _floorOrderKey(String floor) {
    switch (floor) {
      case 'G': return 0;
      case 'F': return 1;
      case 'S': return 2;
      case 'T': return 3;
      default: return 9;
    }
  }
}

// ══════════════════════════════════════════════════════════════
// ROOM CARD
// ══════════════════════════════════════════════════════════════
class _RoomCard extends StatelessWidget {
  final Room room;
  final Tenant? tenant;

  const _RoomCard({required this.room, this.tenant});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(room.status);
    final statusBg = statusColor.withValues(alpha: 0.1);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderMuted),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Room number
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                room.displayRoomNumber,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: AppColors.neutralDark,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Floor + status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.floorLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (tenant != null && room.isOccupied)
                    Text(
                      tenant!.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.neutralDark,
                      ),
                    ),
                ],
              ),
            ),
            // Status badge
            _statusBadge(room.status, statusBg, statusColor),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'occupied':
        return AppColors.success;
      case 'void':
        return Colors.grey;
      case 'maintenance':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _statusBadge(String status, Color bg, Color fg) {
    String label;
    IconData icon;
    switch (status) {
      case 'occupied':
        label = 'Occupied';
        icon = Icons.check_circle;
        break;
      case 'void':
        label = 'Void';
        icon = Icons.crop_square;
        break;
      case 'maintenance':
        label = 'Maint.';
        icon = Icons.build;
        break;
      default:
        label = status;
        icon = Icons.help_outline;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
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
