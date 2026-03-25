// ─────────────────────────────────────────────────────────────────────────────
// AuthNotifier — Riverpod StateNotifier for Authentication.
//
// Manages the full auth lifecycle: sign-in, sign-up, Google OAuth, sign-out.
// Screens watch authNotifierProvider.state to react to auth changes.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/services/supabase_service.dart';
import 'app_providers.dart';

// ─── Auth State Model ─────────────────────────────────────────────────────────
enum AuthStatus {
  idle,         // No ongoing operation
  loading,      // Async operation in progress
  authenticated, // User is logged in
  unauthenticated, // User is NOT logged in
  error,        // An error occurred
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
      errorMessage: errorMessage,      // null clears the error
      user: user ?? this.user,
    );
  }
}

// ─── AuthNotifier ────────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthStateModel> {
  final SupabaseService _service;

  AuthNotifier(this._service) : super(const AuthStateModel()) {
    // Initialize: check if already logged in
    final currentUser = _service.currentUser;
    if (currentUser != null) {
      state = AuthStateModel(status: AuthStatus.authenticated, user: currentUser);
    } else {
      state = const AuthStateModel(status: AuthStatus.unauthenticated);
    }
  }

  // ─── Sign In (Email + Password) ────────────────────────────────────────────
  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final response = await _service.signInWithEmail(email, password);
      state = AuthStateModel(status: AuthStatus.authenticated, user: response.user);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _parseAuthException(e),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _parseGenericError(e),
      );
      return false;
    }
  }

  // ─── Sign Up (Email + Password + Name) ────────────────────────────────────
  Future<bool> signUp(String email, String password, String name) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final response = await _service.signUpWithEmailAndName(email, password, name);
      state = AuthStateModel(status: AuthStatus.authenticated, user: response.user);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _parseSignUpException(e),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _parseGenericError(e),
      );
      return false;
    }
  }

  // ─── Google Sign In ────────────────────────────────────────────────────────
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final success = await _service.signInWithGoogle();
      if (success) {
        final currentUser = _service.currentUser;
        state = AuthStateModel(status: AuthStatus.authenticated, user: currentUser);
        return true;
      } else {
        // User likely cancelled the Google sign-in
        state = state.copyWith(status: AuthStatus.unauthenticated, errorMessage: null);
        return false;
      }
    } on AuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Google sign-in failed: ${e.message}',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Google sign-in failed. Please try again.',
      );
      return false;
    }
  }

  // ─── Sign Out ──────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      await _service.signOut();
      state = const AuthStateModel(status: AuthStatus.unauthenticated);
    } catch (_) {
      state = const AuthStateModel(status: AuthStatus.unauthenticated);
    }
  }

  // ─── Reset state to idle ──────────────────────────────────────────────────
  void clearError() {
    state = state.copyWith(status: AuthStatus.idle, errorMessage: null);
  }

  // ─── Error message helpers ────────────────────────────────────────────────
  String _parseAuthException(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials') || msg.contains('invalid_grant')) {
      return 'Incorrect email or password.';
    } else if (msg.contains('email not confirmed')) {
      return 'Please verify your email before signing in.';
    } else if (msg.contains('too many requests')) {
      return 'Too many attempts. Please wait and try again.';
    }
    return 'Login failed. Please check your credentials.';
  }

  String _parseSignUpException(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('user already registered') || msg.contains('already exists')) {
      return 'This email is already registered. Try signing in.';
    } else if (msg.contains('weak_password') || msg.contains('password should be at least')) {
      return 'Password is too weak. Please use a stronger one.';
    } else if (msg.contains('email address is invalid')) {
      return 'The email address is invalid.';
    }
    return 'Signup failed. Please try again.';
  }

  String _parseGenericError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('network') || msg.contains('socketexception') || msg.contains('connection')) {
      return 'No internet connection. Please check your network.';
    }
    return 'An unexpected error occurred. Please try again.';
  }
}

// ─── Provider ──────────────────────────────────────────────────────────────
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthStateModel>((ref) {
  final service = ref.read(supabaseServiceProvider);
  return AuthNotifier(service);
});
