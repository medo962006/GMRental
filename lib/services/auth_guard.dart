// lib/services/auth_guard.dart
// Password gate for destructive CRUD actions + unique device code per device.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The current admin password. Change this to rotate.
const String adminPassword = 'admin123';

/// Tracks whether the user has been authenticated this session.
final authSessionProvider = StateProvider<bool>((ref) => false);

/// Device code provider — unique per device, persisted in SharedPreferences.
final deviceCodeProvider = StateProvider<String>((ref) => '');

/// Generates or retrieves a persistent device code for this device.
/// Format: "DEV-XXXXX" where X is alphanumeric.
Future<String> getDeviceCode(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  String? code = prefs.getString('device_code');
  if (code != null && code.isNotEmpty) {
    // Update last_seen in Supabase asynchronously (fire-and-forget)
    _updateLastSeen(code);
    return code;
  }

  // Generate a new unique device code
  final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
  final random = DateTime.now().microsecond.toString().padLeft(3, '0');
  code = 'DEV-$timestamp$random';

  await prefs.setString('device_code', code);

  // Register in Supabase asynchronously (fire-and-forget)
  _registerDevice(code, ref);

  return code;
}

void _updateLastSeen(String code) {
  // Fire-and-forget — don't block the UI
  try {
    Supabase.instance.client
        .from('device_codes')
        .update({'last_seen_at': DateTime.now().toIso8601String()})
        .eq('code', code)
        .then((_) => null)
        .catchError((_) => null);
  } catch (_) {}
}

void _registerDevice(String code, WidgetRef ref) {
  // Fire-and-forget
  try {
    final deviceName = Platform.localHostname;
    Supabase.instance.client
        .from('device_codes')
        .upsert({
          'code': code,
          'device_name': deviceName,
          'is_active': true,
          'created_at': DateTime.now().toIso8601String(),
          'last_seen_at': DateTime.now().toIso8601String(),
        })
        .then((_) => null)
        .catchError((_) => null);
  } catch (_) {}
}

/// Shows a password dialog. Returns true if the password is correct.
Future<bool> showPasswordDialog(BuildContext context, WidgetRef ref) async {
  // Already authenticated this session — skip
  if (ref.read(authSessionProvider)) return true;

  final ctrl = TextEditingController();
  String? error;
  bool success = false;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Row(children: [
          Icon(
            success ? Icons.check_circle : Icons.lock_outline,
            color: success ? Colors.green : Colors.amber,
          ),
          const SizedBox(width: 8),
          Text(success ? 'Authenticated' : 'Admin Authentication'),
        ]),
        content: success
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified, color: Colors.green, size: 48),
                  const SizedBox(height: 12),
                  const Text('Access granted! Proceeding...',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  FutureBuilder<String>(
                    future: getDeviceCode(ref),
                    builder: (_, snap) {
                      if (!snap.hasData) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Device: ${snap.data}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      );
                    },
                  ),
                ],
              )
            : SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Enter admin password to proceed.',
                        style: TextStyle(fontSize: 13)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ctrl,
                      obscureText: true,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter admin password',
                        errorText: error,
                        prefixIcon: const Icon(Icons.key),
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) {
                        if (ctrl.text.trim() == adminPassword) {
                          ref.read(authSessionProvider.notifier).state = true;
                          setDialogState(() {
                            success = true;
                            error = null;
                          });
                          // Auto-close after showing success
                          Future.delayed(const Duration(milliseconds: 1200), () {
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          });
                        } else {
                          setDialogState(() => error = 'Incorrect password. Try again.');
                        }
                      },
                    ),
                  ],
                ),
              ),
        actions: success
            ? null
            : [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (ctrl.text.trim() == adminPassword) {
                      ref.read(authSessionProvider.notifier).state = true;
                      setDialogState(() {
                        success = true;
                        error = null;
                      });
                      // Auto-close after showing success
                      Future.delayed(const Duration(milliseconds: 1200), () {
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      });
                    } else {
                      setDialogState(() => error = 'Incorrect password. Try again.');
                    }
                  },
                  child: const Text('Confirm'),
                ),
              ],
      ),
    ),
  );

  return result == true;
}

/// Resets the auth session (call on app pause/timeout).
void clearAuthSession(WidgetRef ref) {
  ref.read(authSessionProvider.notifier).state = false;
}
