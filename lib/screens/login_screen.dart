// lib/screens/login_screen.dart
// App lock screen — the app cannot be opened or viewed without the access password.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_theme.dart';
import '../providers/auth_state_provider.dart';
import '../services/auth_guard.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (_submitting || !_formKey.currentState!.validate()) return;

    if (!verifyAppPassword(_passwordController.text)) {
      setState(() {
        _error = 'Incorrect password. Try again.';
        _passwordController.clear();
      });
      return;
    }

    // Grant access for this session, then enter the app.
    ref.read(authSessionProvider.notifier).state = true;
    ref.read(authStateProvider.notifier).login();
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.lock, size: 44, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'App Locked',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.neutralDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter the access password to open the app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Password form
                  Form(
                    key: _formKey,
                    child: TextField(
                      controller: _passwordController,
                      obscureText: true,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Access Password',
                        hintText: 'Enter access password',
                        prefixIcon: const Icon(Icons.key),
                        errorText: _error,
                      ),
                      onSubmitted: (_) => _handleLogin(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _handleLogin,
                      child: const Text('Unlock'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
