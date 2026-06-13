// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'widgets/responsive_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Supabase Initialization ──────────────────────
  // NOTE: RLS should be disabled for initial testing,
  // or bypassed using a service role key.
  // For production, enable RLS and use proper auth.

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

class HostelManagerApp extends StatelessWidget {
  const HostelManagerApp({super.key});

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
