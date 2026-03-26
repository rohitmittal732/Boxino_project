import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boxino/core/theme/app_theme.dart';
import 'package:boxino/core/providers/app_providers.dart';
import 'package:boxino/domain/models/app_models.dart';

class DeliveryBoyScreen extends ConsumerStatefulWidget {
  const DeliveryBoyScreen({super.key});

  @override
  ConsumerState<DeliveryBoyScreen> createState() => _DeliveryBoyScreenState();
}

class _DeliveryBoyScreenState extends ConsumerState<DeliveryBoyScreen> {
  Timer? _locationTimer;

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  void _toggleOnline(bool val) {
    ref.read(isOnlineProvider.notifier).state = val;
    if (val) {
      _startLocationUpdates();
    } else {
      _locationTimer?.cancel();
    }
  }

  void _startLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      final deliveries = ref.read(deliveryOrdersProvider).value ?? [];
      final service = ref.read(supabaseServiceProvider);

      final activeDeliveries = deliveries.where((d) => d.status == 'on_the_way').toList();
      if (activeDeliveries.isEmpty) return;

      // Update in parallel to avoid blocking the loop
      await Future.wait(activeDeliveries.map((d) {
        final newLat = 26.9124 + (timer.tick * 0.0001);
        final newLng = 75.7873 + (timer.tick * 0.0001);
        return service.updateLiveLocation(d.id, newLat, newLng);
      }));
      
      print('DEBUG: DeliveryBoy: Updated location for ${activeDeliveries.length} orders');
    });
  }

  @override
  Widget build(BuildContext context) {
    final deliveriesAsync = ref.watch(deliveryOrdersProvider);
    final pendingAsync = ref.watch(pendingOrdersProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final userId = ref.watch(currentUserProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Delivery Dashboard'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          actions: [
            Row(
              children: [
                Text(isOnline ? 'ONLINE' : 'OFFLINE', 
                  style: TextStyle(color: isOnline ? Colors.green : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                Switch(
                  value: isOnline,
                  onChanged: _toggleOnline,
                  activeThumbColor: Colors.green,
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(supabaseServiceProvider).signOut(),
            ),
          ],
          bottom: const TabBar(
            labelColor: AppTheme.primaryOrange,
            indicatorColor: AppTheme.primaryOrange,
            tabs: [
              Tab(text: 'My Tasks', icon: Icon(Icons.delivery_dining)),
              Tab(text: 'New Orders', icon: Icon(Icons.new_releases)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: My Tasks
            deliveriesAsync.when(
              data: (deliveries) {
                if (deliveries.isEmpty) return const Center(child: Text('No active deliveries assigned.'));
                return ListView.builder(
                  itemCount: deliveries.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final delivery = deliveries[index];
                    return DeliveryCard(delivery: delivery);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
            
            // Tab 2: New Orders
            pendingAsync.when(
              data: (orders) {
                if (orders.isEmpty) return const Center(child: Text('No new orders available.'));
                return ListView.builder(
                  itemCount: orders.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        title: Text('Order #${order.id.substring(0, 8)}'),
                        subtitle: Text('Total: ₹${order.totalPrice}\nAddress: ${order.userAddress}'),
                        trailing: ElevatedButton(
                          onPressed: isOnline && userId != null 
                              ? () => ref.read(supabaseServiceProvider).acceptOrder(order.id, userId)
                              : null,
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                          child: const Text('Accept'),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ],
        ),
      ),
    );
  }
}

class DeliveryCard extends ConsumerWidget {
  final DeliveryModel delivery;
  const DeliveryCard({super.key, required this.delivery});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Order ID: ${delivery.orderId.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                _buildStatusBadge(delivery.status),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Current Location:'),
                Text(delivery.lat != null ? '${delivery.lat!.toStringAsFixed(4)}, ${delivery.lng!.toStringAsFixed(4)}' : 'Awaiting Link...',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showStatusDialog(context, ref, delivery),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Update Delivery Status'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusDialog(BuildContext context, WidgetRef ref, DeliveryModel delivery) {
    final statuses = ['accepted', 'picked_up', 'on_the_way', 'delivered'];
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: statuses.map((s) => ListTile(
          title: Text(s.replaceAll('_', ' ').toUpperCase()),
          onTap: () async {
            await ref.read(supabaseServiceProvider).updateDeliveryStatus(delivery.id, s);
            ref.invalidate(deliveryOrdersProvider);
            if (context.mounted) Navigator.pop(context);
          },
          trailing: delivery.status == s ? const Icon(Icons.check, color: AppTheme.primaryGreen) : null,
        )).toList(),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = AppTheme.primaryGreen;
    if (status == 'accepted') color = Colors.blue;
    if (status == 'picked_up') color = Colors.orange;
    if (status == 'on_the_way') color = Colors.purple;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
