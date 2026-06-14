// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_config.dart';
import 'widgets/responsive_shell.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  // Initialize local notifications
  await NotificationService.instance.initialize();

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
  @override
  void initState() {
    super.initState();
    // Run notification checks on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.runAllChecks();
    });
  }

  @override
  Widget build(BuildContext context) {
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
