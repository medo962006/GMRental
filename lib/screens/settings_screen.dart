// lib/screens/settings_screen.dart
// Settings screen — shows Sign in instead of logout when guest.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_theme.dart';
import '../providers/auth_state_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final isGuest = authState.isGuest;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: isGuest
                        ? AppColors.warningBg
                        : AppColors.primary.withValues(alpha: 0.1),
                    child: Icon(
                      isGuest ? Icons.person_outline : Icons.admin_panel_settings,
                      size: 28,
                      color: isGuest ? AppColors.warningText : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isGuest ? 'Guest User' : 'Admin',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.neutralDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isGuest ? 'Signed in as guest' : 'Signed in as admin',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Actions
          if (isGuest)
            Card(
              child: ListTile(
                leading: const Icon(Icons.login, color: AppColors.primary),
                title: const Text('Sign In'),
                subtitle: const Text('Sign in to access all features'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushReplacementNamed(context, '/login'),
              ),
            )
          else
            Card(
              child: ListTile(
                leading: const Icon(Icons.logout, color: AppColors.danger),
                title: const Text('Logout'),
                subtitle: const Text('Sign out of your account'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ref.read(authStateProvider.notifier).logout();
                  Navigator.pushReplacementNamed(context, '/login');
                },
              ),
            ),
        ],
      ),
    );
  }
}