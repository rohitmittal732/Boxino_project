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
import 'package:boxino/features/roles/widgets/payout_request_sheet.dart';

class DeliveryBoyScreen extends ConsumerStatefulWidget {
  const DeliveryBoyScreen({super.key});

  @override
  ConsumerState<DeliveryBoyScreen> createState() => _DeliveryBoyScreenState();
}

class _DeliveryBoyScreenState extends ConsumerState<DeliveryBoyScreen> {
  @override
  void dispose() {
    super.dispose();
  }

  void _toggleOnline(bool val) {
    ref.read(isOnlineProvider.notifier).state = val;
  }

  @override
  Widget build(BuildContext context) {
    final deliveriesAsync = ref.watch(deliveryOrdersProvider);
    final isOnline = ref.watch(isOnlineProvider);

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
            _buildOrderList(deliveriesAsync, ['picked_up', 'out_for_delivery'], 'No active tasks'),
            _buildOrderList(deliveriesAsync, ['accepted'], 'No new assignments', 
              isNewTab: true, 
              hasActiveTask: (deliveriesAsync.valueOrNull?.any((o) => ['picked_up', 'out_for_delivery'].contains(o.status)) ?? false)
            ),
            const DeliveryEarningsTab(),
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
      loading: () => const SizedBox(), // Removed loader
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }
}

class DeliveryCard extends ConsumerWidget {
  final OrderModel order;
  final bool isLocked;
  const DeliveryCard({super.key, required this.order, this.isLocked = false});

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
      child: InkWell(
        onTap: () => context.push('/order-tracking', extra: order),
        borderRadius: BorderRadius.circular(16),
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
              
              Row(
                children: [
                  const CircleAvatar(backgroundColor: AppTheme.primaryOrange, child: Icon(Icons.person, color: Colors.white)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.customerName ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(order.customerPhone ?? 'No number', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.call, color: Colors.green),
                      onPressed: () => _makeCall(order.customerPhone),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              
              if (!isOnline)
                const Center(child: Text('Go Online to action orders', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)))
              else if (isLocked)
                const Center(child: Text('Finish active task first 🔒', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)))
              else
                _buildWorkflowButton(context, service, ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkflowButton(BuildContext context, SupabaseService service, WidgetRef ref) {
    String label = '';
    Color color = AppTheme.primaryOrange;
    String nextStatus = '';

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
              if (context.mounted) {
                while (context.canPop()) {
                  context.pop();
                }
                context.go('/login');
              }
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
        if (!snapshot.hasData) return const SizedBox(); // Removed loader
        
        final orders = (snapshot.data as List).map((o) => OrderModel.fromJson(o as Map<String, dynamic>)).toList();
        final totalEarnings = orders.fold(0.0, (sum, o) => sum + o.riderEarning);

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primaryOrange, Color(0xFFFF8C00)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryOrange.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text('Available Balance', style: TextStyle(color: Colors.white70, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text('₹${totalEarnings.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMiniStat('Orders', '${orders.length}', Icons.shopping_bag_outlined),
                              Container(width: 1, height: 30, color: Colors.white24),
                              _buildMiniStat('Bonus', '₹0', Icons.stars_outlined),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: totalEarnings > 0 ? () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => PayoutRequestSheet(amount: totalEarnings),
                          );
                        } : null,
                        icon: const Icon(Icons.account_balance_wallet_outlined),
                        label: const Text('REQUEST PAYOUT', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: AppTheme.primaryOrange),
                          foregroundColor: AppTheme.primaryOrange,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    const Text('Recent Deliveries', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final order = orders[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.green.shade50,
                            child: const Icon(Icons.check, color: Colors.green, size: 20),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Order #${order.id.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text(order.createdAt.toString().split(' ')[0], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                          const Text('+ ₹40', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
                        ],
                      ),
                    );
                  },
                  childCount: orders.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        );
      },
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
