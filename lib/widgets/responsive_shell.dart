// lib/widgets/responsive_shell.dart
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
      MasareefScreen(),
      TasksScreen(),
      OperationalCostsScreen(),
      WhatsAppScreen(),
      InsuranceScreen(),
      NotificationsScreen(),
    ];

    final navItems = const <_NavItem>[
      _NavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
      _NavItem(Icons.bed_outlined, Icons.bed, 'Rooms'),
      _NavItem(Icons.receipt_long_outlined, Icons.receipt_long, 'Masareef'),
      _NavItem(Icons.checklist_outlined, Icons.checklist, 'Tasks'),
      _NavItem(Icons.trending_up_outlined, Icons.trending_up, 'Op. Costs'),
      _NavItem(Icons.chat_outlined, Icons.chat, 'WhatsApp'),
      _NavItem(Icons.shield_outlined, Icons.shield, 'Ta2meen'),
      _NavItem(Icons.notifications_outlined, Icons.notifications, 'Alerts'),
    ];

    // Unread count
    final notificationsAsync = ref.watch(adminNotificationsStreamProvider);
    final unreadCount = notificationsAsync.when(
      data: (List<AdminNotification> list) =>
          list.where((n) => !n.isReadBy('emad')).length,
      loading: () => 0,
      error: (_, __) => 0,
    );

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.canvas,
        body: Row(
          children: [
            // ── Sidebar ──
            Container(
              width: 240,
              color: AppColors.primary,
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // Logo area
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.apartment,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text('Hostel\nManager',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                height: 1.2)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(
                      color: Colors.white12, height: 1, indent: 16, endIndent: 16),
                  const SizedBox(height: 8),
                  // Nav items
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: navItems.length,
                      itemBuilder: (_, i) {
                        final item = navItems[i];
                        final isSelected = selectedIndex == i;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: ListTile(
                            selected: isSelected,
                            selectedTileColor:
                                AppColors.accent.withValues(alpha: 0.2),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            leading: Icon(
                                isSelected ? item.activeIcon : item.icon,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white60),
                            title: Text(item.label,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white70,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  fontSize: 14,
                                )),
                            onTap: () => ref
                                .read(selectedIndexProvider.notifier)
                                .state = i,
                            trailing: i == 7 && unreadCount > 0
                                ? Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                        color: AppColors.danger,
                                        shape: BoxShape.circle),
                                    child: Text('$unreadCount',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // ── Main content ──
            Expanded(child: screens[selectedIndex]),
          ],
        ),
      );
    }

    // ── Mobile ──
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(navItems[selectedIndex].label),
        actions: [
          // Bell badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () =>
                    ref.read(selectedIndexProvider.notifier).state = 7,
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        color: AppColors.danger, shape: BoxShape.circle),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text('$unreadCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: screens[selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) =>
            ref.read(selectedIndexProvider.notifier).state = i,
        destinations: [
          for (int i = 0; i < navItems.length; i++)
            NavigationDestination(
              icon: i == 7 && unreadCount > 0
                  ? Badge(
                      label: Text('$unreadCount',
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold)),
                      child: Icon(navItems[i].icon),
                    )
                  : Icon(navItems[i].icon),
              selectedIcon: Icon(navItems[i].activeIcon),
              label: navItems[i].label,
            ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}
