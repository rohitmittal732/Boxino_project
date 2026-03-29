import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:boxino/data/services/supabase_service.dart';
import 'package:boxino/core/theme/app_theme.dart';
import 'package:boxino/core/providers/app_providers.dart';
import 'package:boxino/domain/models/app_models.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
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
    final trackingAsync = ref.watch(combinedTrackingProvider(widget.orderId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Track Order', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: trackingAsync.when(
        data: (data) {
          final order = data['order'] as OrderModel?;
          if (order == null) return const Center(child: Text('Order not found.'));
          
          final customerAsync = ref.watch(riderDetailsProvider(order.userId));
          final eta = order.adminEta ?? 30;

          return SingleChildScrollView(
            child: Column(
              children: [
                // ─── Status & Progress ───────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.status.replaceAll('_', ' ').toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: AppTheme.primaryOrange,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('Order ID: #${order.id.substring(0, 8)}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                const Text('ETA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryOrange)),
                                Text('$eta min', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryOrange)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _getStatusProgress(order.status),
                          backgroundColor: Colors.grey.shade100,
                          color: AppTheme.primaryGreen,
                          minHeight: 10,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _statusPoint('Ordered', true),
                          _statusPoint('Preparing', _getStatusProgress(order.status) >= 0.45),
                          _statusPoint('On Way', _getStatusProgress(order.status) >= 0.85),
                          _statusPoint('Delivered', _getStatusProgress(order.status) >= 1.0),
                        ],
                      ),
                    ],
                  ),
                ),

                // ─── Delivery Partner ────────────────────────────────────────
                if (order.deliveryBoyId != null)
                  _buildProfileCard(
                    title: 'Delivery Partner',
                    name: order.riderName ?? 'Assigning...',
                    phone: order.riderPhone ?? '',
                    icon: Icons.delivery_dining,
                    color: AppTheme.primaryOrange,
                    isMe: ref.watch(currentUserProvider) == order.deliveryBoyId,
                  ),

                // ─── Customer Details ────────────────────────────────────────
                _buildProfileCard(
                  title: 'Delivery Address',
                  name: order.customerName ?? customerAsync.valueOrNull?.name ?? 'User',
                  phone: order.customerPhone ?? customerAsync.valueOrNull?.phone ?? '',
                  address: order.areaName ?? order.userAddress,
                  icon: Icons.home,
                  color: AppTheme.primaryGreen,
                  isMe: ref.watch(currentUserProvider) == order.userId,
                ),

                // ─── Cancellation (Optional) ─────────────────────────────────
                if (order.status == 'pending')
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () async {
                          try {
                            await ref.read(supabaseServiceProvider).updateOrderStatus(order.id, 'cancelled');
                            if (mounted) context.pop();
                          } catch (e) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                          }
                        },
                        child: const Text('CANCEL ORDER', style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),

                // ─── Rider Controls ──────────────────────────────────────────
                if (ref.watch(userRoleProvider).valueOrNull == 'delivery' && (order.status != 'delivered' || order.paymentStatus != 'paid'))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    child: _buildRiderActions(order, ref),
                  ),
                
                const SizedBox(height: 50),
              ],
            ),
          );
        },
        loading: () => const SizedBox(), // No loader
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _statusPoint(String label, bool active) {
    return Column(
      children: [
        Icon(active ? Icons.check_circle : Icons.radio_button_unchecked, size: 16, color: active ? AppTheme.primaryGreen : Colors.grey.shade300),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: active ? Colors.black87 : Colors.grey, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  double _getStatusProgress(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return 0.15;
      case 'accepted': return 0.30;
      case 'preparing': return 0.50;
      case 'picked_up': return 0.70;
      case 'out_for_delivery': return 0.90;
      case 'delivered': return 1.0;
      case 'cancelled': return 0.0;
      default: return 0.0;
    }
  }

  Widget _buildProfileCard({
    required String title,
    required String name,
    required String phone,
    String? address,
    required IconData icon,
    required Color color,
    bool isMe = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            radius: 25,
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (address != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(address, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  ),
              ],
            ),
          ),
          if (phone.isNotEmpty && !isMe)
            IconButton.filled(
              onPressed: () => _makePhoneCall(phone),
              icon: const Icon(Icons.call, size: 22),
              style: IconButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.all(12),
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
      nextStatus = 'paid';
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
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 4,
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
    );
  }
}
