// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'widgets/responsive_shell.dart';
import 'services/notification_service.dart';
import 'providers/app_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

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
  Timer? _paymentTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.runAllChecks();
      // Auto-update payment status based on due dates
      ref.read(supabaseRepositoryProvider).autoUpdatePaymentStatus().catchError((_) => 0);
    });
    // Run auto-update every 6 hours so overdue tenants are caught daily
    _paymentTimer = Timer.periodic(const Duration(hours: 6), (_) {
      ref.read(supabaseRepositoryProvider).autoUpdatePaymentStatus().catchError((_) => 0);
    });
  }

  @override
  void dispose() {
    _paymentTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hostel Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const ResponsiveShell(),
    );
  }
}
