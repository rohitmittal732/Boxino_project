class UserModel {
  final String id;
  final String name;
  final String phone;
  final String role; // 'user', 'cook', 'admin'
  final double lat;
  final double long;
  final String preference; // 'Veg', 'Non-veg'
  final String goal; // 'Weight loss', 'Normal', 'Gym'

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.lat,
    required this.long,
    required this.preference,
    required this.goal,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      role: json['role'] as String,
      lat: (json['lat'] as num).toDouble(),
      long: (json['long'] as num).toDouble(),
      preference: json['preference'] as String,
      goal: json['goal'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'role': role,
        'lat': lat,
        'long': long,
        'preference': preference,
        'goal': goal,
      };
}

class KitchenModel {
  final String id;
  final String name;
  final String image;
  final double lat;
  final double long;
  final double rating;
  final double pricePerMeal;
  final String description;
  final bool isApproved;
  final String createdBy;

  KitchenModel({
    required this.id,
    required this.name,
    required this.image,
    required this.lat,
    required this.long,
    required this.rating,
    required this.pricePerMeal,
    required this.description,
    required this.isApproved,
    required this.createdBy,
  });

  factory KitchenModel.fromJson(Map<String, dynamic> json) {
    return KitchenModel(
      id: json['id'] as String,
      name: json['name'] as String,
      image: json['image'] as String? ?? '',
      lat: (json['lat'] as num).toDouble(),
      long: (json['long'] as num).toDouble(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      pricePerMeal: (json['price_per_meal'] as num).toDouble(),
      description: json['description'] as String,
      isApproved: json['is_approved'] as bool? ?? false,
      createdBy: json['created_by'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'image': image,
        'lat': lat,
        'long': long,
        'rating': rating,
        'price_per_meal': pricePerMeal,
        'description': description,
        'is_approved': isApproved,
        'created_by': createdBy,
      };
}

class OrderModel {
  final String id;
  final String userId;
  final String kitchenId;
  final String items; // JSON encoded string or text
  final String customization;
  final String planType; // 'Daily', 'Weekly', 'Monthly'
  final String mealType; // 'Lunch', 'Dinner'
  final double price;
  final String status; // 'pending', 'preparing', 'on_the_way', 'delivered'
  final String deliveryTime;
  final String? userAddress;

  OrderModel({
    required this.id,
    required this.userId,
    required this.kitchenId,
    required this.items,
    required this.customization,
    required this.planType,
    required this.mealType,
    required this.price,
    required this.status,
    required this.deliveryTime,
    this.userAddress,
  });

  /// Alias so delivery screen can use [totalPrice] interchangeably with [price].
  double get totalPrice => price;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      kitchenId: json['kitchen_id'] as String,
      items: json['items'] as String,
      customization: json['customization'] as String? ?? '',
      planType: json['plan_type'] as String,
      mealType: json['meal_type'] as String,
      price: (json['price'] as num).toDouble(),
      status: json['status'] as String,
      deliveryTime: json['delivery_time'] as String? ?? '',
      userAddress: json['user_address'] as String?,
    );
  }
}

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
  final String id;
  final String userId;
  final String kitchenId;
  final String planType;
  final DateTime startDate;
  final DateTime endDate;

  SubscriptionModel({
    required this.id,
    required this.userId,
    required this.kitchenId,
    required this.planType,
    required this.startDate,
    required this.endDate,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      kitchenId: json['kitchen_id'] as String,
      planType: json['plan_type'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
    );
  }
}
