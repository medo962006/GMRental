// lib/providers/auth_state_provider.dart
// Auth state management — tracks the app-access status for the current session.
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks the auth state of the app.
class AuthState {
  final bool isLoggedIn;
  final bool isGuest;

  const AuthState({this.isLoggedIn = false, this.isGuest = false});

  bool get isAuthenticated => isLoggedIn || isGuest;

  AuthState copyWith({bool? isLoggedIn, bool? isGuest}) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isGuest: isGuest ?? this.isGuest,
    );
  }
}

/// Auth state notifier — manages login and logout.
class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier() : super(const AuthState());

  void login() {
    state = state.copyWith(isLoggedIn: true, isGuest: false);
  }

  void logout() {
    state = const AuthState();
  }
}

final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  return AuthStateNotifier();
});