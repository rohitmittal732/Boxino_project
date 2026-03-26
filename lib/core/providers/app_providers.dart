import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/supabase_service.dart';
import '../../domain/models/app_models.dart';

// ─── Service Provider ─────────────────────────────────────────
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

// ─── OTP Email Provider ───────────────────────────────────────
/// Stores the email address during the OTP flow.
final otpEmailProvider = StateProvider<String>((ref) => '');

// ─── Auth State Stream (reactive) ─────────────────────────────
/// Streams auth state changes: logged-in, logged-out, token refresh, etc.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

// ─── Current User ID ──────────────────────────────────────────
final currentUserProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenOrNull(
    data: (state) => state.session?.user.id,
  );
});

// ─── Current User Email ───────────────────────────────────────
final currentUserEmailProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenOrNull(
    data: (state) => state.session?.user.email,
  );
});

// ─── Is Logged In ─────────────────────────────────────────────
final isLoggedInProvider = Provider<bool>((ref) {
  final userId = ref.watch(currentUserProvider);
  return userId != null;
});

// ─── User Profile Provider (Future) ───────────────────────────
final userProfileProvider = FutureProvider<UserModel?>((ref) async {
  final userId = ref.watch(currentUserProvider);
  if (userId == null) return null;
  final service = ref.read(supabaseServiceProvider);
  return await service.getUserProfile(userId);
});

// ─── Approved Kitchens Provider (Future) ──────────────────────
final approvedKitchensProvider = FutureProvider<List<KitchenModel>>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  return await service.getApprovedKitchens();
});

// ─── Admin All Kitchens Provider (Future) ─────────────────────
final adminKitchensProvider = FutureProvider<List<KitchenModel>>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  return await service.getAllKitchensAdmin();
});

// ─── User Orders Provider (Future) ────────────────────────────
final userOrdersProvider = FutureProvider<List<OrderModel>>((ref) async {
  final userId = ref.watch(currentUserProvider);
  if (userId == null) return [];
  final service = ref.read(supabaseServiceProvider);
  return await service.getUserOrders(userId);
});

// ─── Live Order Stream Provider (Family) ──────────────────────
final liveOrderStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, orderId) {
  final service = ref.read(supabaseServiceProvider);
  return service.getLiveOrderStream(orderId);
});

// ─── Delivery Boy: Online Status ──────────────────────────────
/// Tracks whether the delivery boy has toggled themselves online.
final isOnlineProvider = StateProvider<bool>((ref) => false);

// ─── Delivery Boy: Active Deliveries ─────────────────────────
/// Fetches deliveries assigned to the current delivery boy that are not yet
/// marked as 'delivered'.
final deliveryOrdersProvider = FutureProvider<List<DeliveryModel>>((ref) async {
  final userId = ref.watch(currentUserProvider);
  if (userId == null) return [];
  final service = ref.read(supabaseServiceProvider);
  return await service.getActiveDeliveries(userId);
});

// ─── Delivery Boy: Pending Orders ─────────────────────────────
/// Fetches orders in 'pending' status that have no delivery boy assigned yet.
final pendingOrdersProvider = FutureProvider<List<OrderModel>>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  return await service.getPendingOrders();
});
