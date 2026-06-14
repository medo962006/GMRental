// lib/widgets/responsive_shell.dart
// Desktop: deep blue sidebar. Mobile: floating circular nav menu.
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
import 'floating_nav_menu.dart';

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

    final navLabels = const [
      'Dashboard', 'Rooms', 'Masareef', 'Tasks',
      'Op. Costs', 'WhatsApp', 'Ta2meen', 'Alerts',
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
        body: Row(children: [
          // ── Sidebar ──
          Container(
            width: 240,
            color: AppColors.primary,
            child: Column(children: [
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                        color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.apartment, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('Hostel\nManager',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, height: 1.2)),
                ]),
              ),
              const SizedBox(height: 24),
              const Divider(color: Colors.white12, height: 1, indent: 16, endIndent: 16),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: navLabels.length,
                  itemBuilder: (_, i) {
                    final isSelected = selectedIndex == i;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        selected: isSelected,
                        selectedTileColor: AppColors.accent.withValues(alpha: 0.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: Icon(
                          _navIcons[i],
                          color: isSelected ? Colors.white : Colors.white60,
                        ),
                        title: Text(navLabels[i],
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              fontSize: 14,
                            )),
                        onTap: () => ref.read(selectedIndexProvider.notifier).state = i,
                        trailing: i == 7 && unreadCount > 0
                            ? Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                                child: Text('$unreadCount',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ]),
          ),
          Expanded(child: screens[selectedIndex]),
        ]),
      );
    }

    // ── Mobile: AppBar + Floating Menu ──
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(navLabels[selectedIndex]),
        actions: [
          if (unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: GestureDetector(
                  onTap: () => ref.read(selectedIndexProvider.notifier).state = 7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('$unreadCount new',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: screens[selectedIndex],
      floatingActionButton: FloatingNavMenu(
        selectedIndex: selectedIndex,
        onSelect: (i) => ref.read(selectedIndexProvider.notifier).state = i,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

const _navIcons = <IconData>[
  Icons.dashboard,
  Icons.bed,
  Icons.receipt_long,
  Icons.checklist,
  Icons.trending_up,
  Icons.chat,
  Icons.shield,
  Icons.notifications,
];
