import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/services/supabase_service.dart';
import 'app_providers.dart';

// ─── Auth State Model ─────────────────────────────────────────────────────────
enum AuthStatus {
  idle,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthStateModel {
  final AuthStatus status;
  final String? errorMessage;
  final User? user;

  const AuthStateModel({
    this.status = AuthStatus.idle,
    this.errorMessage,
    this.user,
  });

  bool get isLoading      => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get hasError       => status == AuthStatus.error;

  AuthStateModel copyWith({
    AuthStatus? status,
    String? errorMessage,
    User? user,
  }) {
    return AuthStateModel(
      status: status ?? this.status,
      errorMessage: errorMessage,
      user: user ?? this.user,
    );
  }
}

// ─── AuthNotifier ────────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthStateModel> {
  final SupabaseService _service;

  AuthNotifier(this._service) : super(const AuthStateModel()) {
    _init();
  }

  void _init() {
    final user = _service.currentUser;
    if (user != null) {
      state = AuthStateModel(status: AuthStatus.authenticated, user: user);
    } else {
      state = const AuthStateModel(status: AuthStatus.unauthenticated);
    }
  }

  // ─── Sign In ───────────────────────────────────────────────────────────────
  Future<bool> signIn(String email, String password) async {
    try {
      print('DEBUG: AuthNotifier: Attempting sign-in for $email');
      final response = await _service.signInWithEmail(email, password);
      
      if (response.user != null) {
        print('DEBUG: AuthNotifier: Login successful: ${response.user!.id}');
        state = AuthStateModel(status: AuthStatus.authenticated, user: response.user);
        return true;
      }
      print('DEBUG: AuthNotifier: Login failed: No user in response');
      return false;
    } on AuthException catch (e) {
      print('DEBUG: AuthNotifier: AuthException: ${e.message}');
      dev.log('Auth error: ${e.message}', name: 'Auth', error: e);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _parseAuthException(e),
      );
      return false;
    } catch (e, stack) {
      print('DEBUG: AuthNotifier: Unexpected error: $e');
      print('DEBUG: AuthNotifier: Stacktrace: $stack');
      dev.log('Unexpected login error', name: 'Auth', error: e);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'An unexpected error occurred: ${e.toString()}',
      );
      return false;
    }
  }

  // ─── Sign Up ───────────────────────────────────────────────────────────────
  Future<bool> signUp(String email, String password, String name) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    dev.log('Attempting signup for: $email', name: 'Auth');

    try {
      final response = await _service.signUpWithEmailAndName(email, password, name);
      
      if (response.user != null) {
        dev.log('Signup successful for ${response.user!.email}', name: 'Auth');
        state = AuthStateModel(status: AuthStatus.authenticated, user: response.user);
        return true;
      }
      return false;
    } on AuthException catch (e) {
      dev.log('Signup error: ${e.message}', name: 'Auth', error: e);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _parseSignUpException(e),
      );
      return false;
    } catch (e) {
      dev.log('Unexpected signup error', name: 'Auth', error: e);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Signup failed. Please check your connection.',
      );
      return false;
    }
  }
  // ─── Reset Password ───────────────────────────────────────────────────────
  Future<bool> resetPassword(String email) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      dev.log('Sending reset password link to $email', name: 'Auth');
      await _service.resetPassword(email);
      state = state.copyWith(status: AuthStatus.idle);
      return true;
    } catch (e) {
      dev.log('Failed to send reset link', name: 'Auth', error: e);
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Failed to send reset link. Please try again.',
      );
      return false;
    }
  }

  // ─── Google Sign In ────────────────────────────────────────────────────────
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      await _service.signInWithGoogle();
      // OAuth flow handles its own state via authStateProvider stream
      return true;
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, errorMessage: 'Google sign-in failed.');
      return false;
    }
  }

  // ─── Sign Out ──────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _service.signOut();
    state = const AuthStateModel(status: AuthStatus.unauthenticated);
  }

  void clearError() {
    state = state.copyWith(status: AuthStatus.idle, errorMessage: null);
  }

  // ─── Error message helpers ────────────────────────────────────────────────
  String _parseAuthException(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials')) return 'Incorrect email or password.';
    if (msg.contains('email not confirmed')) {
      return 'Login Failed: Email not confirmed. Please ensure "Confirm Email" is turned OFF in Supabase Auth settings.';
    }
    if (msg.contains('too many requests')) return 'Too many attempts. Please wait.';
    return 'Auth Error: ${e.message}';
  }

  String _parseSignUpException(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('user already registered')) return 'This email is already taken.';
    if (msg.contains('weak_password')) return 'Password must be at least 6 characters.';
    return e.message;
  }
}

// ─── Provider ──────────────────────────────────────────────────────────────
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthStateModel>((ref) {
  final service = ref.read(supabaseServiceProvider);
  return AuthNotifier(service);
});
