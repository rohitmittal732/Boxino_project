// ─────────────────────────────────────────────────────────────────────────────
// Auth Providers — Riverpod state management for authentication.
//
// • authLoadingProvider  — simple bool for loading state
// • authErrorProvider    — last error message
// • authNotifierProvider — re-exported from auth_notifier.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';

// Re-export AuthNotifier for convenience
export 'auth_notifier.dart' show authNotifierProvider, AuthStateModel, AuthStatus;

/// Tracks whether an auth operation is in progress (for lightweight usage).
final authLoadingProvider = StateProvider<bool>((ref) => false);

/// Stores the last error message from an auth operation.
final authErrorProvider = StateProvider<String?>((ref) => null);
