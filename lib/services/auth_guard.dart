// lib/services/auth_guard.dart
// Password gate for destructive CRUD actions.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The current admin password. Change this to rotate.
const String adminPassword = 'admin2025';

/// Tracks whether the user has been authenticated this session.
final authSessionProvider = StateProvider<bool>((ref) => false);

/// Shows a password dialog. Returns true if the password is correct.
Future<bool> showPasswordDialog(BuildContext context, WidgetRef ref) async {
  // Already authenticated this session — skip
  if (ref.read(authSessionProvider)) return true;

  final ctrl = TextEditingController();
  String? error;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.lock_outline, color: Colors.amber),
          const SizedBox(width: 8),
          const Text('Admin Authentication'),
        ]),
        content: SizedBox(
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
                    Navigator.pop(ctx, true);
                  } else {
                    setDialogState(() => error = 'Incorrect password. Try again.');
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim() == adminPassword) {
                ref.read(authSessionProvider.notifier).state = true;
                Navigator.pop(ctx, true);
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

/// The Supabase SQL to create the admin_passwords table (one-time setup).
const String adminPasswordsTableSQL = '''
CREATE TABLE IF NOT EXISTS admin_passwords (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  password TEXT NOT NULL,
  label TEXT DEFAULT 'Active',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '30 days')
);
ALTER TABLE admin_passwords ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow read to anon" ON admin_passwords FOR SELECT TO anon USING (true);
INSERT INTO admin_passwords (password, label) VALUES ('admin2025', 'Default');
''';
