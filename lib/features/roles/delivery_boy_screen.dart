import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:boxino/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:boxino/data/services/supabase_service.dart';
import 'package:boxino/core/providers/app_providers.dart';
import 'package:boxino/core/providers/auth_notifier.dart';
import 'package:boxino/domain/models/app_models.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

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
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      final deliveries = ref.read(deliveryOrdersProvider).valueOrNull ?? [];
      final activeDeliveries = deliveries.where((d) => d.status == 'out_for_delivery').toList();
      
      final userId = ref.read(currentUserProvider);
      if (userId == null) return;

      try {
        final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        final service = ref.read(supabaseServiceProvider);

        final List<Future> futures = [];
        
        // Update rider global position
        final address = await service.getAddressFromLatLng(position.latitude, position.longitude);
        futures.add(service.updateUserProfile(
          userId: userId,
          lat: position.latitude, 
          lng: position.longitude,
          areaName: address,
        ));

        // Update live tracking for active orders
        for (var order in activeDeliveries) {
          futures.add(service.updateLiveLocation(order.id, position.latitude, position.longitude));
        }

        await Future.wait(futures);
      } catch (e) {
        print('DEBUG: GPS Update Fail: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final deliveriesAsync = ref.watch(deliveryOrdersProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final userId = ref.watch(currentUserProvider);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Rider Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
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
            const SizedBox(width: 8),
          ],
          bottom: const TabBar(
            labelColor: AppTheme.primaryOrange,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.primaryOrange,
            tabs: [
              Tab(text: 'Tasks', icon: Icon(Icons.delivery_dining)),
              Tab(text: 'New', icon: Icon(Icons.assignment)),
              Tab(text: 'Earnings', icon: Icon(Icons.payments)),
              Tab(text: 'Profile', icon: Icon(Icons.person)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Active Tasks (picked_up, out_for_delivery)
            _buildOrderList(deliveriesAsync, ['picked_up', 'out_for_delivery'], 'No active tasks'),
            
            // Tab 2: New Orders (accepted)
            _buildOrderList(deliveriesAsync, ['accepted'], 'No new assignments', 
              isNewTab: true, 
              hasActiveTask: (deliveriesAsync.valueOrNull?.any((o) => ['picked_up', 'out_for_delivery'].contains(o.status)) ?? false)
            ),
            
            // Tab 3: Earnings
            const DeliveryEarningsTab(),

            // Tab 4: Profile
            const DeliveryProfileTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList(AsyncValue<List<OrderModel>> asyncOrders, List<String> statuses, String emptyMsg, {bool isNewTab = false, bool hasActiveTask = false}) {
    return asyncOrders.when(
      data: (orders) {
        final filtered = orders.where((o) => statuses.contains(o.status)).toList();
        if (filtered.isEmpty) return Center(child: Text(emptyMsg, style: const TextStyle(color: Colors.grey)));
        
        return ListView.builder(
          itemCount: filtered.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) => DeliveryCard(
            order: filtered[index], 
            isLocked: isNewTab && hasActiveTask,
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }
}

class DeliveryCard extends ConsumerWidget {
  final OrderModel order;
  final bool isLocked;
  const DeliveryCard({super.key, required this.order, this.isLocked = false});

  Future<void> _launchMaps(double lat, double lng) async {
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _makeCall(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final url = 'tel:$phone';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(supabaseServiceProvider);
    final isOnline = ref.watch(isOnlineProvider);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Order #${order.id.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                _buildStatusBadge(order.status),
              ],
            ),
            const Divider(height: 24),
            
            // Customer Info (Now using denormalized metadata)
            Row(
              children: [
                const CircleAvatar(backgroundColor: AppTheme.primaryOrange, child: Icon(Icons.person, color: Colors.white)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.customerName ?? 'Unknown Customer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(order.userAddress, style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _makeCall(order.customerPhone),
                  icon: const Icon(Icons.call, color: Colors.green),
                ),
                IconButton(
                  onPressed: order.userLat != null ? () => _launchMaps(order.userLat!, order.userLng!) : null,
                  icon: const Icon(Icons.directions, color: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Workflow Buttons (Production Level Logic)
            if (!isOnline)
              const Center(child: Text('Go Online to action orders', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)))
            else if (isLocked)
              const Center(child: Text('Finish active task first 🔒', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)))
            else
              _buildWorkflowButton(context, service, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkflowButton(BuildContext context, SupabaseService service, WidgetRef ref) {
    String label = '';
    Color color = AppTheme.primaryOrange;
    String nextStatus = '';

    // Logic based on status flow: accepted -> picked_up -> out_for_delivery -> delivered
    switch (order.status) {
      case 'accepted':
        label = 'PICK UP ORDER';
        nextStatus = 'picked_up';
        color = Colors.blue;
        break;
      case 'picked_up':
        label = 'START MOVEMENT / ON THE WAY';
        nextStatus = 'out_for_delivery';
        color = Colors.deepPurple;
        break;
      case 'out_for_delivery':
        label = 'MARK AS DELIVERED';
        nextStatus = 'delivered';
        color = AppTheme.primaryGreen;
        break;
      case 'delivered':
        if (order.paymentStatus != 'paid') {
          return SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await service.updatePaymentStatus(order.id, 'paid');
                ref.invalidate(deliveryOrdersProvider);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('PAYMENT RECEIVED ✅', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          );
        }
        return const Center(child: Text('ORDER COMPLETED', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)));
      default:
        return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          await service.updateDeliveryStatus(order.id, nextStatus);
          ref.invalidate(deliveryOrdersProvider);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bColor = Colors.grey;
    if (status == 'accepted') bColor = Colors.blue;
    if (status == 'picked_up') bColor = Colors.orange;
    if (status == 'out_for_delivery') bColor = Colors.purple;
    if (status == 'delivered') bColor = Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: bColor)),
      child: Text(status.toUpperCase(), style: TextStyle(color: bColor, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

class DeliveryProfileTab extends ConsumerWidget {
  const DeliveryProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).valueOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const CircleAvatar(radius: 50, backgroundColor: AppTheme.primaryOrange, child: Icon(Icons.delivery_dining, size: 50, color: Colors.white)),
          const SizedBox(height: 24),
          Text(profile?.name ?? 'Partner', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(profile?.phone ?? '', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          ListTile(
            leading: const Icon(Icons.edit, color: AppTheme.primaryOrange),
            title: const Text('Edit Profile'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/edit-profile'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              context.go('/login');
            },
          ),
        ],
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

    return FutureBuilder<List<dynamic>>(
      future: Supabase.instance.client.from('orders').select().eq('delivery_boy_id', userId).eq('status', 'delivered'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final completed = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(gradient: LinearGradient(colors: [AppTheme.primaryOrange, AppTheme.deepOrange]), borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    const Text('Total Deliveries', style: TextStyle(color: Colors.white70)),
                    Text('${completed.length}', style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.builder(
                  itemCount: completed.length,
                  itemBuilder: (context, index) => ListTile(
                    title: Text('Order #${completed[index]['id'].toString().substring(0, 8)}'),
                    subtitle: Text(completed[index]['created_at'].toString().split('T')[0]),
                    trailing: const Text('₹30', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
