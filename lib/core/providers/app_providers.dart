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
  // Watch auth state to react to login/logout
  ref.watch(authStateProvider);
  final user = Supabase.instance.client.auth.currentUser;
  print('DEBUG: currentUserProvider: ${user?.id} (${user?.email})');
  return user?.id;
});

// ─── Current User Email ───────────────────────────────────────
final currentUserEmailProvider = Provider<String?>((ref) {
  return Supabase.instance.client.auth.currentUser?.email;
});

// ─── Is Logged In ─────────────────────────────────────────────
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

// ─── User Profile Provider (Future) ──────────────────────────
final userProfileProvider = FutureProvider<UserModel?>((ref) async {
  final userId = ref.watch(currentUserProvider);
  print('DEBUG: userProfileProvider: Watching userId: $userId');
  
  if (userId == null) {
    print('DEBUG: userProfileProvider: userId is NULL, returning null profile');
    return null;
  }
  
  final service = ref.read(supabaseServiceProvider);
  final profile = await service.getUserProfile(userId);
  print('DEBUG: userProfileProvider: Final resolved role for $userId: ${profile?.role}');
  return profile;
});

// ─── User Role Provider (Future) ─────────────────────────────
final userRoleProvider = FutureProvider<String>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  final role    = profile?.role ?? 'user';
  print('DEBUG: userRoleProvider: Resolved role: $role');
  return role;
});

// ─── Approved Kitchens Provider (Future) ──────────────────────
final approvedKitchensProvider = FutureProvider<List<KitchenModel>>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  return await service.getApprovedKitchens();
});

final kitchenByIdProvider = FutureProvider.family<KitchenModel?, String>((ref, id) async {
  final service = ref.read(supabaseServiceProvider);
  return await service.getKitchenById(id);
});

// ─── Kitchen Menus Provider (Future Family) ───────────────────
final kitchenMenusProvider = FutureProvider.family<List<MenuModel>, String>((ref, kitchenId) async {
  final service = ref.read(supabaseServiceProvider);
  return await service.getKitchenMenus(kitchenId);
});

// ─── Admin Providers ──────────────────────────────────────────
final adminKitchensProvider = FutureProvider<List<KitchenModel>>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  return await service.getAllKitchensAdmin();
});

final adminOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  final service = ref.read(supabaseServiceProvider);
  return service.getAdminOrdersStream().map(
    (list) => list.map((m) => OrderModel.fromJson(m)).toList(),
  );
});

final pendingOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  final service = ref.read(supabaseServiceProvider);
  return service.getPendingOrdersStream().map(
    (list) => list.map((m) => OrderModel.fromJson(m)).toList(),
  );
});

final allUsersProvider = FutureProvider<List<UserModel>>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  return await service.getAllUsers();
});

// ─── User Orders Provider (Future) ────────────────────────────
final userOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  final userId = ref.watch(currentUserProvider);
  if (userId == null) return Stream.value([]);
  final service = ref.read(supabaseServiceProvider);
  return service.getUserOrdersStream(userId).map(
    (list) => list.map((m) => OrderModel.fromJson(m)).toList(),
  );
});

// ─── Delivery Orders Provider (Future) ────────────────────────
final deliveryOrdersProvider = StreamProvider<List<DeliveryModel>>((ref) {
  final userId = ref.watch(currentUserProvider);
  if (userId == null) return Stream.value([]);
  final service = ref.read(supabaseServiceProvider);
  return service.getDeliveryBoyDeliveriesStream(userId).map(
    (list) => list.map((m) => DeliveryModel.fromJson(m)).toList(),
  );
});

// ─── Live Order Stream Provider (Family) ──────────────────────
final liveOrderStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, orderId) {
  final service = ref.read(supabaseServiceProvider);
  return service.getLiveOrderStream(orderId);
});

// ─── Live Delivery Stream Provider (Family) ───────────────────
final liveDeliveryStreamProvider = StreamProvider.family<List<DeliveryModel>, String>((ref, orderId) {
  final service = ref.read(supabaseServiceProvider);
  return service.getLiveDeliveryStream(orderId).map(
    (list) => list.map((e) => DeliveryModel.fromJson(e)).toList(),
  );
});

typedef TrackingData = ({String status, DeliveryModel? delivery});

// ─── Delivery Location Stream (Family) ────────────────────────
final deliveryLocationProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, deliveryBoyId) {
  final service = ref.read(supabaseServiceProvider);
  return service.getDeliveryLocationStream(deliveryBoyId);
});

// ─── Cart Management ──────────────────────────────────────────
class CartItem {
  final MenuModel menu;
  final int quantity;

  CartItem({required this.menu, this.quantity = 1});

  CartItem copyWith({int? quantity}) {
    return CartItem(
      menu: menu,
      quantity: quantity ?? this.quantity,
    );
  }
}

class CartNotifier extends StateNotifier<Map<String, CartItem>> {
  CartNotifier() : super({});

  void addItem(MenuModel menu) {
    final existing = state[menu.id];
    if (existing != null) {
      state = {
        ...state,
        menu.id: existing.copyWith(quantity: existing.quantity + 1),
      };
    } else {
      state = {
        ...state,
        menu.id: CartItem(menu: menu, quantity: 1),
      };
    }
  }

  void removeItem(String menuId) {
    final existing = state[menuId];
    if (existing == null) return;

    if (existing.quantity > 1) {
      state = {
        ...state,
        menuId: existing.copyWith(quantity: existing.quantity - 1),
      };
    } else {
      final newState = Map<String, CartItem>.from(state);
      newState.remove(menuId);
      state = newState;
    }
  }

  void clear() => state = {};

  double get total {
    double sum = 0;
    state.forEach((key, item) {
      sum += item.menu.price * item.quantity;
    });
    return sum;
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, Map<String, CartItem>>((ref) {
  return CartNotifier();
});

// ─── Delivery Online Status ──────────────────────────────────
final isOnlineProvider = StateProvider<bool>((ref) => false);
