import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/app_models.dart';

class SupabaseService {
  SupabaseClient get _client => Supabase.instance.client;

  //////////////////
  /// AUTH Logic ///
  //////////////////

  Future<AuthResponse> signUpWithEmail(String email, String password, String name) async {
    return await _client.auth.signUp(
      email: email, 
      password: password,
      data: {'display_name': name},
    );
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

    int attempts = 0;
    while (attempts < 3) {
      try {
        final response = await _client.from('orders').insert(order.toJson()).select('id').single();
        final orderId = response['id'] as String;
        
        // Auto-assign delivery after a slight delay so User gets immediate confirmation
        Future.delayed(const Duration(seconds: 2), () => _autoAssignOrder(orderId));
        
        return orderId;
      } catch (e) {
        attempts++;
        if (attempts >= 3) rethrow;
        await Future.delayed(Duration(seconds: attempts)); // Exponential backoff
      }
    }
    throw Exception('Unknown error during order creation');
  }

  Future<void> _autoAssignOrder(String orderId) async {
    try {
      // Fetch all delivery boys
      final response = await _client.from('users').select().eq('role', 'delivery');
      final deliveryBoys = (response as List).map((u) => UserModel.fromJson(u)).toList();
      if (deliveryBoys.isEmpty) return;

      // Calculate loads
      final activeDeliveries = await _client.from('deliveries').select('delivery_boy_id').neq('status', 'delivered');
      final Map<String, int> loadMap = { for (var d in deliveryBoys) d.id: 0 };
      for (var d in activeDeliveries as List) {
        final boyId = d['delivery_boy_id'] as String;
        if (loadMap.containsKey(boyId)) loadMap[boyId] = loadMap[boyId]! + 1;
      }

      // Find the least loaded delivery boy
      String? selectedBoyId;
      int minLoad = 999999;
      for (var boy in deliveryBoys) {
        if (loadMap[boy.id]! < minLoad) {
          minLoad = loadMap[boy.id]!;
          selectedBoyId = boy.id;
        }
      }

      if (selectedBoyId != null) {
        print('LOG: Auto-assigning order $orderId to delivery boy $selectedBoyId with load $minLoad');
        await assignDelivery(orderId, selectedBoyId);
      }
    } catch (e) {
      print('ERROR: Auto-assignment failed for order $orderId: $e');
    }
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    print('LOG: SupabaseService: Updating order status for $orderId to $status');
    await _client.from('orders').update({'status': status}).eq('id', orderId);
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
    
    // 🔥 STEP 1: Update orders table (main source of truth for realtime)
    await _client.from('orders').update({
      'status': 'accepted',
      'delivery_id': deliveryBoyId,
    }).eq('id', orderId);

    // 🔥 STEP 2: Upsert into deliveries table (assignment record)
    // We check for existing first to avoid Double Insert Bug as requested
    final existing = await _client.from('deliveries').select().eq('order_id', orderId);
    
    if ((existing as List).isEmpty) {
      await _client.from('deliveries').insert({
        'order_id': orderId,
        'delivery_boy_id': deliveryBoyId,
        'status': 'accepted',
      });
    } else {
      await _client.from('deliveries').update({
        'delivery_boy_id': deliveryBoyId,
        'status': 'accepted',
      }).eq('order_id', orderId);
    }
  }

  Future<void> acceptOrder(String orderId, String deliveryBoyId) async {
    await assignDelivery(orderId, deliveryBoyId);
  }

  Future<void> updateDeliveryStatus(String orderId, String status) async {
    print('LOG: SupabaseService: Updating order $orderId to $status');
    
    final Map<String, dynamic> updates = {'status': status};
    if (status == 'delivered') {
      updates['payment_status'] = 'paid';
    }

    // 🔥 SYNC: Update both tables
    await Future.wait([
      _client.from('orders').update(updates).eq('id', orderId),
      _client.from('deliveries').update({'status': status}).eq('order_id', orderId),
    ]);
  }

  Future<void> updateLiveLocation(String orderId, double lat, double lng) async {
    await _client.from('orders').update({'tracking_lat': lat, 'tracking_lng': lng}).eq('id', orderId);
  }

  Future<void> updateUserLocation(String userId, double lat, double lng) async {
    await _client.from('users').update({'lat': lat, 'lng': lng}).eq('id', userId);
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
    // This now watches ORDERS where delivery_id matches
    return _client.from('orders').stream(primaryKey: ['id']).eq('delivery_id', deliveryBoyId);
  }

  Stream<List<Map<String, dynamic>>> getLiveOrderStream(String orderId) {
    return _client.from('orders').stream(primaryKey: ['id']).eq('id', orderId);
  }

  Stream<List<Map<String, dynamic>>> getDeliveryBoyLocationStream(String deliveryId) {
    return _client.from('users').stream(primaryKey: ['id']).eq('id', deliveryId);
  }
}
