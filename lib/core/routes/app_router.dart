import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
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
