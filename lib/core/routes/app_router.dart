// ─────────────────────────────────────────────────────────────────────────────
// App Router — GoRouter with auth-based redirect guards.
//
// GUARDS:
//   • Protected routes (/home, /profile-setup, /kitchen-detail, /subscription,
//     /order-summary, /order-success, /order-tracking):
//     → Redirect to /login if user has no active session.
//   • Auth routes (/login, /signup):
//     → Redirect to /home if user already has an active session.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:boxino/features/auth/presentation/screens/splash_screen.dart';
import 'package:boxino/features/auth/presentation/screens/login_screen.dart';
import 'package:boxino/features/auth/presentation/screens/signup_screen.dart';
import 'package:boxino/features/profile/presentation/screens/profile_setup_screen.dart';
import 'package:boxino/features/home/presentation/screens/home_screen.dart';
import 'package:boxino/features/kitchen/presentation/screens/kitchen_detail_screen.dart';
import 'package:boxino/features/subscription/presentation/screens/subscription_screen.dart';
import 'package:boxino/features/order/presentation/screens/order_summary_screen.dart';
import 'package:boxino/features/order/presentation/screens/order_success_screen.dart';
import 'package:boxino/features/order/presentation/screens/order_tracking_screen.dart';

// ── Auth helper ─────────────────────────────────────────────────────────────
bool get _isAuthenticated =>
    Supabase.instance.client.auth.currentSession != null;

// ── Protected routes — require auth ─────────────────────────────────────────
const _protectedRoutes = [
  '/home',
  '/profile-setup',
  '/kitchen-detail',
  '/subscription',
  '/order-summary',
  '/order-success',
  '/order-tracking',
];

// ── Auth-only routes — redirect away if already logged in ───────────────────
const _authRoutes = ['/login', '/signup'];

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final location = state.matchedLocation;

    // Skip redirect logic for splash
    if (location == '/') return null;

    final authenticated = _isAuthenticated;

    // Guard: unauthenticated user trying to access protected route
    if (_protectedRoutes.any((r) => location.startsWith(r))) {
      if (!authenticated) return '/login';
    }

    // Guard: authenticated user trying to access login/signup
    if (_authRoutes.contains(location)) {
      if (authenticated) return '/home';
    }

    return null; // No redirect needed
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/profile-setup',
      builder: (context, state) => const ProfileSetupScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/kitchen-detail',
      builder: (context, state) => const KitchenDetailScreen(),
    ),
    GoRoute(
      path: '/subscription',
      builder: (context, state) => const SubscriptionScreen(),
    ),
    GoRoute(
      path: '/order-summary',
      builder: (context, state) => OrderSummaryScreen(
        orderData: state.extra as Map<String, dynamic>? ?? {},
      ),
    ),
    GoRoute(
      path: '/order-success',
      builder: (context, state) => const OrderSuccessScreen(),
    ),
    GoRoute(
      path: '/order-tracking',
      builder: (context, state) => const OrderTrackingScreen(),
    ),
  ],
);
