// lib/screens/notifications_screen.dart
// Phase 3.7: Admin Notification Panel — mobile-first.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/admin_notification.dart';
import '../providers/app_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  // Current admin ID — in production this would come from auth
  static const _currentAdminId = 'emad';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(adminNotificationsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all read',
            onPressed: () => _markAllRead(ref),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (List<AdminNotification> notifications) {
          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No notifications',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          // Group by category
          final rentDue =
              notifications.where((n) => n.isRentDue).toList();
          final insurance =
              notifications.where((n) => n.isInsuranceAlert).toList();
          final tasks =
              notifications.where((n) => n.isTaskPending).toList();

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              if (rentDue.isNotEmpty) ...[
                _sectionHeader('Rent Due', Colors.orange, Icons.payments),
                ...rentDue.map((n) => _buildNotificationCard(context, ref, n)),
              ],
              if (insurance.isNotEmpty) ...[
                _sectionHeader('Insurance', Colors.purple, Icons.shield),
                ...insurance.map((n) => _buildNotificationCard(context, ref, n)),
              ],
              if (tasks.isNotEmpty) ...[
                _sectionHeader('Tasks', Colors.blue, Icons.checklist),
                ...tasks.map((n) => _buildNotificationCard(context, ref, n)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(title,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  Widget _buildNotificationCard(
      BuildContext context, WidgetRef ref, AdminNotification n) {
    final isRead = n.isReadBy(_currentAdminId);
    final color = n.isRentDue
        ? Colors.orange
        : n.isInsuranceAlert
            ? Colors.purple
            : Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: isRead ? 0.5 : 2,
      color: isRead ? Colors.grey.shade50 : null,
      child: InkWell(
        onTap: () {
          if (!isRead) {
            ref
                .read(supabaseRepositoryProvider)
                .markNotificationRead(n.id, _currentAdminId);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Unread indicator
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: isRead ? Colors.transparent : color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.title,
                        style: TextStyle(
                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                          fontSize: 14,
                          color: isRead ? Colors.grey.shade600 : null,
                        )),
                    const SizedBox(height: 4),
                    Text(n.body,
                        style: TextStyle(
                          fontSize: 12,
                          color: isRead ? Colors.grey.shade500 : Colors.grey.shade700,
                        )),
                    const SizedBox(height: 4),
                    Text(_timeAgo(n.createdAt),
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade400)),
                  ],
                ),
              ),
              // Delete button
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => ref
                    .read(supabaseRepositoryProvider)
                    .deleteNotification(n.id),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _markAllRead(WidgetRef ref) {
    // This would need the full list — for now, handled per-card
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
