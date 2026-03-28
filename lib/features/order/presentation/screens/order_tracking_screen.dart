import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:boxino/core/theme/app_theme.dart';
import 'package:boxino/core/providers/app_providers.dart';
import 'package:boxino/domain/models/app_models.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderTrackingScreen extends ConsumerWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

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
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(liveOrderStreamProvider(orderId), (previous, next) {
      if (next is AsyncData) {
        final nextVal = next.valueOrNull;
        final prevVal = previous?.valueOrNull;
        if (nextVal != null && nextVal.isNotEmpty && prevVal != null && prevVal.isNotEmpty) {
          final newStatus = nextVal.first['status'];
          final oldStatus = prevVal.first['status'];
          if (newStatus != oldStatus) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📦 Order Status: ${newStatus.toString().toUpperCase()}'),
                backgroundColor: AppTheme.primaryOrange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    });

    final orderStream = ref.watch(liveOrderStreamProvider(orderId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Track Order'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: orderStream.when(
        data: (orderData) {
          if (orderData.isEmpty) return const Center(child: Text('Order not found.'));
          
          final order = OrderModel.fromJson(orderData.first);
          final kitchenAsync = ref.watch(kitchenByIdProvider(order.kitchenId));
          
          // Watch rider location
          double? liveLat = order.trackingLat;
          double? liveLng = order.trackingLng;
          
          if (order.deliveryBoyId != null) {
            final riderLocAsync = ref.watch(deliveryLocationStreamProvider(order.deliveryBoyId!));
            riderLocAsync.whenData((data) {
              if (data.isNotEmpty) {
                liveLat = (data.first['lat'] as num?)?.toDouble();
                liveLng = (data.first['lng'] as num?)?.toDouble();
              }
            });
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // 1. Kitchen Header
                kitchenAsync.when(
                  data: (kitchen) => Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Row(
                      children: [
                        const Icon(Icons.restaurant, color: AppTheme.primaryOrange),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(kitchen?.name ?? 'Kitchen', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              Text('Order #${order.id.substring(0, 8)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: order.paymentStatus == 'paid' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            order.paymentStatus == 'paid' ? 'PAID' : 'PAY ON DELIVERY',
                            style: TextStyle(
                              color: order.paymentStatus == 'paid' ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, s) => const SizedBox(),
                ),

                // 2. Map
                SizedBox(
                  height: 300,
                  width: double.infinity,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: (liveLat != null && liveLat != 0)
                          ? LatLng(liveLat!, liveLng!)
                          : const LatLng(26.9124, 75.7873),
                      initialZoom: 15.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.boxino.app',
                      ),
                      MarkerLayer(
                        markers: [
                          if (liveLat != null && liveLat != 0)
                            Marker(
                              point: LatLng(liveLat!, liveLng!),
                              width: 60,
                              height: 60,
                              child: const Icon(Icons.delivery_dining, color: AppTheme.primaryOrange, size: 45),
                            ),
                          if (kitchenAsync.valueOrNull != null)
                            Marker(
                              point: LatLng(kitchenAsync.valueOrNull!.lat, kitchenAsync.valueOrNull!.lng),
                              width: 50,
                              height: 50,
                              child: const Icon(Icons.location_on, color: AppTheme.primaryGreen, size: 40),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 3. Rider Info Card
                if (order.deliveryBoyId != null)
                  ref.watch(riderDetailsProvider(order.deliveryBoyId!)).when(
                    data: (rider) => Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 25,
                            backgroundColor: AppTheme.primaryOrange,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(rider?.name ?? 'Delivery Partner', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const Text('On his way to you', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                          IconButton.filled(
                            onPressed: () => _makePhoneCall(rider?.phone ?? ''),
                            icon: const Icon(Icons.call),
                            backgroundColor: AppTheme.primaryGreen,
                          ),
                        ],
                      ),
                    ),
                    loading: () => const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
                    error: (e, s) => const SizedBox(),
                  ),

                // 4. Status Timeline
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Track Order Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      _buildTimeline(order.status),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, color: Colors.grey, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            order.status == 'delivered' ? 'Order Delivered' : 'Estimated Delivery: 20 mins',
                            style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildTimeline(String currentStatus) {
    final statusFlow = ['pending', 'accepted', 'picked_up', 'on_the_way', 'delivered'];
    final currentIndex = statusFlow.indexOf(currentStatus.toLowerCase());

    return Column(
      children: statusFlow.asMap().entries.map((entry) {
        final index = entry.key;
        final status = entry.value;
        final isCompleted = index <= currentIndex;
        final isLast = index == statusFlow.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: isCompleted ? AppTheme.primaryGreen : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                  child: isCompleted ? const Icon(Icons.check, size: 10, color: Colors.white) : null,
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 35,
                    color: isCompleted ? AppTheme.primaryGreen : Colors.grey.shade300,
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                status.replaceAll('_', ' ').toUpperCase(),
                style: TextStyle(
                  fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                  color: isCompleted ? Colors.black : Colors.grey,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
