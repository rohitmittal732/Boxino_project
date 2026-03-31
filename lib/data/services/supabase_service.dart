import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/app_models.dart';
import 'dart:async';
import 'dart:convert';


class SupabaseService {
  SupabaseClient get _client => Supabase.instance.client;

  User? get currentSupabaseUser => null; // Auth moved to Firebase

  ////////////////////
  /// DB QUERIES /////
  ////////////////////

  // USERS
  Future<UserModel?> getUserProfile(String userId) async {
    try {
      // 🚀 V6 Migration: Read from 'profiles' table first
      var response = await _client.from('profiles').select().eq('id', userId).maybeSingle();
      
      // Fallback to legacy 'users' table if not found in profiles
      if (response == null) {
        response = await _client.from('users').select().eq('id', userId).maybeSingle();
      }

      if (response != null) {
        return UserModel.fromJson(response);
      }
      return null;
    } catch (e) {
      print('ERROR: SupabaseService: Error fetching profile for $userId: $e');
      return null;
    }
  }


  Future<void> updateUserProfile({
    required String userId,
    String? name,
    String? phone,
    String? address,
    String? areaName,
  }) async {
    final Map<String, dynamic> updates = {};
    if (name != null) updates['name'] = name;
    if (phone != null) updates['phone'] = phone;
    if (address != null) updates['address'] = address; // Changed from user_address in profiles
    if (areaName != null) updates['area_name'] = areaName;

    if (updates.isEmpty) return;
    
    // First attempt to update 'profiles'
    try {
      await _client.from('profiles').upsert({'id': userId, ...updates});
    } catch (e) {
      // Fallback/Sync to legacy 'users' for now
      updates['user_address'] = address; // Legacy name
      await _client.from('users').update(updates).eq('id', userId);
    }
  }

  Future<void> updateUserRole(String userId, String role) async {
    try {
      // 1. Update Database (Both tables for safety during migration)
      await _client.from('profiles').update({'role': role}).eq('id', userId);
      await _client.from('users').update({'role': role}).eq('id', userId);
    } catch (e) {
      print('ERROR: SupabaseService: Error updating role for $userId: $e');
      rethrow;
    }
  }

  Future<List<UserModel>> getAllUsers({int limit = 20, int offset = 0}) async {
    final response = await _client
        .from('users')
        .select()
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (response as List).map((u) => UserModel.fromJson(u)).toList();
  }

  // KITCHENS
  Stream<List<KitchenModel>> watchApprovedKitchens() {
    return _client
        .from('kitchens')
        .stream(primaryKey: ['id'])
        .eq('is_approved', true)
        .order('name', ascending: true)
        .map((list) => list.map((data) => KitchenModel.fromJson(data)).toList());
  }

  Future<List<KitchenModel>> getApprovedKitchens({int limit = 20, int offset = 0}) async {
    final response = await _client
        .from('kitchens')
        .select()
        .eq('is_approved', true)
        .range(offset, offset + limit - 1);
    return (response as List).map((data) => KitchenModel.fromJson(data)).toList();
  }

  Future<List<KitchenModel>> getAllKitchensAdmin({int limit = 20, int offset = 0}) async {
    final response = await _client
        .from('kitchens')
        .select()
        .range(offset, offset + limit - 1);
    return (response as List).map((data) => KitchenModel.fromJson(data)).toList();
  }

  Stream<List<KitchenModel>> watchAllKitchensAdmin() {
    return _client
        .from('kitchens')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((list) => list.map((data) => KitchenModel.fromJson(data)).toList());
  }

  Stream<List<OrderModel>> watchAllOrdersAdmin() {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((list) => list.map((data) => OrderModel.fromJson(data)).toList());
  }

  Future<void> createKitchen(KitchenModel kitchen) async {
    await _client.from('kitchens').insert(kitchen.toJson());
  }

  Future<void> updateKitchen(KitchenModel kitchen) async {
    await _client.from('kitchens').update(kitchen.toJson()).eq('id', kitchen.id);
  }

  Future<void> deleteKitchen(String id) async {
    await _client.from('kitchens').delete().eq('id', id);
  }

