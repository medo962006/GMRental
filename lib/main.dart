// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'services/notification_service.dart';
import 'providers/app_providers.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/booking_success_screen.dart';
import 'models/booking.dart';

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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.runAllChecks();
      // Flip paid tenants whose due_date has passed to unpaid.
      // See autoUpdatePaymentStatus() for full behavior.
      unawaited(
        ref
            .read(supabaseRepositoryProvider)
            .autoUpdatePaymentStatus()
            .then<int>((_) => 0, onError: (_) => 0),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hostel Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
      onGenerateRoute: (settings) {
        // Handle booking success screen with argument
        if (settings.name == '/booking-success') {
          final booking = settings.arguments as Booking?;
          if (booking == null) return null;
          return MaterialPageRoute(
            builder: (_) => BookingSuccessScreen(booking: booking),
          );
        }
        return null;
      },
    );
  }
}