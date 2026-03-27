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
    await updateOrderStatus(orderId, 'accepted');
    await _client.from('deliveries').insert({
      'order_id': orderId,
      'delivery_boy_id': deliveryBoyId,
      'status': 'accepted',
    });
  }

  Future<void> acceptOrder(String orderId, String deliveryBoyId) async {
    // Same logic as assign, but initiated by the delivery boy
    await assignDelivery(orderId, deliveryBoyId);
  }

  Future<List<DeliveryModel>> getDeliveryBoyOrders(String deliveryBoyId) async {
    final response = await _client.from('deliveries').select().eq('delivery_boy_id', deliveryBoyId).neq('status', 'delivered');
    return (response as List).map((d) => DeliveryModel.fromJson(d)).toList();
  }

  Future<void> updateDeliveryStatus(String deliveryId, String status) async {
    print('LOG: SupabaseService: Updating delivery status for $deliveryId to $status');
    await _client.from('deliveries').update({
      'status': status, 
      'updated_at': DateTime.now().toIso8601String()
    }).eq('id', deliveryId);
    
    final res = await _client.from('deliveries').select('order_id').eq('id', deliveryId).single();
    final orderId = res['order_id'];

    if (status == 'delivered') {
      // Mark order as delivered AND if cash payment, mark as paid
      await _client.from('orders').update({
        'status': 'delivered',
        'payment_status': 'paid'
      }).eq('id', orderId);
    } else if (status == 'on_the_way') {
      await updateOrderStatus(orderId, 'out_for_delivery');
    } else if (status == 'picked_up') {
      await updateOrderStatus(orderId, 'preparing');
    }
  }

  Future<void> updateLiveLocation(String deliveryId, double lat, double lng) async {
    await _client.from('deliveries').update({'lat': lat, 'lng': lng, 'updated_at': DateTime.now().toIso8601String()}).eq('id', deliveryId);
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
    return _client.from('deliveries').stream(primaryKey: ['id']).eq('delivery_boy_id', deliveryBoyId).order('updated_at');
  }

  Stream<List<Map<String, dynamic>>> getLiveOrderStream(String orderId) {
    return _client.from('orders').stream(primaryKey: ['id']).eq('id', orderId);
  }

  Stream<List<Map<String, dynamic>>> getLiveDeliveryStream(String orderId) {
    return _client.from('deliveries').stream(primaryKey: ['id']).eq('order_id', orderId);
  }

  Stream<List<Map<String, dynamic>>> getDeliveryLocationStream(String deliveryBoyId) {
    return _client.from('deliveries').stream(primaryKey: ['id']).eq('delivery_boy_id', deliveryBoyId);
  }
}

