import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
<<<<<<< HEAD
import 'package:supabase_flutter/supabase_flutter.dart';
=======
>>>>>>> a59414e02a835213c0343f758d0b64ec2ddfa6e2
import 'package:boxino/core/theme/app_theme.dart';
import 'package:boxino/core/providers/app_providers.dart';
import 'package:boxino/domain/models/app_models.dart';

import 'package:geolocator/geolocator.dart';

<<<<<<< HEAD

=======
>>>>>>> a59414e02a835213c0343f758d0b64ec2ddfa6e2
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

  void _startLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enable location services')));
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    _locationTimer?.cancel();
    // Throttle updates to 10 seconds to save battery and reduce DB writes
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      final deliveries = ref.read(deliveryOrdersProvider).value ?? [];
      final service = ref.read(supabaseServiceProvider);

      final activeDeliveries = deliveries.where((d) => d.status == 'on_the_way').toList();
      if (activeDeliveries.isEmpty) return;

      try {
        final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        
        await Future.wait(activeDeliveries.map((d) {
          return service.updateLiveLocation(d.id, position.latitude, position.longitude);
        }));
        
        print('DEBUG: Updated real GPS location for ${activeDeliveries.length} orders');
      } catch (e) {
        print('DEBUG: Location error: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final deliveriesAsync = ref.watch(deliveryOrdersProvider);
    final pendingAsync = ref.watch(pendingOrdersProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final userId = ref.watch(currentUserProvider);

    return DefaultTabController(
      length: 3,
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
              Tab(text: 'Earnings', icon: Icon(Icons.account_balance_wallet)),
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
            
            // Tab 3: Earnings
            deliveriesAsync.when(
              data: (deliveries) {
                // Here we cheat a bit since the initial provider filters out 'delivered'. 
                // We'd ideally need a new provider for history, but assuming we fetch all deliveries or the backend provides a summary stream. 
                // For MVP UI, we'll just show a placeholder static view since a dedicated fetch for delivered is needed.
                return const DeliveryEarningsTab();
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

class DeliveryEarningsTab extends ConsumerWidget {
  const DeliveryEarningsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserProvider);
    if (userId == null) return const SizedBox();

    // Use a Future for fetching true history directly from Supabase
    return FutureBuilder<List<dynamic>>(
      future: Supabase.instance.client.from('deliveries').select().eq('delivery_boy_id', userId).eq('status', 'delivered'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        final completed = snapshot.data ?? [];
        final totalCount = completed.length;
        final estEarnings = totalCount * 30; // ₹30 per delivery flat rate

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.primaryOrange, AppTheme.deepOrange]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  const Text('Total Estimated Earnings', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('₹$estEarnings', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: const Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 32),
                title: const Text('Total Deliveries Completed', style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: Text('$totalCount', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
              ),
            ),
          ],
        );
      },
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
    final allStatuses = ['accepted', 'picked_up', 'on_the_way', 'delivered'];
    final currentIndex = allStatuses.indexOf(delivery.status);
    
    // Only show current status and the immediately next status to enforce linear flow
    final statuses = allStatuses.where((s) {
      final idx = allStatuses.indexOf(s);
      return idx == currentIndex || idx == currentIndex + 1;
    }).toList();
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: statuses.map((s) => ListTile(
          title: Text(s.replaceAll('_', ' ').toUpperCase()),
          onTap: () async {
            if (s == 'delivered') {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Cash Collected?'),
                  content: const Text('Please confirm that you have collected the cash from the customer before marking this as delivered.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Yes, Collected'),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
            }
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
