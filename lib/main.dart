// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_config.dart';
import 'widgets/responsive_shell.dart';
import 'services/update_checker_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Supabase Initialization ──────────────────────
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: HostelManagerApp(),
    ),
  );
}

class HostelManagerApp extends ConsumerStatefulWidget {
  const HostelManagerApp({super.key});

  @override
  ConsumerState<HostelManagerApp> createState() => _HostelManagerAppState();
}

class _HostelManagerAppState extends ConsumerState<HostelManagerApp> {
  bool _showForceUpdate = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    final service = ref.read(updateCheckerServiceProvider);
    final result = await service.checkForUpdates();

    if (result.isForceUpdateRequired && mounted) {
      setState(() => _showForceUpdate = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Force update guard — blocks entire app if version is too old
    if (_showForceUpdate) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.system_update_alt, size: 64, color: Colors.red),
                  const SizedBox(height: 24),
                  const Text(
                    'Critical Update Required',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your app version is no longer compatible with the current database schema. Please download the latest version to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      // In production, this would open the app store / internal download link
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Download Latest Version'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'Hostel Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const ResponsiveShell(),
    );
  }
}
