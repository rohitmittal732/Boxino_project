class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role; // 'user', 'delivery', 'admin'
  final double? lat;
  final double? long;
  final String? preference; 
  final String? locationName;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.lat,
    this.long,
    this.preference,
    this.locationName,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      lat: (json['lat'] as num?)?.toDouble(),
      long: (json['long'] as num?)?.toDouble(),
      preference: json['preference'] as String?,
      locationName: json['location_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'lat': lat,
        'long': long,
        'preference': preference,
        'location_name': locationName,
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
  final double long;
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
    required this.long,
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
      long: (json['long'] as num?)?.toDouble() ?? 0.0,
      address: json['address'] as String? ?? '',
      pricePerMeal: (json['price_per_meal'] as num?)?.toDouble() ?? 0.0,
      isApproved: json['is_approved'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    final map = {
      'name': name,
      'image_url': imageUrl,
      'rating': rating,
      'description': description,
      'is_veg': isVeg,
      'is_non_veg': isNonVeg,
      'lat': lat,
      'long': long,
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
    final map = {
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
<<<<<<< HEAD
  final String items; // JSON encoded string or text
  final String customization;
  final String planType; // 'Daily', 'Weekly', 'Monthly'
  final String mealType; // 'Lunch', 'Dinner'
  final double price;
  final String status; // 'pending', 'preparing', 'on_the_way', 'delivered'
  final String deliveryTime;
  final String? userAddress;
=======
  final List<dynamic> items; 
  final double totalPrice;
  final String status; // 'pending', 'accepted', 'preparing', 'out_for_delivery', 'delivered'
  final DateTime createdAt;
  final String userAddress;
  final String paymentMethod; // 'cash', 'online'
  final String paymentStatus; // 'pending', 'paid'
>>>>>>> a59414e02a835213c0343f758d0b64ec2ddfa6e2

  OrderModel({
    required this.id,
    required this.userId,
    required this.kitchenId,
    required this.items,
    required this.totalPrice,
    required this.status,
<<<<<<< HEAD
    required this.deliveryTime,
    this.userAddress,
=======
    required this.createdAt,
    required this.userAddress,
    this.paymentMethod = 'cash',
    this.paymentStatus = 'pending',
>>>>>>> a59414e02a835213c0343f758d0b64ec2ddfa6e2
  });

  /// Alias so delivery screen can use [totalPrice] interchangeably with [price].
  double get totalPrice => price;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      kitchenId: json['kitchen_id'] as String,
<<<<<<< HEAD
      items: json['items'] as String,
      customization: json['customization'] as String? ?? '',
      planType: json['plan_type'] as String,
      mealType: json['meal_type'] as String,
      price: (json['price'] as num).toDouble(),
      status: json['status'] as String,
      deliveryTime: json['delivery_time'] as String? ?? '',
      userAddress: json['user_address'] as String?,
=======
      items: json['items'] as List? ?? [],
      totalPrice: (json['total_price'] as num).toDouble(),
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
      userAddress: json['user_address'] as String? ?? '',
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      paymentStatus: json['payment_status'] as String? ?? 'pending',
>>>>>>> a59414e02a835213c0343f758d0b64ec2ddfa6e2
    );
  }

  Map<String, dynamic> toJson() {
    final map = {
      'user_id': userId,
      'kitchen_id': kitchenId,
      'items': items,
      'total_price': totalPrice.toInt(),
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'user_address': userAddress,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
    };
    if (id.isNotEmpty) map['id'] = id;
    return map;
  }
}

<<<<<<< HEAD
/// Represents a delivery record assigned to a delivery boy.
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
      status: json['status'] as String,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_id': orderId,
        'delivery_boy_id': deliveryBoyId,
        'status': status,
        'lat': lat,
        'lng': lng,
      };
}

class SubscriptionModel {
=======
class DeliveryModel {
>>>>>>> a59414e02a835213c0343f758d0b64ec2ddfa6e2
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
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = {
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
