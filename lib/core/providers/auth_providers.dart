// ─────────────────────────────────────────────────────────────────────────────
// Auth Providers — Riverpod state management for the Email + Password flow.
//
// These providers manage UI state specific to the authentication flow:
//   • Loading indicators during async operations
//   • Error messages to display to the user
//
// Note: The app-wide auth session stream is in app_providers.dart (unchanged).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks whether an auth operation (login, signup, logout) is in progress.
/// The UI reads this to show/hide loading spinners and disable buttons.
final authLoadingProvider = StateProvider<bool>((ref) => false);

/// Stores a user-friendly error message when an auth operation fails.
/// Set to null when there is no error. The UI reads this to show snackbars.
final authErrorProvider = StateProvider<String?>((ref) => null);
