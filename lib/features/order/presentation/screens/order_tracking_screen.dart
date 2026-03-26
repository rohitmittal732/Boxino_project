import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:boxino/core/theme/app_theme.dart';
import 'package:boxino/core/providers/app_providers.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class OrderTrackingScreen extends ConsumerWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to both order status and delivery updates
    final orderStream = ref.watch(liveOrderStreamProvider(orderId));
    final deliveryStream = ref.watch(liveDeliveryStreamProvider(orderId));

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
          final orderRaw = orderData.first;
          final orderStatus = orderRaw['status'] as String;
          final kitchenId = orderRaw['kitchen_id'] as String;
          final kitchenAsync = ref.watch(kitchenByIdProvider(kitchenId));

          return deliveryStream.when(
            data: (deliveries) {
              final delivery = deliveries.isNotEmpty ? deliveries.first : null;
              final currentStatus = delivery?.status ?? orderStatus;

              return SingleChildScrollView(
                child: Column(
                  children: [
                    // Live Map
                    SizedBox(
                      height: 300,
                      width: double.infinity,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: (delivery != null && delivery.lat != null && delivery.lat != 0)
                              ? LatLng(delivery.lat!, delivery.lng!)
                              : const LatLng(26.9124, 75.7873), // Default Jaipur
                          initialZoom: 14.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.boxino.app',
                          ),
                          MarkerLayer(
                            markers: [
                              // Delivery Boy Marker
                              if (delivery != null && delivery.lat != null && delivery.lat != 0)
                                Marker(
                                  point: LatLng(delivery.lat!, delivery.lng!),
                                  width: 50,
                                  height: 50,
                                  child: const Icon(Icons.delivery_dining, color: AppTheme.primaryOrange, size: 40),
                                ),
                              // Destination Marker (Kitchen)
                              if (kitchenAsync.hasValue && kitchenAsync.value != null)
                                Marker(
                                  point: LatLng(kitchenAsync.value!.lat, kitchenAsync.value!.long),
                                  width: 50,
                                  height: 50,
                                  child: const Icon(Icons.location_on, color: AppTheme.primaryGreen, size: 40),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Order Status', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              Text('#${orderId.substring(0, 8)}', style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildTimeline(currentStatus),
                          const SizedBox(height: 40),
                          if (delivery != null) ...[
                            const Text('Delivery Partner Info', style: TextStyle(fontWeight: FontWeight.bold)),
                            const ListTile(
                              leading: CircleAvatar(child: Icon(Icons.person)),
                              title: Text('Sanjeev (Delivery Partner)'),
                              subtitle: Text('Contact: +91 98765 43210'),
                            ),
                          ],
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => context.go('/home'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryOrange,
                                side: const BorderSide(color: AppTheme.primaryOrange),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text('Back to Home', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
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
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildTimeline(String currentStatus) {
    final statuses = ['pending', 'accepted', 'preparing', 'out_for_delivery', 'delivered'];
    
    // Normalize status names between tables
    String normalized = currentStatus.toLowerCase();
    if (normalized == 'picked_up') normalized = 'preparing';
    if (normalized == 'on_the_way') normalized = 'out_for_delivery';

    final currentIndex = statuses.indexOf(normalized);

    return Column(
      children: statuses.asMap().entries.map((entry) {
        final index = entry.key;
        final status = entry.value;
        final isCompleted = index <= currentIndex;
        final isLast = index == statuses.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isCompleted ? AppTheme.primaryGreen : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                  child: isCompleted ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 40,
                    color: isCompleted ? AppTheme.primaryGreen : Colors.grey.shade300,
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  status.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                    color: isCompleted ? Colors.black : Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
