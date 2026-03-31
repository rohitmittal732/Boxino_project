//   • Protected routes (/home, /profile, /kitchen-detail, 
//     /order-summary, /order-success, /order-tracking):
//     → Redirect to /login if user has no active session.
//   • Auth routes (/login, /signup):
//     → Redirect to /home if user already has an active session.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:boxino/core/providers/auth_notifier.dart';
import 'package:boxino/core/providers/app_providers.dart';
import 'package:boxino/data/services/firebase_service.dart';
import 'package:boxino/features/auth/presentation/screens/splash_screen.dart';
import 'package:boxino/features/auth/presentation/screens/phone_login_screen.dart';
import 'package:boxino/features/auth/presentation/screens/otp_verify_screen.dart';
import 'package:boxino/features/profile/presentation/screens/profile_setup_screen.dart';
import 'package:boxino/features/home/presentation/screens/home_screen.dart';
import 'package:boxino/features/kitchen/presentation/screens/kitchen_detail_screen.dart';
import 'package:boxino/features/order/presentation/screens/order_summary_screen.dart';
import 'package:boxino/features/order/presentation/screens/order_success_screen.dart';
import 'package:boxino/features/order/presentation/screens/order_tracking_screen.dart';
import 'package:boxino/features/order/presentation/screens/kitchen_selection_screen.dart';
import 'package:boxino/features/order/presentation/screens/rating_screen.dart';
import 'package:boxino/features/order/presentation/screens/rating_success_screen.dart';
import 'package:boxino/features/order/presentation/screens/order_history_screen.dart';
import 'package:boxino/features/profile/presentation/screens/profile_screen.dart';
import 'package:boxino/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:boxino/features/roles/admin_panel_screen.dart';
import 'package:boxino/features/roles/delivery_boy_screen.dart';
import 'package:boxino/domain/models/app_models.dart';

// ── Auth helper ─────────────────────────────────────────────────────────────
bool get _isAuthenticated {
  try {
    return fb.FirebaseAuth.instance.currentUser != null;
  } catch (e) {
    print('WARNING: AppRouter: _isAuthenticated check failed: $e');
    return false;
  }
}

// ── Protected routes — require auth ─────────────────────────────────────────
const _protectedRoutes = [
  '/home',
  '/history',

  '/profile',
  '/kitchen-detail',
  '/order-summary',
  '/order-success',
  '/order-tracking',
  '/admin',
  '/delivery',
  '/edit-profile',
];

// ── Auth-only routes — redirect away if already logged in ───────────────────
const _authRoutes = ['/login', '/otp'];

// ── Router Notifier ──────────────────────────────────────────────────────────
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  RouterNotifier(this._ref) {
    // 1. Listen to Riverpod state for role caching
    _ref.listen(authNotifierProvider, (previous, next) {
      if (next.isAuthenticated) {
        _ref.read(userProfileProvider.future);
      }
      notifyListeners();
    });

    // 2. 🔥 GOLDEN RULE: Raw Firebase Auth Listener (Fail-safe)
    try {
      fb.FirebaseAuth.instance.authStateChanges().listen((user) {
        print('DEBUG: AppRouter: Firebase authStateChange: ${user?.uid}');
        notifyListeners();
      });

      // 3. 🔥 NEW: Listen to role changes so guards refresh correctly
      _ref.listen(userRoleProvider, (prev, next) {
        if (prev?.valueOrNull != next.valueOrNull) {
          notifyListeners();
        }
      });
    } catch (e) {
      print('ERROR: AppRouter: Failed to attach auth listener: $e');
    }
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) => RouterNotifier(ref));

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) async {
      final location = state.matchedLocation;
      final authState = ref.read(authNotifierProvider);
      final authenticated = authState.isAuthenticated;

      print('DEBUG: AppRouter: location=$location, authenticated=$authenticated');

      // 1. Unauthenticated users: Redirect if trying to access protected routes
      if (!authenticated) {
        if (_protectedRoutes.any((r) => location.startsWith(r))) {
          print('DEBUG: AppRouter: Unauthenticated, redirecting to /login');
          return '/login';
        }
        return null;
      }

      // 2. Authenticated users: Handle role-based navigation and protection
      final user = fb.FirebaseAuth.instance.currentUser;
      if (user == null) return '/login'; 

      final roleAsync = ref.watch(userRoleProvider);
      final role = roleAsync.valueOrNull ?? 'user';

      print('DEBUG: AppRouter: Resolved role for redirect: $role');

      // 3. New User Guard: If logged in but no profile, redirect to setup
      final profileAsync = ref.watch(userProfileProvider);
      
      // If we are authenticated but haven't fetched profile yet or it's missing
      // (Exception: don't redirect if already on profile-setup)
      if (location != '/profile-setup' && !location.startsWith('/otp')) {
        if (profileAsync.hasValue && profileAsync.value == null) {
          print('DEBUG: AppRouter: Profile missing, redirecting to /profile-setup');
          return '/profile-setup';
        }
      }

      // Prevent traversing back to auth routes while logged in
      if (_authRoutes.contains(location) || location == '/') {
        if (role == 'admin') return '/admin';
        if (role == 'delivery') return '/delivery';
        return '/home';
      }

      // Role-based route protection guards
      if (location == '/admin' && role != 'admin') return '/home';
      if (location == '/delivery' && role != 'delivery') return '/home';
      
      return null;
    },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const PhoneLoginScreen(),
    ),
    GoRoute(
      path: '/otp',
      builder: (context, state) {
        final phone = state.extra as String? ?? '';
        return OtpVerifyScreen(phone: phone);
      },
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
      path: '/history',
      builder: (context, state) => const OrderHistoryScreen(), // NEW
    ),
    GoRoute(
      path: '/profile',

      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/edit-profile',
      builder: (context, state) => const EditProfileScreen(),
    ),
    GoRoute(
      path: '/kitchen-detail',
      builder: (context, state) {
        final kitchen = state.extra as KitchenModel;
        return KitchenDetailScreen(kitchen: kitchen);
      },
    ),
    GoRoute(
      path: '/order-summary',
      builder: (context, state) => const OrderSummaryScreen(),
    ),
    GoRoute(
      path: '/order-success',
      builder: (context, state) {
        final orderId = state.extra as String;
        return OrderSuccessScreen(orderId: orderId);
      },
    ),
    GoRoute(
      path: '/order-tracking',
      builder: (context, state) {
        if (state.extra is OrderModel) {
          return OrderTrackingScreen(orderId: (state.extra as OrderModel).id, initialOrder: state.extra as OrderModel);
        }
        final orderId = state.extra as String;
        return OrderTrackingScreen(orderId: orderId);
      },
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminPanelScreen(),
    ),
    GoRoute(
      path: '/delivery',
      builder: (context, state) => const DeliveryBoyScreen(),
    ),
    GoRoute(
      path: '/rate-selection',
      builder: (context, state) => const KitchenSelectionScreen(),
    ),
    GoRoute(
      path: '/rate/:kid',
      builder: (context, state) {
        final kitchenId = state.pathParameters['kid']!;
        final kitchen = state.extra as KitchenModel?;
        return RatingScreen(kitchenId: kitchenId, kitchen: kitchen);
      },
    ),
    GoRoute(
      path: '/rate-success',
      builder: (context, state) => const RatingSuccessScreen(),
    ),
    ],
  );
});

