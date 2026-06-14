// lib/screens/notifications_screen.dart
// Phase 3.7: Notification Center — design system overhaul.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_theme.dart';
import '../models/admin_notification.dart';
import '../providers/app_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});
  static const _currentAdminId = 'emad';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(adminNotificationsStreamProvider);

    return Scaffold(
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (List<AdminNotification> notifications) {
          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 48, color: AppColors.textSecondary),
                  SizedBox(height: 12),
                  Text('No notifications',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: notifications.length,
            itemBuilder: (_, i) =>
                _NotificationCard(notification: notifications[i]),
          );
        },
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  final AdminNotification notification;
  const _NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRead = notification.isReadBy(NotificationsScreen._currentAdminId);
    final color = notification.isRentDue
        ? AppColors.warning
        : notification.isInsuranceAlert
            ? AppColors.accent
            : AppColors.infoText;
    final icon = notification.isRentDue
        ? Icons.payments
        : notification.isInsuranceAlert
            ? Icons.shield
            : Icons.checklist;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isRead ? AppColors.borderMuted : color.withValues(alpha: 0.3),
            width: isRead ? 1 : 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Accent strip
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: isRead ? Colors.transparent : color,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
              ),
            ),
            // Avatar circle
            Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notification.title,
                        style: TextStyle(
                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                          fontSize: 14,
                          color: isRead ? AppColors.textSecondary : AppColors.neutralDark,
                        )),
                    const SizedBox(height: 4),
                    Text(notification.body,
                        style: TextStyle(
                          fontSize: 12,
                          color: isRead ? AppColors.textSecondary : AppColors.neutralDark,
                        )),
                    const SizedBox(height: 4),
                    Text(_timeAgo(notification.createdAt),
                        style: TextStyle(
                            fontSize: 10, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!isRead)
                    GestureDetector(
                      onTap: () => ref
                          .read(supabaseRepositoryProvider)
                          .markNotificationRead(
                              notification.id, NotificationsScreen._currentAdminId),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.successBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.done, size: 14, color: AppColors.success),
                      ),
                    ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => ref
                        .read(supabaseRepositoryProvider)
                        .deleteNotification(notification.id),
                    child: const Icon(Icons.close, size: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
