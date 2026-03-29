import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/app_models.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';


class SupabaseService {
  SupabaseClient get _client => Supabase.instance.client;

  //////////////////
  /// AUTH Logic ///
  //////////////////

  Future<AuthResponse> signUpWithEmail(String email, String password, String name, String phone) async {
    return await _client.auth.signUp(
      email: email, 
      password: password,
      data: {
        'display_name': name,
        'phone': phone,
      },
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

  Future<void> updateUserProfile({
    required String userId,
    String? name,
    String? phone,
    String? address,
    String? areaName,
    double? lat,
    double? lng,
  }) async {
    final Map<String, dynamic> updates = {};
    if (name != null) updates['name'] = name;
    if (phone != null) updates['phone'] = phone;
    if (address != null) updates['user_address'] = address;
    if (areaName != null) updates['area_name'] = areaName;
    if (lat != null) updates['lat'] = lat;
    if (lng != null) updates['lng'] = lng;

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
    
    // Denormalize user metadata for UI performance
    final userProfile = await getUserProfile(currentUser.id);
    
    // 🔥 PRO FIX: Use current GPS if profile coords are missing
    double? finalLat = userProfile?.lat;
    double? finalLng = userProfile?.lng;
    
    if (finalLat == null) {
      try {
        final pos = await Geolocator.getCurrentPosition();
        finalLat = pos.latitude;
        finalLng = pos.longitude;
      } catch (e) {
        print('DEBUG: Location fetch failed during order: $e');
      }
    }

    if (userProfile != null) {
      orderData['customer_name'] = userProfile.name;
      orderData['customer_phone'] = userProfile.phone;
      orderData['user_lat'] = finalLat;
      orderData['user_lng'] = finalLng;
    }


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
    await updateDeliveryStatus(orderId, status);
  }


  Future<void> updateAdminEta(String orderId, int eta) async {
    await _client.from('orders').update({'admin_eta': eta}).eq('id', orderId);
  }

  Future<Map<String, dynamic>> getRouteInfo(LatLng start, LatLng end) async {
    final url = 'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final route = data['routes'][0];
        final List<dynamic> coordinates = route['geometry']['coordinates'];
        final duration = (route['duration'] as num).toDouble(); // Seconds
        final distance = (route['distance'] as num).toDouble(); // Meters
        final points = coordinates.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
        return {
          'points': points, 
          'duration': duration, 
          'distance': distance,
          'durationMinutes': (duration / 60).round(),
        };
      }
    } catch (e) {
      print('ERROR: SupabaseService: OSRM route error: $e');
    }
    return {'points': [], 'duration': 0, 'distance': 0, 'durationMinutes': 0};
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
    
    // 🔥 STEP 1: Update orders table
    // Denormalize rider metadata for UI performance
    final riderProfile = await getUserProfile(deliveryBoyId);
    final updates = {
      'status': 'accepted',
      'delivery_boy_id': deliveryBoyId,
    };
    if (riderProfile != null) {
      updates['rider_name'] = riderProfile.name;
      updates['rider_phone'] = riderProfile.phone;
    }

    await _client.from('orders').update(updates).eq('id', orderId);

    // 🔥 STEP 2: Upsert into deliveries table
    final existing = await _client.from('deliveries').select().eq('order_id', orderId).maybeSingle();
    
    if (existing == null) {
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
    
    // Keep tables in sync
    await Future.wait([
      _client.from('orders').update({'status': status}).eq('id', orderId),
      _client.from('deliveries').update({'status': status}).eq('order_id', orderId),
    ]);
  }

  Future<void> updatePaymentStatus(String orderId, String paymentStatus) async {
    await _client.from('orders').update({'payment_status': paymentStatus}).eq('id', orderId);
  }

  Future<void> updateLiveLocation(String orderId, double lat, double lng) async {
    // 🔥 PRO SCALABILITY: Sync to both tables using new explicit column names
    await Future.wait([
      _client.from('orders').update({
        'tracking_lat': lat, 
        'tracking_lng': lng,
        'delivery_lat': lat,
        'delivery_lng': lng,
      }).eq('id', orderId),
      _client.from('deliveries').update({'lat': lat, 'lng': lng}).eq('order_id', orderId),
    ]);
  }


  Future<void> updateUserLocation(String userId, double lat, double lng) async {
    await _client.from('users').update({'lat': lat, 'lng': lng}).eq('id', userId);
  }

  Future<String?> getAddressFromLatLng(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return "${place.name}, ${place.subLocality}, ${place.locality}";
      }
    } catch (e) {
      print('DEBUG: Geocoding error: $e');
    }
    return null;
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

  Stream<List<Map<String, dynamic>>> getDeliveryBoyLocationStream(String deliveryId) {
    return _client.from('users').stream(primaryKey: ['id']).eq('id', deliveryId);
  }
}