  Future<void> toggleKitchenApproval(String id, bool isApproved) async {
    await _client.from('kitchens').update({'is_approved': isApproved}).eq('id', id);
  }

  // MENUS
  Future<List<MenuModel>> getKitchenMenus(String kitchenId) async {
    final response = await _client.from('menus').select().eq('kitchen_id', kitchenId);
    return (response as List).map((data) => MenuModel.fromJson(data)).toList();
  }

  Future<void> addMenu(MenuModel menu) async {
    await _client.from('menus').insert(menu.toJson());
  }

  Future<void> updateMenu(MenuModel menu) async {
    await _client.from('menus').update(menu.toJson()).eq('id', menu.id);
  }

  Future<void> deleteMenu(String id) async {
    await _client.from('menus').delete().eq('id', id);
  }

  Future<KitchenModel?> getKitchenById(String id) async {
    final response = await _client.from('kitchens').select().eq('id', id).maybeSingle();
    if (response != null) return KitchenModel.fromJson(response);
    return null;
  }

  // RATINGS & FEEDBACK
  Future<void> submitRating({
    required String kitchenId,
    required int rating,
    String? feedback,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _client.from('ratings').upsert({
      'user_id': user.id,
      'kitchen_id': kitchenId,
      'rating': rating,
      'feedback': feedback,
    });
  }

  Future<List<Map<String, dynamic>>> getKitchenRatings(String kitchenId) async {
    final response = await _client
        .from('ratings')
        .select('*, user:user_id(name)')
        .eq('kitchen_id', kitchenId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getAllRatingsAdmin() async {
    final response = await _client
        .from('ratings')
        .select('*, kitchen:kitchen_id(name), user:user_id(name)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<KitchenModel>> getRecentKitchensForUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final response = await _client
        .from('orders')
        .select('kitchen_id, kitchens(*)')
        .eq('user_id', user.id)
        .or('status.eq.delivered,status.eq.Delivered') // 🔥 Fix: Handle both cases
        .order('created_at', ascending: false)
        .limit(20);

    final List<KitchenModel> uniqueKitchens = [];
    final Set<String> ids = {};

    for (var item in response) {
      final kData = item['kitchens'];
      if (kData != null) {
        final kitchen = KitchenModel.fromJson(kData);
        if (!ids.contains(kitchen.id)) {
          uniqueKitchens.add(kitchen);
          ids.add(kitchen.id);
        }
      }
    }
    return uniqueKitchens;
  }

  Future<int> countUnratedDeliveredOrders() async {
    final user = _client.auth.currentUser;
    if (user == null) return 0;

    // 🔥 V5 MASTER: Logic to find kitchens ordered but not yet rated
    final response = await _client.rpc('get_unrated_kitchen_count');
    if (response != null) return response as int;

    // Fallback if RPC not applied
    final orders = await _client
        .from('orders')
        .select('kitchen_id')
        .eq('user_id', user.id)
        .or('status.eq.delivered,status.eq.Delivered'); // 🔥 Fix: Handle both cases
    
    final ratedKitchens = await _client
        .from('ratings')
        .select('kitchen_id')
        .eq('user_id', user.id);

    final Set<String> ratedIds = (ratedKitchens as List).map((r) => r['kitchen_id'] as String).toSet();
    final Set<String> orderedIds = (orders as List).map((o) => o['kitchen_id'] as String).toSet();
    
    return orderedIds.difference(ratedIds).length;
  }

  // ORDERS
  Future<String> createOrder(OrderModel order) async {
    if (order.items.isEmpty) throw Exception('Order items cannot be empty');
    final kitchen = await getKitchenById(order.kitchenId);
    if (kitchen == null) throw Exception('Selected kitchen does not exist');

    // Force correct user_id (Caller must ensure order items/metadata are set correctly)
    orderData['user_id'] = order.userId;

    int attempts = 0;

    while (attempts < 3) {
      try {
        final response = await _client.from('orders').insert(orderData).select('id').single();
        final orderId = response['id'] as String;
        
        // Auto-assign delivery after a slight delay so User gets immediate confirmation
        Future.delayed(const Duration(seconds: 2), () => _autoAssignOrder(orderId));
        
        return orderId;
      } catch (e) {
        attempts++;
        if (attempts >= 3) {
          print('ERROR: Order creation failed after 3 attempts: $e');
          rethrow;
        }
        await Future.delayed(Duration(seconds: attempts)); // Exponential backoff
      }
    }
    throw Exception('Unknown error during order creation');
  }

  Future<void> _autoAssignOrder(String orderId) async {
    try {
      final response = await _client.from('users').select().eq('role', 'delivery');
      final deliveryBoys = (response as List).map((u) => UserModel.fromJson(u)).toList();
      if (deliveryBoys.isEmpty) return;

      // Simple round-robin or first available for Lite Mode
      final selectedBoy = deliveryBoys.first;
      await assignDelivery(orderId, selectedBoy.id);
    } catch (e) {
      print('ERROR: Auto-assignment failed for order $orderId: $e');
    }
  }


  Future<void> updateOrderStatus(String orderId, String status) async {
    await updateDeliveryStatus(orderId, status);
  }


  Future<void> updateAdminEta(String orderId, int eta) async {
    await _client.from('orders').update({'admin_eta': eta}).eq('id', orderId);
  }



  Future<List<OrderModel>> getUserOrders(String userId, {int limit = 10, int offset = 0}) async {
    final response = await _client
        .from('orders')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (response as List).map((data) => OrderModel.fromJson(data)).toList();
  }

  Future<List<OrderModel>> getAllOrdersAdmin({int limit = 50, int offset = 0}) async {
    final response = await _client
        .from('orders')
        .select()
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (response as List).map((data) => OrderModel.fromJson(data)).toList();
  }

  // DELIVERIES
  Future<void> assignDelivery(String orderId, String deliveryBoyId) async {
    print('LOG: SupabaseService: Assigning order $orderId to $deliveryBoyId');
    final riderProfile = await getUserProfile(deliveryBoyId);
    final updates = {
      'status': 'accepted',
      'delivery_boy_id': deliveryBoyId,
      'admin_eta': 30, // Default for Lite Mode
    };
    if (riderProfile != null) {
      updates['rider_name'] = riderProfile.name;
      updates['rider_phone'] = riderProfile.phone;
    }
    await _client.from('orders').update(updates).eq('id', orderId);
  }


  Future<void> acceptOrder(String orderId, String deliveryBoyId) async {
    await assignDelivery(orderId, deliveryBoyId);
  }

  Future<void> updateDeliveryStatus(String orderId, String status) async {
    print('LOG: SupabaseService: Updating order $orderId to $status');
    await _client.from('orders').update({'status': status}).eq('id', orderId);
  }


  Future<void> updatePaymentStatus(String orderId, String paymentStatus) async {
    await _client.from('orders').update({'payment_status': paymentStatus}).eq('id', orderId);
  }








  // STREAMS
  Stream<List<Map<String, dynamic>>> getAdminOrdersStream() {
    return _client.from('orders').stream(primaryKey: ['id']).order('created_at');
  }

  Stream<List<Map<String, dynamic>>> getPendingOrdersStream() {
    return _client.from('orders').stream(primaryKey: ['id']).eq('status', 'pending').order('created_at');
  }

  Stream<List<Map<String, dynamic>>> getUserOrdersStream(String userId) {
    return _client.from('orders').stream(primaryKey: ['id']).eq('user_id', userId).order('created_at');
  }

  Stream<List<Map<String, dynamic>>> getDeliveryBoyDeliveriesStream(String deliveryBoyId) {
    // This now watches ORDERS where delivery_boy_id matches
    return _client.from('orders').stream(primaryKey: ['id']).eq('delivery_boy_id', deliveryBoyId);
  }

  Stream<List<Map<String, dynamic>>> getLiveOrderStream(String orderId) {
    // 🔥 JOINING rider and customer profiles into the stream
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .map((list) => list.map((order) {
              // We'll need to fetch the extra data or use a simpler structure if stream joins are tricky in Supabase Flutter
              // Since Supabase .stream() doesn't officially support .select('*, profiles(*)') yet,
              // we will stick to fetching the data manually in the UI using FutureProviders for linked info,
              // but we will keep this stream for the core status & coordinates.
              return order;
            }).toList());
  }



}
