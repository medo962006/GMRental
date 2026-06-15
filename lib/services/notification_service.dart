// lib/services/notification_service.dart
// Phase 3.7: Local push notifications + Supabase admin_notifications sync.
// Web: uses browser Notification API via dart:js. Mobile: flutter_local_notifications.
import 'dart:js' as js;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tenant.dart';
import '../models/insurance_ledger.dart';
import '../models/task_routine.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) return; // No-op on web — browser handles it natively

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) {
      _showWebNotification(title: title, body: body);
      return;
    }

    if (!_initialized) await initialize();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'hostel_alerts',
        'Hostel Alerts',
        channelDescription: 'Rent, insurance, and task notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(id, title, body, details);
  }

  /// Show a browser notification (works in WebView on modern Android too)
  void _showWebNotification({required String title, required String body}) {
    try {
      final context = js.context;
      if (context == null) return;

      // Check if Notification API exists
      final hasNotification = context.hasProperty('Notification');
      if (!hasNotification) return;

      final perm = context['Notification']['permission'];
      if (perm == 'denied') return;

      // Escape strings for JS
      final t = title.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('"', '\\"');
      final b = body.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('"', '\\"');

      if (perm == 'default') {
        context.callMethod('eval', [
          "Notification.requestPermission().then(p => { if (p === 'granted') new Notification('$t', {body: '$b'}); })"
        ]);
        return;
      }

      // Permission granted — show notification
      context.callMethod('eval', [
        "new Notification('$t', {body: '$b'})"
      ]);
    } catch (_) {
      // Silent fail — don't crash the app
    }
  }

  /// Create a notification in Supabase AND fire a local push.
  /// Deduplicates by title+category — if an identical notification already
  /// exists (and is unread), skips creation to avoid spam on every app open.
  /// Returns the created/existing notification ID, or null on failure.
  Future<String?> createRemoteNotification({
    required String title,
    required String body,
    required String category,
  }) async {
    try {
      final client = Supabase.instance.client;

      // ── Dedup: check if an identical notification already exists ──
      final existing = await client
          .from('admin_notifications')
          .select('id')
          .eq('title', title)
          .eq('category', category)
          .eq('is_read', false)
          .limit(1)
          .maybeSingle();

      if (existing != null) {
        final id = existing['id'] as String;
        await show(id: id.hashCode, title: title, body: body);
        return id;
      }

      // ── Create new ──
      final data = await client.from('admin_notifications').insert({
        'title': title,
        'body': body,
        'category': category,
      }).select().single();
      final id = data['id'] as String;
      await show(id: id.hashCode, title: title, body: body);
      return id;
    } catch (e) {
      try {
        await show(id: title.hashCode, title: title, body: body);
      } catch (_) {}
      return null;
    }
  }

  /// Check for overdue rent and fire notifications.
  Future<void> checkRentDueAlerts(List<Tenant> tenants) async {
    for (final t in tenants) {
      if (t.isUnpaid && t.dueDate != null) {
        final daysOverdue = DateTime.now().difference(t.dueDate!).inDays;
        if (daysOverdue >= 0) {
          await createRemoteNotification(
            title: 'Rent Due: Room ${t.roomId}',
            body:
                '${t.name}\'s rent is ${daysOverdue == 0 ? "due today" : "$daysOverdue days overdue"}. Please collect payment.',
            category: 'rent_due',
          );
        }
      }
    }
  }

  /// Check for insurance due dates.
  Future<void> checkInsuranceAlerts(List<InsuranceLedger> ledgers) async {
    for (final l in ledgers) {
      if (l.hasRemaining && l.dueDateForRemaining != null) {
        final daysUntil =
            l.dueDateForRemaining!.difference(DateTime.now()).inDays;
        if (daysUntil <= 0) {
          await createRemoteNotification(
            title: 'Ta2meen Reminder: Insurance #${l.id}',
            body:
                'Insurance payment of ${l.remainingBalance.toStringAsFixed(0)} LE is ${daysUntil == 0 ? "due today" : "${-daysUntil} days overdue"}.',
            category: 'insurance_alert',
          );
        }
      }
    }
  }

  /// Check for stale pending tasks (>24h).
  Future<void> checkTaskAlerts(List<TaskRoutine> tasks) async {
    final now = DateTime.now();
    for (final t in tasks) {
      if (t.isPending) {
        final hoursOld = now.difference(t.createdAt).inHours;
        if (hoursOld >= 24) {
          await createRemoteNotification(
            title: 'Pending Task: ${t.title}',
            body:
                'Task "${t.title}" has been pending for ${hoursOld}h. Assigned to: ${t.assignedTo}',
            category: 'task_pending',
          );
        }
      }
    }
  }

  /// Run all checks against Supabase data.
  Future<void> runAllChecks() async {
    try {
      final client = Supabase.instance.client;

      // Check rent
      final tenantsData = await client
          .from('tenants')
          .select()
          .eq('status', 'active')
          .eq('payment_status', 'unpaid');
      final tenants =
          (tenantsData as List).map((e) => Tenant.fromJson(e)).toList();
      await checkRentDueAlerts(tenants);

      // Check insurance
      final insData = await client
          .from('insurance_ledger')
          .select()
          .inFilter('status', ['partial']);
      final ledgers =
          (insData as List).map((e) => InsuranceLedger.fromJson(e)).toList();
      await checkInsuranceAlerts(ledgers);

      // Check tasks
      final taskData = await client
          .from('task_routines')
          .select()
          .eq('status', 'pending');
      final tasks =
          (taskData as List).map((e) => TaskRoutine.fromJson(e)).toList();
      await checkTaskAlerts(tasks);
    } catch (_) {
      // Silent fail — don't crash the app if notification check fails
    }
  }
}
