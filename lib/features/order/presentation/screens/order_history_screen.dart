import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:boxino/core/theme/app_theme.dart';
import 'package:boxino/core/providers/app_providers.dart';
import 'package:boxino/domain/models/app_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(userOrdersProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(child: Text('You have no orders yet.'));
          }
          return ListView.builder(
            itemCount: orders.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final order = orders[index];
              return _OrderHistoryCard(order: order);
            },
          );
        },
        loading: () => const SizedBox(),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _OrderHistoryCard extends ConsumerWidget {
  final OrderModel order;
  const _OrderHistoryCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Generate a simple timeline component based on status
    final statuses = ['pending', 'accepted', 'preparing', 'picked_up', 'out_for_delivery', 'delivered'];
    final currentIndex = statuses.indexOf(order.status);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/order-tracking', extra: order.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Order #${order.id.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('₹${order.totalPrice}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryOrange)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt.toLocal()),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 16),
              
              // Timeline
              Row(
                children: statuses.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final status = entry.value;
                  final isCompleted = idx <= currentIndex;
                  
                  return Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCompleted ? AppTheme.primaryOrange : Colors.grey.shade300,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          status.split('_')[0],
                          style: TextStyle(
                            fontSize: 10,
                            color: isCompleted ? AppTheme.primaryOrange : Colors.grey,
                            fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 16),
              
              // Allow cancellation if purely pending
              if (order.status == 'pending') ...[
                const Divider(),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      // Ask for confirmation
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Cancel Order?'),
                          content: const Text('Are you sure you want to cancel this order?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
                            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      
                      if (confirm == true) {
                        try {
                          await Supabase.instance.client.from('orders').update({'status': 'cancelled'}).eq('id', order.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order Cancelled')));
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to cancel: $e')));
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                    label: const Text('Cancel Order', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ] else if (order.status != 'delivered') ...[
                const Divider(),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('Tap to track live', style: TextStyle(color: AppTheme.primaryOrange, fontSize: 12, fontWeight: FontWeight.bold)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.primaryOrange),
                  ],
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
