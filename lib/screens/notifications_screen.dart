// lib/screens/notifications_screen.dart
// Notification Center — create, read, dismiss, delete.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_theme.dart';
import '../models/admin_notification.dart';
import '../providers/app_providers.dart';
import '../repositories/supabase_repository.dart';

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
                  Text('No notifications', style: TextStyle(color: AppColors.textSecondary)),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Alert'),
      ),
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton.icon(
            onPressed: () => _createTestNotification(context, ref),
            icon: const Icon(Icons.bug_report, size: 18),
            label: const Text('Test'),
          ),
        ],
      ),
    );
  }

  void _createTestNotification(BuildContext ctx, WidgetRef ref) async {
    try {
      await ref.read(supabaseRepositoryProvider).createNotification(
        title: '🔔 Test Notification',
        body: 'This is a test alert created at ${DateTime.now().toString().substring(11, 19)}. If you see this, notifications are working!',
        category: 'rent_due',
      );
      ref.invalidate(adminNotificationsStreamProvider);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('✅ Test notification created!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCreateForm(BuildContext ctx, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String category = 'rent_due';

    showDialog(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDialogState) => AlertDialog(
          title: const Text('Create Notification'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyCtrl,
                decoration: const InputDecoration(labelText: 'Body', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'rent_due', child: Text('Rent Due')),
                  DropdownMenuItem(value: 'insurance_alert', child: Text('Insurance Alert')),
                  DropdownMenuItem(value: 'task_pending', child: Text('Task Pending')),
                  DropdownMenuItem(value: 'payment_received', child: Text('Payment Received')),
                  DropdownMenuItem(value: 'tenant_checkout', child: Text('Tenant Checkout')),
                ],
                onChanged: (v) => setDialogState(() => category = v!),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty || bodyCtrl.text.isEmpty) return;
                try {
                  await ref.read(supabaseRepositoryProvider).createNotification(
                    title: titleCtrl.text,
                    body: bodyCtrl.text,
                    category: category,
                  );
                  if (dCtx.mounted) Navigator.pop(dCtx);
                  ref.invalidate(adminNotificationsStreamProvider);
                } catch (e) {
                  if (dCtx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
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
            : notification.isTaskPending
                ? AppColors.secondary
                : notification.category == 'payment_received'
                    ? AppColors.success
                    : notification.category == 'tenant_checkout'
                        ? AppColors.danger
                        : AppColors.infoText;
    final icon = notification.isRentDue
        ? Icons.payments
        : notification.isInsuranceAlert
            ? Icons.shield
            : notification.isTaskPending
                ? Icons.checklist
                : notification.category == 'payment_received'
                    ? Icons.account_balance_wallet
                    : notification.category == 'tenant_checkout'
                        ? Icons.exit_to_app
                        : Icons.notifications;

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
                        style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
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
                    onTap: () => _confirmDelete(context, ref),
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

  void _confirmDelete(BuildContext ctx, WidgetRef ref) {
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Delete Notification'),
        content: const Text('This notification will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              try {
                await ref.read(supabaseRepositoryProvider).deleteNotification(notification.id);
                if (dCtx.mounted) Navigator.pop(dCtx);
                ref.invalidate(adminNotificationsStreamProvider);
              } catch (e) {
                if (dCtx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
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
