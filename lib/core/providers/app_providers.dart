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
final otpEmailProvider = StateProvider<String>((ref) => '');

// ─── Auth State Stream (reactive) ─────────────────────────────
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

// ─── Current User ID ──────────────────────────────────────────
final currentUserProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  return Supabase.instance.client.auth.currentUser?.id;
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
  if (userId == null) return null;
  final service = ref.read(supabaseServiceProvider);
  return await service.getUserProfile(userId);
});

// ─── User Role Provider (Future) ─────────────────────────────
final userRoleProvider = FutureProvider<String>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  return profile?.role ?? 'user';
});

// ─── Approved Kitchens Provider (Stream) ──────────────────────
final approvedKitchensProvider = StreamProvider<List<KitchenModel>>((ref) {
  final service = ref.read(supabaseServiceProvider);
  return service.watchApprovedKitchens();
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

// ─── Admin Ratings Provider (Future) ──────────────────────────
final adminRatingsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  return await service.getAllRatingsAdmin();
});

// ─── Unrated Kitchens Provider ────────────────────────────────
final unratedKitchensCountProvider = FutureProvider<int>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  return await service.countUnratedDeliveredOrders();
});

// ─── Admin Kitchens Provider (Stream) ────────────────────────
final adminKitchensProvider = StreamProvider<List<KitchenModel>>((ref) {
  final service = ref.read(supabaseServiceProvider);
  return service.watchAllKitchensAdmin();
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
final deliveryOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  final userId = ref.watch(currentUserProvider);
  if (userId == null) return Stream.value([]);
  final service = ref.read(supabaseServiceProvider);
  return service.getDeliveryBoyDeliveriesStream(userId).map(
    (list) => list.map((m) => OrderModel.fromJson(m)).toList(),
  );
});

final liveOrderStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, orderId) {
  final service = ref.read(supabaseServiceProvider);
  return service.getLiveOrderStream(orderId);
});

// Simplified Tracking for Lite Mode (Status only)
final combinedTrackingProvider = StreamProvider.family<Map<String, dynamic>, String>((ref, orderId) async* {
  final service = ref.read(supabaseServiceProvider);
  
  await for (final orderList in service.getLiveOrderStream(orderId)) {
    if (orderList.isEmpty) {
      yield {'order': null, 'riderId': null};
      continue;
    }
    
    final orderMap = orderList.first;
    final order = OrderModel.fromJson(orderMap);
    
    yield {
      'order': order,
      'riderId': order.deliveryBoyId,
    };
  }
});

final riderDetailsProvider = FutureProvider.family<UserModel?, String>((ref, userId) async {
  final service = ref.read(supabaseServiceProvider);
  return await service.getUserProfile(userId);
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

  int get totalQuantity {
    int count = 0;
    state.forEach((key, item) {
      count += item.quantity;
    });
    return count;
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, Map<String, CartItem>>((ref) {
  return CartNotifier();
});

// ─── Delivery Online Status ──────────────────────────────────
final isOnlineProvider = StateProvider<bool>((ref) => false);

// ─── UI State Providers (Home) ────────────────────────────────
final selectedCategoryProvider = StateProvider<String>((ref) => 'All');
final searchQueryProvider = StateProvider<String>((ref) => '');
final navIndexProvider = StateProvider<int>((ref) => 0);

// ─── Optimized/Memoized Filtered Kitchens ─────────────────────
final filteredKitchensProvider = Provider<AsyncValue<List<KitchenModel>>>((ref) {
  final kitchensAsync = ref.watch(approvedKitchensProvider);
  final selectedCategory = ref.watch(selectedCategoryProvider);
  final searchQuery = ref.watch(searchQueryProvider).toLowerCase();

  return kitchensAsync.whenData((kitchens) {
    return kitchens.where((k) {
      final matchesCategory = selectedCategory == 'All' || 
                             (selectedCategory == 'Veg' && k.isVeg) || 
                             (selectedCategory == 'Non-Veg' && k.isNonVeg);
      final matchesSearch = k.name.toLowerCase().contains(searchQuery);
      return matchesCategory && matchesSearch;
    }).toList();
  });
});
