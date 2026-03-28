import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boxino/core/theme/app_theme.dart';
import 'package:boxino/core/providers/app_providers.dart';
import 'package:boxino/domain/models/app_models.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

// Provider to fetch route points from OSRM
final routePointsProvider = FutureProvider.family<List<LatLng>, (LatLng, LatLng)>((ref, coords) async {
  final start = coords.$1;
  final end = coords.$2;
  
  final url = 'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';
  
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> coordinates = data['routes'][0]['geometry']['coordinates'];
      return coordinates.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
    }
  } catch (e) {
    print('Error fetching route: $e');
  }
  return [];
});

class OrderTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  final MapController _mapController = MapController();
  bool _hasFitBounds = false;

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderStream = ref.watch(liveOrderStreamProvider(widget.orderId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Track Order', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: orderStream.when(
        data: (orderData) {
          if (orderData.isEmpty) return const Center(child: Text('Order not found.'));
          
          final order = OrderModel.fromJson(orderData.first);
          
          // 1. Get Customer Info & Location
          final customerAsync = ref.watch(riderDetailsProvider(order.userId));
          
          // 2. Get Rider Location (Live)
          final riderLocAsync = order.deliveryBoyId != null 
              ? ref.watch(deliveryLocationStreamProvider(order.deliveryBoyId!))
              : const AsyncValue<List<Map<String, dynamic>>>.data([]);
          
          final riderData = riderLocAsync.valueOrNull?.firstOrNull;
          final riderLat = (riderData?['lat'] as num?)?.toDouble() ?? order.trackingLat;
          final riderLng = (riderData?['lng'] as num?)?.toDouble() ?? order.trackingLng;
          
          final riderPos = (riderLat != null && riderLat != 0) ? LatLng(riderLat, riderLng!) : null;
          
          // 3. Define Endpoints for Map
          final userPos = order.userLat != null 
              ? LatLng(order.userLat!, order.userLng!) 
              : (customerAsync.valueOrNull?.lat != null ? LatLng(customerAsync.valueOrNull!.lat!, customerAsync.valueOrNull!.lng!) : null);

          // 4. Fetch Route
          AsyncValue<List<LatLng>>? routeAsync;
          if (riderPos != null && userPos != null) {
            routeAsync = ref.watch(routePointsProvider((riderPos, userPos)));
            
            // Fit bounds once data is available
            if (!_hasFitBounds) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _mapController.fitCamera(CameraFit.bounds(
                  bounds: LatLngBounds(riderPos, userPos),
                  padding: const EdgeInsets.all(70),
                ));
                _hasFitBounds = true;
              });
            }
          }

          return Column(
            children: [
              // ORDER STATUS HEADER
              Container(
                padding: const EdgeInsets.all(20),
                color: Colors.white,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(order.status.replaceAll('_', ' ').toUpperCase(), 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryOrange)),
                            Text('Order #${order.id.substring(0, 8)}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                        if (order.status == 'delivered')
                          const Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 32)
                        else
                          const CircularProgressIndicator(strokeWidth: 3, color: AppTheme.primaryOrange),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _getStatusProgress(order.status),
                        backgroundColor: Colors.grey.shade200,
                        color: AppTheme.primaryGreen,
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),

              // MAP SECTION
              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: riderPos ?? userPos ?? const LatLng(26.9124, 75.7873),
                        initialZoom: 14.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.boxino.app',
                        ),
                        if (routeAsync != null)
                          routeAsync.when(
                            data: (points) => PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: points,
                                  color: Colors.blue.withOpacity(0.7),
                                  strokeWidth: 5,
                                ),
                              ],
                            ),
                            loading: () => const SizedBox(),
                            error: (e, s) => const SizedBox(),
                          ),
                        MarkerLayer(
                          markers: [
                            if (riderPos != null)
                              Marker(
                                point: riderPos,
                                width: 60,
                                height: 60,
                                child: _buildMapMarker(Icons.motorcycle, AppTheme.primaryOrange),
                              ),
                            if (userPos != null)
                              Marker(
                                point: userPos,
                                width: 60,
                                height: 60,
                                child: _buildMapMarker(Icons.person_pin_circle, AppTheme.primaryGreen),
                              ),
                          ],
                        ),
                      ],
                    ),
                    
                    // Floating Info Overlays
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (order.deliveryBoyId != null)
                              _buildProfileCard(
                                title: 'Delivery Partner',
                                name: order.riderName ?? 'Assigning...',
                                phone: order.riderPhone ?? '',
                                icon: Icons.delivery_dining,
                                color: AppTheme.primaryOrange,
                              ),
                            const SizedBox(height: 12),
                            _buildProfileCard(
                              title: 'Customer Details',
                              name: order.customerName ?? customerAsync.valueOrNull?.name ?? 'User',
                              phone: order.customerPhone ?? customerAsync.valueOrNull?.phone ?? '',
                              address: order.areaName ?? order.userAddress,
                              icon: Icons.home,
                              color: AppTheme.primaryGreen,
                              isCustomer: true,
                            ),
                            
                            // 🔥 RIDER SPECIFIC ACTIONS
                            if (ref.watch(userProfileProvider).valueOrNull?.role == 'delivery' && (order.status != 'delivered' || order.paymentStatus != 'paid'))
                              Padding(
                                padding: const EdgeInsets.only(top: 20),
                                child: _buildRiderActions(order, ref),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  double _getStatusProgress(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return 0.1;
      case 'accepted': return 0.3;
      case 'preparing': return 0.5;
      case 'picked_up': return 0.7;
      case 'on_the_way': return 0.85;
      case 'delivered': return 1.0;
      default: return 0.0;
    }
  }

  Widget _buildMapMarker(IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, spreadRadius: 2)],
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(icon, color: color, size: 30),
    );
  }

  Widget _buildProfileCard({
    required String title,
    required String name,
    required String phone,
    String? address,
    required IconData icon,
    required Color color,
    bool isCustomer = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (address != null)
                  Text(address, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (phone.isNotEmpty)
            IconButton.filled(
              onPressed: () => _makePhoneCall(phone),
              icon: const Icon(Icons.call, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.all(8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRiderActions(OrderModel order, WidgetRef ref) {
    String label = '';
    String nextStatus = '';
    Color color = AppTheme.primaryOrange;

    if (order.status == 'accepted' || order.status == 'preparing') {
      label = 'PICK UP ORDER';
      nextStatus = 'picked_up';
      color = Colors.blue;
    } else if (order.status == 'picked_up') {
      label = 'ON THE WAY';
      nextStatus = 'out_for_delivery';
      color = Colors.deepPurple;
    } else if (order.status == 'out_for_delivery') {
      label = 'MARK AS DELIVERED';
      nextStatus = 'delivered';
      color = AppTheme.primaryGreen;
    } else if (order.status == 'delivered' && order.paymentStatus != 'paid') {
      label = 'PAYMENT RECEIVED ✅';
      nextStatus = 'paid'; // We'll handle this specially in onPressed
      color = Colors.green;
    }

    if (label.isEmpty) return const SizedBox();

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          final service = ref.read(supabaseServiceProvider);
          if (nextStatus == 'paid') {
            await service.updatePaymentStatus(order.id, 'paid');
          } else {
            await service.updateDeliveryStatus(order.id, nextStatus);
          }
          
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(nextStatus == 'paid' ? 'Payment Confirmed!' : 'Status updated to ${nextStatus.replaceAll('_', ' ')}')),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 0,
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}
