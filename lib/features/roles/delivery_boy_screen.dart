import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:boxino/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:boxino/core/providers/app_providers.dart';
import 'package:boxino/core/providers/auth_notifier.dart';
import 'package:boxino/domain/models/app_models.dart';
import 'package:uuid/uuid.dart';

import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';


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
      final deliveries = ref.read(deliveryOrdersProvider).valueOrNull ?? [];
      final service = ref.read(supabaseServiceProvider);

      final activeDeliveries = deliveries.where((d) => d.status == 'on_the_way').toList();
      if (activeDeliveries.isEmpty) return;

      try {
        final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        final userId = ref.read(currentUserProvider);
        
        final List<Future> futures = [];
        
        // 1. Update global location & Address in users table
        if (userId != null) {
          final address = await service.getAddressFromLatLng(position.latitude, position.longitude);
          futures.add(service.updateUserProfile(
            userId: userId,
            lat: position.latitude, 
            lng: position.longitude,
            areaName: address,
          ));
        }

        // 2. Update active orders for live tracking
        futures.addAll(activeDeliveries.map((d) => service.updateLiveLocation(d.id, position.latitude, position.longitude)));

        await Future.wait(futures);
        
        print('DEBUG: Updated real GPS location and Address for ${activeDeliveries.length + 1} entities');
      } catch (e) {
        print('DEBUG: Location error: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen for new assignments
    ref.listen(deliveryOrdersProvider, (previous, next) {
      if (next is AsyncData && (previous == null || previous is AsyncData)) {
        final newCount = next.valueOrNull?.length ?? 0;
        final oldCount = previous?.valueOrNull?.length ?? 0;
        if (newCount > oldCount) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🚀 New Order Assigned to You!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    });

    final deliveriesAsync = ref.watch(deliveryOrdersProvider);
    final pendingAsync = ref.watch(pendingOrdersProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final userId = ref.watch(currentUserProvider);

    return DefaultTabController(
      length: 4,
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
              onPressed: () async {
                await ref.read(authNotifierProvider.notifier).signOut();
                ref.invalidate(deliveryOrdersProvider);
                ref.invalidate(isOnlineProvider);
                ref.invalidate(userProfileProvider);
                if (context.mounted) {
                  context.go('/login');
                }
              },
            ),
          ],
          bottom: const TabBar(
            labelColor: AppTheme.primaryOrange,
            indicatorColor: AppTheme.primaryOrange,
            isScrollable: false,
            tabs: [
              Tab(text: 'Tasks', icon: Icon(Icons.delivery_dining)),
              Tab(text: 'New', icon: Icon(Icons.new_releases)),
              Tab(text: 'Earnings', icon: Icon(Icons.account_balance_wallet)),
              Tab(text: 'Profile', icon: Icon(Icons.person)),
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
                        title: Text('Order #${order.id.length > 8 ? order.id.substring(0, 8) : order.id}'),
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

            // Tab 4
            const DeliveryProfileTab(),
          ],
        ),
      ),
    );
  }
}

class DeliveryProfileTab extends ConsumerWidget {
  const DeliveryProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      data: (user) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 50,
                backgroundColor: AppTheme.primaryOrange,
                child: Icon(Icons.delivery_dining, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text(user?.name ?? 'Delivery Partner', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(user?.email ?? '', style: const TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.motorcycle, color: AppTheme.primaryOrange),
                      title: const Text('Account Type'),
                      trailing: Text(user?.role.toUpperCase() ?? 'DELIVERY', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.edit, color: AppTheme.primaryOrange),
                      title: const Text('Edit Profile'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/edit-profile'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: const Text('Logout Securely', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      onTap: () async {
                        await ref.read(authNotifierProvider.notifier).signOut();
                        ref.invalidate(deliveryOrdersProvider);
                        ref.invalidate(isOnlineProvider);
                        ref.invalidate(userProfileProvider);
                        if (context.mounted) {
                          context.go('/login');
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error loading profile: $e')),
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
      future: Supabase.instance.client.from('orders').select().eq('delivery_boy_id', userId).eq('status', 'delivered'),
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
  final OrderModel delivery;
  const DeliveryCard({super.key, required this.delivery});

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(riderDetailsProvider(delivery.userId));

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Order #${delivery.id.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                _buildStatusBadge(delivery.status),
              ],
            ),
            const Divider(height: 32),

            // User Info Section
            customerAsync.when(
              data: (user) => Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.blueGrey,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.name ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(delivery.userAddress, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    onPressed: () => _makePhoneCall(user?.phone ?? ''),
                    icon: const Icon(Icons.call),
                    style: IconButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                  ),
                ],
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, s) => const Text('Error loading user info'),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            _buildActionButtons(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    final service = ref.read(supabaseServiceProvider);
    
    // Status Flow: pending -> accepted -> picked_up -> on_the_way -> delivered
    // After delivered: PAYMENT RECEIVED (if not paid)

    if (delivery.status == 'pending') {
      return _actionButton(
        label: 'ACCEPT ORDER',
        color: AppTheme.primaryGreen,
        onPressed: () async {
          final userId = ref.read(currentUserProvider);
          if (userId != null) {
            await service.acceptOrder(delivery.id, userId);
            ref.invalidate(deliveryOrdersProvider);
          }
        },
      );
    }

    if (delivery.status == 'accepted') {
      return _actionButton(
        label: 'PICKED UP',
        color: Colors.blue,
        onPressed: () async {
          await service.updateDeliveryStatus(delivery.id, 'picked_up');
          ref.invalidate(deliveryOrdersProvider);
        },
      );
    }

    if (delivery.status == 'picked_up') {
      return _actionButton(
        label: 'ON THE WAY',
        color: Colors.deepPurple,
        onPressed: () async {
          await service.updateDeliveryStatus(delivery.id, 'on_the_way');
          ref.invalidate(deliveryOrdersProvider);
        },
      );
    }

    if (delivery.status == 'on_the_way') {
      return _actionButton(
        label: 'MARK AS DELIVERED',
        color: AppTheme.primaryOrange,
        onPressed: () async {
          await service.updateDeliveryStatus(delivery.id, 'delivered');
          ref.invalidate(deliveryOrdersProvider);
        },
      );
    }

    if (delivery.status == 'delivered' && delivery.paymentStatus != 'paid') {
      return Column(
        children: [
          const Text('Awaiting Payment Confirmation', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          _actionButton(
            label: 'PAYMENT RECEIVED ✅',
            color: Colors.green,
            onPressed: () async {
              await service.updatePaymentStatus(delivery.id, 'paid');
              ref.invalidate(deliveryOrdersProvider);
            },
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text('COMPLETED', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _actionButton({required String label, required Color color, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = AppTheme.primaryGreen;
    if (status == 'pending') color = Colors.grey;
    if (status == 'accepted') color = Colors.blue;
    if (status == 'picked_up') color = Colors.orange;
    if (status == 'on_the_way') color = Colors.purple;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
