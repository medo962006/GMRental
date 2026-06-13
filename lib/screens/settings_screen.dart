// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/update_checker_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _checkingUpdates = false;
  String? _checkResult;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: theme.colorScheme.primaryContainer,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── App Version Info ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.info_outline, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('App Information',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ]),
                  const Divider(height: 24),
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                      final info = snap.data!;
                      return Column(children: [
                        _infoRow('App Name', info.appName),
                        _infoRow('Package', info.packageName),
                        _infoRow('Base Version', 'v${info.version}'),
                        _infoRow('Build Number', info.buildNumber),
                      ]);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Shorebird Patch Info ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.system_update, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('OTA Update Status',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ]),
                  const Divider(height: 24),
                  _buildShorebirdInfo(context),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _checkingUpdates ? null : _manualCheckUpdates,
                      icon: _checkingUpdates
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.refresh, size: 18),
                      label: Text(_checkingUpdates ? 'Checking...' : 'Check for Updates'),
                    ),
                  ),
                  if (_checkResult != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Icon(
                          _checkResult!.contains('available') ? Icons.check_circle : Icons.info,
                          size: 16,
                          color: _checkResult!.contains('available') ? Colors.green : Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_checkResult!, style: const TextStyle(fontSize: 12))),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Version Guard Status ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.security, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Version Guard',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ]),
                  const Divider(height: 24),
                  Consumer(builder: (context, ref, _) {
                    final updateCheck = ref.watch(startupUpdateCheckProvider);
                    return updateCheck.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (_, __) => _infoRow('Status', 'Unable to verify', valueColor: Colors.orange),
                      data: (result) {
                        if (result.isForceUpdateRequired) {
                          return Column(children: [
                            _infoRow('Status', 'Update Required', valueColor: Colors.red),
                            if (result.minRequiredVersion != null)
                              _infoRow('Minimum Version', 'v${result.minRequiredVersion}'),
                            if (result.currentVersion != null)
                              _infoRow('Your Version', 'v${result.currentVersion}'),
                          ]);
                        }
                        return Column(children: [
                          _infoRow('Status', 'Up to date', valueColor: Colors.green),
                          if (result.minRequiredVersion != null)
                            _infoRow('Min Required', 'v${result.minRequiredVersion}'),
                          _infoRow('Shorebird', result.isUpdateAvailable ? 'Patch available' : 'Up to date',
                              valueColor: result.isUpdateAvailable ? Colors.blue : null),
                        ]);
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Hostel Manager v1.0.0',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildShorebirdInfo(BuildContext context) {
    final updater = ShorebirdUpdater();
    final available = updater.isAvailable;
    return Column(children: [
      _infoRow('Shorebird Updater', available ? 'Available (Release build)' : 'Not Available (Debug build)',
          valueColor: available ? Colors.green : Colors.grey),
      if (available)
        FutureBuilder<int?>(
          future: ref.read(updateCheckerServiceProvider).getCurrentPatch(),
          builder: (context, snap) {
            final patch = snap.data;
            return _infoRow('Active Patch', patch != null ? 'Patch $patch' : 'Base install (no patch)');
          },
        ),
    ]);
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: valueColor)),
        ],
      ),
    );
  }

  Future<void> _manualCheckUpdates() async {
    setState(() { _checkingUpdates = true; _checkResult = null; });
    try {
      final service = ref.read(updateCheckerServiceProvider);
      final result = await service.manualCheck();
      if (mounted) {
        setState(() {
          _checkingUpdates = false;
          if (result.errorMessage != null) {
            _checkResult = 'Error: ${result.errorMessage}';
          } else if (result.isUpdateAvailable) {
            _checkResult = 'New patch available! It will be applied on next restart.';
          } else {
            _checkResult = 'App is up to date. No new patches found.';
          }
        });
      }
    } catch (e) {
      if (mounted) { setState(() { _checkingUpdates = false; _checkResult = 'Error: $e'; }); }
    }
  }
}
