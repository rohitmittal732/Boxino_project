class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role; // 'user', 'delivery', 'admin'
  final double? lat;
  final double? lng;
  final String? preference;
  final String? locationName;
  final String? userAddress;
  final String? areaName;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.lat,
    this.lng,
    this.preference,
    this.locationName,
    this.userAddress,
    this.areaName,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble() ?? (json['long'] as num?)?.toDouble(),
      preference: json['preference'] as String?,
      locationName: json['location_name'] as String?,
      userAddress: json['user_address'] as String?,
      areaName: json['area_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'lat': lat,
        'lng': lng,
        'preference': preference,
        'location_name': locationName,
        'user_address': userAddress,
        'area_name': areaName,
      };
}

class KitchenModel {
  final String id;
  final String name;
  final String imageUrl;
  final double rating;
  final String description;
  final bool isVeg;
  final bool isNonVeg;
  final double lat;
  final double lng;
  final String address;
  final double pricePerMeal;
  final bool isApproved;

  KitchenModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.rating,
    required this.description,
    required this.isVeg,
    required this.isNonVeg,
    required this.lat,
    required this.lng,
    required this.address,
    required this.pricePerMeal,
    this.isApproved = true,
  });

  factory KitchenModel.fromJson(Map<String, dynamic> json) {
    return KitchenModel(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['image_url'] as String? ?? json['image'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String? ?? '',
      isVeg: json['is_veg'] as bool? ?? true,
      isNonVeg: json['is_non_veg'] as bool? ?? false,
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? (json['long'] as num?)?.toDouble() ?? 0.0,
      address: json['address'] as String? ?? '',
      pricePerMeal: (json['price_per_meal'] as num?)?.toDouble() ?? 0.0,
      isApproved: json['is_approved'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> map = {
      'name': name,
      'image_url': imageUrl,
      'rating': rating,
      'description': description,
      'is_veg': isVeg,
      'is_non_veg': isNonVeg,
      'lat': lat,
      'lng': lng,
      'address': address,
      'price_per_meal': pricePerMeal,
      'is_approved': isApproved,
    };
    if (id.isNotEmpty) map['id'] = id;
    return map;
  }
}

class MenuModel {
  final String id;
  final String kitchenId;
  final String name;
  final String description;
  final double price;
  final String category; // 'Veg', 'Non-Veg', 'Combo'
  final String imageUrl;

  MenuModel({
    required this.id,
    required this.kitchenId,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.imageUrl,
  });

  factory MenuModel.fromJson(Map<String, dynamic> json) {
    return MenuModel(
      id: json['id'] as String,
      kitchenId: json['kitchen_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      price: (json['price'] as num).toDouble(),
      category: json['category'] as String? ?? 'Veg',
      imageUrl: json['image_url'] as String? ?? json['image'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> map = {
      'kitchen_id': kitchenId,
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'image_url': imageUrl,
    };
    if (id.isNotEmpty) map['id'] = id;
    return map;
  }
}

class OrderModel {
  final String id;
  final String userId;
  final String kitchenId;
  final List<dynamic> items; 
  final double totalPrice;
  final String status; // 'pending', 'accepted', 'preparing', 'out_for_delivery', 'delivered'
  final String? deliveryBoyId;
  final DateTime createdAt;
  final String userAddress;
  final String paymentMethod; // 'cash', 'online'
  final String paymentStatus; // 'pending', 'paid'
  final double? trackingLat;
  final double? trackingLng;
  final double? userLat;
  final double? userLng;
  final String? areaName;

  // Metadata from joins (optional)
  final String? riderName;
  final String? riderPhone;
  final String? customerName;
  final String? customerPhone;
  
  // Legacy fields for UI compatibility
  final String? customization;
  final String? planType;
  final String? mealType;
  final String? deliveryTime;

  OrderModel({
    required this.id,
    required this.userId,
    required this.kitchenId,
    required this.items,
    required this.totalPrice,
    required this.status,
    this.deliveryBoyId,
    required this.createdAt,
    required this.userAddress,
    this.paymentMethod = 'cash',
    this.paymentStatus = 'pending',
    this.trackingLat,
    this.trackingLng,
    this.userLat,
    this.userLng,
    this.areaName,
    this.riderName,
    this.riderPhone,
    this.customerName,
    this.customerPhone,
    this.customization,
    this.planType,
    this.mealType,
    this.deliveryTime,
  });

  /// Alias so delivery screen can use [totalPrice] interchangeably with [price]
  double get price => totalPrice;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      kitchenId: json['kitchen_id'] as String? ?? '',
      items: json['items'] is List ? json['items'] as List : (json['items'] is String ? [json['items']] : []),
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? (json['price'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
      deliveryBoyId: json['delivery_boy_id'] as String? ?? json['delivery_id'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      userAddress: json['user_address'] as String? ?? '',
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      trackingLat: (json['tracking_lat'] as num?)?.toDouble() ?? (json['lat'] as num?)?.toDouble(),
      trackingLng: (json['tracking_lng'] as num?)?.toDouble() ?? (json['lng'] as num?)?.toDouble() ?? (json['long'] as num?)?.toDouble(),
      userLat: (json['user_lat'] as num?)?.toDouble(),
      userLng: (json['user_lng'] as num?)?.toDouble(),
      areaName: json['area_name'] as String?,
      riderName: json['rider_profiles'] != null ? json['rider_profiles']['name'] : null,
      riderPhone: json['rider_profiles'] != null ? json['rider_profiles']['phone'] : null,
      customerName: json['customer_profiles'] != null ? json['customer_profiles']['name'] : null,
      customerPhone: json['customer_profiles'] != null ? json['customer_profiles']['phone'] : null,
      customization: json['customization'] as String?,
      planType: json['plan_type'] as String?,
      mealType: json['meal_type'] as String?,
      deliveryTime: json['delivery_time'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> map = {
      'user_id': userId,
      'kitchen_id': kitchenId,
      'items': items,
      'total_price': totalPrice,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'user_address': userAddress,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
    };
    if (deliveryBoyId != null) map['delivery_boy_id'] = deliveryBoyId;
    if (trackingLat != null) map['tracking_lat'] = trackingLat;
    if (trackingLng != null) map['tracking_lng'] = trackingLng;
    if (userLat != null) map['user_lat'] = userLat;
    if (userLng != null) map['user_lng'] = userLng;
    if (areaName != null) map['area_name'] = areaName;
    if (id.isNotEmpty) map['id'] = id;
    if (customization != null) map['customization'] = customization;
    if (planType != null) map['plan_type'] = planType;
    if (mealType != null) map['meal_type'] = mealType;
    if (deliveryTime != null) map['delivery_time'] = deliveryTime;
    return map;
  }
}

class DeliveryModel {
  final String id;
  final String orderId;
  final String deliveryBoyId;
  final String status; // 'accepted', 'picked_up', 'on_the_way', 'delivered'
  final double? lat;
  final double? lng;

  DeliveryModel({
    required this.id,
    required this.orderId,
    required this.deliveryBoyId,
    required this.status,
    this.lat,
    this.lng,
  });

  factory DeliveryModel.fromJson(Map<String, dynamic> json) {
    return DeliveryModel(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      deliveryBoyId: json['delivery_boy_id'] as String,
      status: json['status'] as String? ?? 'accepted',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble() ?? (json['long'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> map = {
      'order_id': orderId,
      'delivery_boy_id': deliveryBoyId,
      'status': status,
      'lat': lat,
      'lng': lng,
    };
    if (id.isNotEmpty) map['id'] = id;
    return map;
  }
}
