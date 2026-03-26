import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/app_models.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  //////////////////
  /// AUTH Logic ///
  //////////////////

  /// Sign up with Email + Password (stores name in metadata if provided)
  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
    );
  }

  /// Sign up with Email + Password + Name (stores name in user metadata)
  /// This allows us to save the user's display name right at registration.
  Future<AuthResponse> signUpWithEmailAndName(
    String email,
    String password,
    String name,
  ) async {
    try {
      print('DEBUG: Attempting signup for $email with name $name');
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': name}, // Stored in auth.users.raw_user_meta_data
      );
      print('DEBUG: Signup successful for ${response.user?.email}');
      return response;
    } catch (e) {
      print('DEBUG: Signup ERROR - $e');
      rethrow;
    }
  }

  /// Sign in with Email + Password
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    try {
      print('DEBUG: Attempting login for $email');
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      print('DEBUG: Login successful for ${response.user?.email}');
      return response;
    } catch (e) {
      print('DEBUG: Login ERROR - $e');
      rethrow;
    }
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

  /// Sign in with Google (via Supabase OAuth)
  Future<bool> signInWithGoogle() async {
    return await _client.auth.signInWithOAuth(
      OAuthProvider.google,
    );
  }

  /// Reset Password
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;

  ////////////////////
  /// DB QUERIES /////
  ////////////////////

  // USER
  Future<UserModel?> getUserProfile(String userId) async {
    final response = await _client.from('Users').select().eq('id', userId).maybeSingle();
    if (response != null) {
      return UserModel.fromJson(response);
    }
    return null;
  }

  Future<void> createUserProfile(UserModel user) async {
    await _client.from('Users').upsert(user.toJson());
  }

  // KITCHENS
  Future<List<KitchenModel>> getApprovedKitchens() async {
    final response = await _client.from('Kitchens').select().eq('is_approved', true);
    return (response as List).map((data) => KitchenModel.fromJson(data)).toList();
  }

  Future<List<KitchenModel>> getAllKitchensAdmin() async {
    final response = await _client.from('Kitchens').select();
    return (response as List).map((data) => KitchenModel.fromJson(data)).toList();
  }

  Future<void> approveKitchen(String kitchenId, bool isApproved) async {
    await _client.from('Kitchens').update({'is_approved': isApproved}).eq('id', kitchenId);
  }

  // ORDERS
  Future<void> createOrder(OrderModel order) async {
    await _client.from('Orders').insert({
      'user_id': order.userId,
      'kitchen_id': order.kitchenId,
      'items': order.items,
      'customization': order.customization,
      'plan_type': order.planType,
      'meal_type': order.mealType,
      'price': order.price,
      'payment_method': 'COD',
      'status': order.status,
      'delivery_time': order.deliveryTime,
    });
  }

  Future<List<OrderModel>> getUserOrders(String userId) async {
    final response = await _client.from('Orders').select().eq('user_id', userId).order('created_at', ascending: false);
    return (response as List).map((data) => OrderModel.fromJson(data)).toList();
  }

  // REALTIME STREAM FOR ORDERS
  Stream<List<Map<String, dynamic>>> getLiveOrderStream(String orderId) {
    return _client
        .from('Orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId);
  }

  // SUBSCRIPTIONS
  Future<void> createSubscription(SubscriptionModel sub) async {
    await _client.from('Subscriptions').insert({
      'user_id': sub.userId,
      'kitchen_id': sub.kitchenId,
      'plan_type': sub.planType,
      'start_date': sub.startDate.toIso8601String(),
      'end_date': sub.endDate.toIso8601String(),
    });
  }

  // ─── DELIVERY BOY METHODS ───────────────────────────────────

  /// Returns active (non-delivered) deliveries assigned to [deliveryBoyId].
  Future<List<DeliveryModel>> getActiveDeliveries(String deliveryBoyId) async {
    final response = await _client
        .from('deliveries')
        .select()
        .eq('delivery_boy_id', deliveryBoyId)
        .neq('status', 'delivered')
        .order('created_at', ascending: false);
    return (response as List).map((d) => DeliveryModel.fromJson(d)).toList();
  }

  /// Returns orders in 'pending' status with no delivery boy assigned.
  Future<List<OrderModel>> getPendingOrders() async {
    final response = await _client
        .from('Orders')
        .select()
        .eq('status', 'pending')
        .isFilter('delivery_boy_id', null)
        .order('created_at', ascending: false);
    return (response as List).map((d) => OrderModel.fromJson(d)).toList();
  }

  /// Assigns [deliveryBoyId] to an order and creates a delivery record.
  Future<void> acceptOrder(String orderId, String deliveryBoyId) async {
    // Update the order status and assign the delivery boy
    await _client
        .from('Orders')
        .update({'status': 'accepted', 'delivery_boy_id': deliveryBoyId})
        .eq('id', orderId);
    // Insert a delivery tracking row
    await _client.from('deliveries').upsert({
      'order_id': orderId,
      'delivery_boy_id': deliveryBoyId,
      'status': 'accepted',
    });
  }

  /// Updates the [status] of a delivery record by [deliveryId].
  Future<void> updateDeliveryStatus(String deliveryId, String status) async {
    await _client
        .from('deliveries')
        .update({'status': status})
        .eq('id', deliveryId);
  }

  /// Pushes the current GPS coordinates for a delivery record.
  Future<void> updateLiveLocation(
      String deliveryId, double lat, double lng) async {
    await _client
        .from('deliveries')
        .update({'lat': lat, 'lng': lng})
        .eq('id', deliveryId);
  }
}

