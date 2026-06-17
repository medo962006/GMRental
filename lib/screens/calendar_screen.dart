// lib/screens/calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_theme.dart';
import '../providers/app_providers.dart';
import '../models/tenant.dart';
import '../models/room.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _currentMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  void _goToPrevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _goToNextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _currentMonth = DateTime(now.year, now.month, 1);
      _selectedDay = DateTime(now.year, now.month, now.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final buildingId = ref.watch(currentBuildingIdProvider);
    final tenantsAsync = ref.watch(tenantsStreamProvider(buildingId));
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          // ── Header ──
          _buildHeader(isDesktop),
          // ── Legend ──
          _buildLegend(),
          const SizedBox(height: 8),
          // ── Calendar + Detail ──
          Expanded(
            child: isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildCalendarGrid(tenantsAsync)),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: _buildDayDetail(tenantsAsync)),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(flex: 3, child: _buildCalendarGrid(tenantsAsync)),
                      if (_selectedDay != null)
                        Expanded(flex: 2, child: _buildDayDetail(tenantsAsync)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // HEADER
  // ════════════════════════════════════════════════════════
  Widget _buildHeader(bool isDesktop) {
    final monthNames = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24 : 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Month nav
            IconButton(
              onPressed: _goToPrevMonth,
              icon: const Icon(Icons.chevron_left, size: 22),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.canvas,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: _goToToday,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${monthNames[_currentMonth.month - 1]} ${_currentMonth.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _goToNextMonth,
              icon: const Icon(Icons.chevron_right, size: 22),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.canvas,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 8),
            // Today button
            TextButton.icon(
              onPressed: _goToToday,
              icon: const Icon(Icons.today, size: 16),
              label: const Text('Today', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // LEGEND
  // ════════════════════════════════════════════════════════
  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _legendDot(AppColors.success, 'Paid'),
          const SizedBox(width: 16),
          _legendDot(AppColors.danger, 'Unpaid'),
          const SizedBox(width: 16),
          _legendDot(AppColors.warning, 'Due Today'),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  // ════════════════════════════════════════════════════════
  // CALENDAR GRID
  // ════════════════════════════════════════════════════════
  Widget _buildCalendarGrid(AsyncValue<List<Tenant>> tenantsAsync) {
    final firstDay = _currentMonth;
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startWeekday = firstDay.weekday; // 1=Mon, 7=Sun
    final daysInMonth = lastDay.day;
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);

    // Build a map: day → list of tenants due that day
    final Map<int, List<Tenant>> dueByDay = {};
    tenantsAsync.whenData((tenants) {
      for (final t in tenants) {
        if (t.dueDate == null) continue;
        final dueDay = t.dueDate!.day;
        dueByDay.putIfAbsent(dueDay, () => []).add(t);
      }
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          // Day headers
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(d,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary)),
                        ),
                      ))
                  .toList(),
            ),
          ),
          // Calendar grid
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cellWidth = constraints.maxWidth / 7;
                final cellHeight = cellWidth * 1.1; // taller to fit tenant name chips
                final totalRows = ((daysInMonth + startWeekday - 1) / 7).ceil();
                final gridHeight = totalRows * cellHeight;

                return SingleChildScrollView(
                  child: SizedBox(
                    height: gridHeight,
                    child: _buildGridCells(
                      firstDay, daysInMonth, startWeekday,
                      todayNormalized, dueByDay, cellWidth, cellHeight,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridCells(
    DateTime firstDay,
    int daysInMonth,
    int startWeekday,
    DateTime today,
    Map<int, List<Tenant>> dueByDay,
    double cellWidth,
    double cellHeight,
  ) {
    final cells = <Widget>[];

    // Empty cells before the first day
    for (int i = 1; i < startWeekday; i++) {
      cells.add(SizedBox(width: cellWidth, height: cellHeight));
    }

    // Day cells
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final isToday = date == today;
      final isSelected = _selectedDay != null &&
          date.year == _selectedDay!.year &&
          date.month == _selectedDay!.month &&
          date.day == _selectedDay!.day;
      final tenantsDue = dueByDay[day] ?? [];

      cells.add(GestureDetector(
        onTap: () {
          setState(() => _selectedDay = date);
        },
        child: Container(
          width: cellWidth,
          height: cellHeight,
          padding: const EdgeInsets.all(2),
          child: _buildDayCell(day, isToday, isSelected, tenantsDue),
        ),
      ));
    }

    return Wrap(children: cells);
  }

  Widget _buildDayCell(int day, bool isToday, bool isSelected, List<Tenant> tenantsDue) {
    Color? bgColor;
    Color borderColor = Colors.transparent;

    if (isSelected) {
      borderColor = AppColors.accent;
    }

    if (tenantsDue.isNotEmpty) {
      final allPaid = tenantsDue.every((t) => t.isPaid);
      if (allPaid) {
        bgColor = AppColors.successBg;
      } else if (isToday) {
        bgColor = AppColors.warningBg;
      } else {
        bgColor = AppColors.dangerBg;
      }
    }

    if (isToday && bgColor == null) {
      bgColor = AppColors.accent.withValues(alpha: 0.08);
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor,
          width: isSelected ? 2 : 0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day number
          Text(
            '$day',
            style: TextStyle(
              fontSize: 11,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
              color: isToday
                  ? AppColors.accent
                  : isSelected
                      ? AppColors.primary
                      : AppColors.neutralDark,
            ),
          ),
          // Tenant name chips
          if (tenantsDue.isNotEmpty)
            Expanded(
              child: _buildTenantChips(tenantsDue),
            ),
        ],
      ),
    );
  }

  Widget _buildTenantChips(List<Tenant> tenants) {
    // Show up to 4 tenant name chips, then overflow indicator
    const maxChips = 4;
    final visible = tenants.take(maxChips).toList();
    final overflow = tenants.length - maxChips;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...visible.map((t) {
          final color = t.isPaid ? AppColors.success : AppColors.danger;
          // Use first name only to fit in small space
          final firstWord = t.name.split(' ').first;
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 1),
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              firstWord,
              style: TextStyle(
                fontSize: 7.5,
                fontWeight: FontWeight.w600,
                color: color == AppColors.success ? AppColors.successText : AppColors.dangerText,
              ),
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          );
        }),
        if (overflow > 0)
          Text(
            '+$overflow',
            style: const TextStyle(fontSize: 7, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════
  // DAY DETAIL PANEL
  // ════════════════════════════════════════════════════════
  Widget _buildDayDetail(AsyncValue<List<Tenant>> tenantsAsync) {
    if (_selectedDay == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 48, color: AppColors.borderMuted),
            const SizedBox(height: 12),
            const Text('Select a day',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    final selectedDate = _selectedDay!;

    return tenantsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (tenants) {
        // Find tenants whose due_date falls on the selected day of month
        // Match by day-of-month only, so someone who moved in on the 22nd
        // shows up on every 22nd regardless of month/year
        final dueTenants = tenants.where((t) {
          if (t.dueDate == null) return false;
          return t.dueDate!.day == selectedDate.day;
        }).toList();

        // Sort: unpaid first, then paid
        dueTenants.sort((a, b) {
          if (a.isPaid != b.isPaid) return a.isPaid ? 1 : -1;
          return a.name.compareTo(b.name);
        });

        // Also find overdue tenants (past due, not yet paid) — different day
        final overdueTenants = tenants.where((t) {
          if (t.dueDate == null || t.isPaid) return false;
          return t.dueDate!.isBefore(selectedDate) &&
              t.dueDate!.day != selectedDate.day;
        }).toList();
        overdueTenants.sort((a, b) => a.name.compareTo(b.name));

        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.04),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '${selectedDate.day}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatSelectedDate(selectedDate),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.neutralDark,
                          ),
                        ),
                        Text(
                          '${dueTenants.length} due · ${overdueTenants.length} overdue',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Tenant list
              Expanded(
                child: dueTenants.isEmpty && overdueTenants.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 40, color: AppColors.success.withValues(alpha: 0.4)),
                            const SizedBox(height: 8),
                            const Text('No payments due this day',
                                style: TextStyle(
                                    color: AppColors.textSecondary, fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        children: [
                          if (dueTenants.isNotEmpty) ...[
                            _sectionHeader('Due Today', AppColors.accent),
                            ...dueTenants.map((t) => _tenantTile(t)),
                          ],
                          if (overdueTenants.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _sectionHeader('Overdue', AppColors.danger),
                            ...overdueTenants.map((t) => _tenantTile(t)),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tenantTile(Tenant tenant) {
    final isOverdue = tenant.isOverdue;
    final statusColor = tenant.isPaid
        ? AppColors.success
        : isOverdue
            ? AppColors.danger
            : AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tenant.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutralDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Due: ${_formatDate(tenant.dueDate!)} · ${tenant.insuranceAmount.toStringAsFixed(0)} EGP',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              tenant.isPaid ? 'PAID' : isOverdue ? 'OVERDUE' : 'DUE',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSelectedDate(DateTime date) {
    final months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
