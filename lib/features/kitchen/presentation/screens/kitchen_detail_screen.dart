import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:boxino/core/theme/app_theme.dart';
import 'package:boxino/core/providers/app_providers.dart';
import 'package:boxino/domain/models/app_models.dart';
import 'package:cached_network_image/cached_network_image.dart';

class KitchenDetailScreen extends ConsumerWidget {
  final KitchenModel kitchen;

  const KitchenDetailScreen({super.key, required this.kitchen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menusAsync = ref.watch(kitchenMenusProvider(kitchen.id));
    // 🔥 Optimization: Don't watch the full cart at the top level

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // Banner Image & Back Button
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: CachedNetworkImage(
                imageUrl: kitchen.imageUrl.isNotEmpty ? kitchen.imageUrl : 'https://www.eurokidsindia.com/blog/wp-content/uploads/2023/03/best-healthy-food-for-kids-1.png',
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.grey.shade100),
                errorWidget: (context, url, error) => Image.network('https://www.eurokidsindia.com/blog/wp-content/uploads/2023/03/best-healthy-food-for-kids-1.png', fit: BoxFit.cover),
              ),
            ),
            leading: IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.arrow_back, color: Colors.black),
              ),
              onPressed: () => context.pop(),
            ),
          ),

          // Kitchen info
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        kitchen.name,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 20),
                          const SizedBox(width: 4),
                          Text(kitchen.rating.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(kitchen.description, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (kitchen.isVeg) _buildTag('Veg', Colors.green),
                      if (kitchen.isNonVeg) _buildTag('Non-Veg', Colors.red),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text('Menu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),

          // Menu List
          menusAsync.when(
            data: (menus) {
              if (menus.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Center(child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('No menu items available.'),
                  )),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = menus[index];
                    return MenuItemCard(menu: item);
                  },
                  childCount: menus.length,
                  addAutomaticKeepAlives: true,
                  addRepaintBoundaries: true,
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange)),
              ),
            ),
            error: (e, s) => SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      
      // Cart Summary Bar
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: ref.watch(cartProvider.select((cart) => cart.isNotEmpty))
          ? Consumer(
              builder: (context, ref, child) {
                final totalQuantity = ref.watch(cartProvider.select((cart) => ref.read(cartProvider.notifier).totalQuantity));
                final total = ref.watch(cartProvider.select((cart) => ref.read(cartProvider.notifier).total));
                
                return Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$totalQuantity item${totalQuantity > 1 ? 's' : ''}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Total: ₹$total',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () => context.push('/order-summary'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primaryOrange,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('View Cart'),
                      ),
                    ],
                  ),
                );
              },
            )
          : null,
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class MenuItemCard extends ConsumerWidget {
  final MenuModel menu;
  const MenuItemCard({super.key, required this.menu});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🔥 Optimization: Only rebuild this card when its specific quantity changes
    final quantity = ref.watch(cartProvider.select((cart) => cart[menu.id]?.quantity ?? 0));

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Item Image
          Container(
            width: 80,
            height: 80,
            child: CachedNetworkImage(
              imageUrl: menu.imageUrl.isNotEmpty ? menu.imageUrl : 'https://www.eurokidsindia.com/blog/wp-content/uploads/2023/03/best-healthy-food-for-kids-1.png',
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.grey.shade100),
              errorWidget: (context, url, error) => Image.network('https://www.eurokidsindia.com/blog/wp-content/uploads/2023/03/best-healthy-food-for-kids-1.png', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.circle, size: 10, color: menu.category == 'Veg' ? Colors.green : Colors.red),
                    const SizedBox(width: 4),
                    Text(menu.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Text(menu.description, style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Text('₹${menu.price}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryOrange)),
              ],
            ),
          ),
          
          // Add/Remove Controls
          Column(
            children: [
              if (quantity == 0)
                ElevatedButton(
                  onPressed: () => ref.read(cartProvider.notifier).addItem(menu),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryOrange,
                    side: const BorderSide(color: AppTheme.primaryOrange),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(80, 40),
                  ),
                  child: const Text('Add'),
                )
              else
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: AppTheme.primaryOrange),
                      onPressed: () => ref.read(cartProvider.notifier).removeItem(menu.id),
                    ),
                    Text(quantity.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryOrange),
                      onPressed: () => ref.read(cartProvider.notifier).addItem(menu),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
