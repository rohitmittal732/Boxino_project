import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/app_models.dart';
import 'dart:async';
import 'dart:convert';


class SupabaseService {
  SupabaseClient get _client => Supabase.instance.client;

  //////////////////
  /// AUTH Logic ///
  //////////////////

  Future<AuthResponse> signUpWithEmail(String email, String password, String name, String phone) async {
    final response = await _client.auth.signUp(
      email: email, 
      password: password,
      data: {
        'name': name, // Standardized for V4 Trigger
        'phone': phone,
        'role': 'user',
      },
    );

    // 🔥 V4 MASTER FIX:
    // User is created in auth.users, and the V4 Database Trigger automatically
    // handles the sync to public.users with 'ON CONFLICT DO NOTHING'.
    // No more manual client-side inserts that cause duplicate key errors.

    return response;
  }


  /// Logs in the user.
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Sends a 6-digit OTP to the user's email.
  Future<void> sendEmailOtp(String email) async {
    await _client.auth.signInWithOtp(email: email);
  }

  /// Verifies the 6-digit OTP entered by the user.
  Future<AuthResponse> verifyEmailOtp(String email, String otp) async {
    return await _client.auth.verifyOTP(
      email: email,
      token: otp,
      type: OtpType.email,
    );
  }
  Future<bool> signInWithGoogle() async {
    return await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.boxino://login-callback',
    );
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
    );
  }

  User? get currentUser {
    try {
      return _client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  ////////////////////
  /// DB QUERIES /////
  ////////////////////

  // USERS
  Future<UserModel?> getUserProfile(String userId) async {
    try {
      final response = await _client.from('users').select().eq('id', userId).maybeSingle();
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
    if (address != null) updates['user_address'] = address;
    if (areaName != null) updates['area_name'] = areaName;


    if (updates.isEmpty) return;
    
    await _client.from('users').update(updates).eq('id', userId);
  }

  Future<void> updateUserRole(String userId, String role) async {
    try {
      await _client.from('users').update({'role': role}).eq('id', userId);
    } catch (e) {
      print('ERROR: SupabaseService: Error updating role: $e');
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

  // ORDERS
  Future<String> createOrder(OrderModel order) async {
    if (order.items.isEmpty) throw Exception('Order items cannot be empty');
    final kitchen = await getKitchenById(order.kitchenId);
    if (kitchen == null) throw Exception('Selected kitchen does not exist');

    // 🔥 FIX: Ensure we use the freshly fetched Auth ID
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    final orderData = order.toJson();
    orderData['user_id'] = currentUser.id; // 🔥 Force correct user_id
    
    // Assign customer info to the order record (denormalized for speed)
    orderData['customer_name'] = currentUser.userMetadata?['name'] ?? 'User';
    orderData['customer_phone'] = currentUser.userMetadata?['phone'] ?? '';

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
