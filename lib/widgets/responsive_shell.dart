// lib/widgets/responsive_shell.dart
// Desktop: deep blue sidebar. Mobile: hamburger → drawer with nav items.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_theme.dart';
import '../providers/app_providers.dart';
import '../screens/dashboard_screen.dart';
import '../screens/rooms_screen.dart';
import '../screens/masareef_screen.dart';
import '../screens/tasks_screen.dart';
import '../screens/operational_costs_screen.dart';
import '../screens/whatsapp_screen.dart';
import '../screens/insurance_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/calendar_screen.dart';
import '../models/admin_notification.dart';

class ResponsiveShell extends ConsumerWidget {
  const ResponsiveShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 800;
    final selectedIndex = ref.watch(selectedIndexProvider);

    final screens = const <Widget>[
      DashboardScreen(),
      RoomsScreen(),
      CalendarScreen(),
      MasareefScreen(),
      TasksScreen(),
      OperationalCostsScreen(),
      WhatsAppScreen(),
      InsuranceScreen(),
      NotificationsScreen(),
    ];

    final navLabels = const [
      'Dashboard', 'Rooms', 'Calendar', 'Masareef', 'Tasks',
      'Op. Costs', 'WhatsApp', 'Ta2meen', 'Alerts',
    ];

    final navIcons = const [
      Icons.dashboard,
      Icons.bed,
      Icons.calendar_month,
      Icons.receipt_long,
      Icons.checklist,
      Icons.trending_up,
      Icons.chat,
      Icons.shield,
      Icons.notifications,
    ];

    // Unread count
    final notificationsAsync = ref.watch(adminNotificationsStreamProvider);
    final unreadCount = notificationsAsync.when(
      data: (List<AdminNotification> list) =>
          list.where((n) => !n.isReadBy('emad')).length,
      loading: () => 0,
      error: (_, __) => 0,
    );

    // ── Building Switcher (shared widget) ──
    Widget _buildBuildingSwitcher({required bool isDesktop}) {
      return Consumer(builder: (context, ref, _) {
        final bId = ref.watch(currentBuildingIdProvider);
        final bg = isDesktop ? Colors.white12 : AppColors.canvas;
        final selectedBg = isDesktop ? Colors.white24 : AppColors.primary;
        final selectedFg = isDesktop ? Colors.white : Colors.white;
        final unselectedFg = isDesktop ? Colors.white54 : AppColors.textSecondary;
        final borderColor = isDesktop ? Colors.white12 : AppColors.borderMuted;

        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => ref.read(currentBuildingIdProvider.notifier).state = 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: bId == 1 ? selectedBg : Colors.transparent,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                  ),
                  child: Text('Gawy',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: bId == 1 ? selectedFg : unselectedFg)),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => ref.read(currentBuildingIdProvider.notifier).state = 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: bId == 2 ? selectedBg : Colors.transparent,
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                  ),
                  child: Text('Baraka',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: bId == 2 ? selectedFg : unselectedFg)),
                ),
              ),
            ),
          ]),
        );
      });
    }

    // ── Drawer content (shared between desktop sidebar and mobile drawer) ──
    Widget buildNavItem(int i) {
      final isSelected = selectedIndex == i;
      final isMobile = !isDesktop;

      if (isMobile) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: ListTile(
            selected: isSelected,
            selectedTileColor: AppColors.accent.withValues(alpha: 0.15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accent.withValues(alpha: 0.15) : AppColors.canvas,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(navIcons[i],
                  size: 20,
                  color: isSelected ? AppColors.accent : AppColors.textSecondary),
            ),
            title: Text(navLabels[i],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.neutralDark,
                )),
            trailing: i == 7 && unreadCount > 0
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$unreadCount',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  )
                : null,
            onTap: () {
              ref.read(selectedIndexProvider.notifier).state = i;
              Navigator.pop(context); // close drawer
            },
          ),
        );
      }

      // Desktop sidebar item
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: ListTile(
          selected: isSelected,
          selectedTileColor: AppColors.accent.withValues(alpha: 0.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: Icon(navIcons[i],
              color: isSelected ? Colors.white : Colors.white60),
          title: Text(navLabels[i],
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              )),
          trailing: i == 7 && unreadCount > 0
              ? Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                      color: AppColors.danger, shape: BoxShape.circle),
                  child: Text('$unreadCount',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              : null,
          onTap: () => ref.read(selectedIndexProvider.notifier).state = i,
        ),
      );
    }

    // ── Desktop: sidebar + content ──
    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.canvas,
        body: Row(children: [
          Container(
            width: 250,
            color: AppColors.primary,
            child: Column(children: [
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(12)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset('assets/images/gmrental_logo.png',
                          width: 40, height: 40, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('Hostel Manager',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                ]),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildBuildingSwitcher(isDesktop: true),
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white12, height: 1, indent: 16, endIndent: 16),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: navLabels.length,
                  itemBuilder: (_, i) => buildNavItem(i),
                ),
              ),
            ]),
          ),
          Expanded(child: screens[selectedIndex]),
        ]),
      );
    }

    // ── Mobile: AppBar with hamburger + Drawer ──
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(navLabels[selectedIndex]),
        actions: [
          // Building switcher in AppBar
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: SizedBox(
                width: 120,
                child: _buildBuildingSwitcher(isDesktop: false),
              ),
            ),
          ),
          if (unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    ref.read(selectedIndexProvider.notifier).state = 7;
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.notifications, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text('$unreadCount',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
              ),
            ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20))),
        child: SafeArea(
          child: Column(children: [
            // Drawer header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset('assets/images/gmrental_logo.png',
                        width: 44, height: 44, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Hostel Manager',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  Consumer(builder: (context, ref, _) {
                    final bId = ref.watch(currentBuildingIdProvider);
                    return Text(bId == 1 ? 'Main Building' : 'Baraka',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary));
                  }),
                ]),
              ]),
            ),
            const Divider(height: 1),

            // ── Building Switcher ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: _buildBuildingSwitcher(isDesktop: false),
            ),
            const Divider(height: 1),
            // Nav items
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: navLabels.length,
                itemBuilder: (_, i) => buildNavItem(i),
              ),
            ),
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('v1.0.0',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ),
          ]),
        ),
      ),
      body: screens[selectedIndex],
    );
  }
}