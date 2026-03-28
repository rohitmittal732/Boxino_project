import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boxino/core/theme/app_theme.dart';
import 'package:boxino/core/providers/app_providers.dart';
import 'package:boxino/core/providers/auth_notifier.dart';
import 'package:boxino/domain/models/app_models.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Listen for new orders to show notification
    ref.listen(adminOrdersProvider, (previous, next) {
      if (next is AsyncData && (previous == null || previous is AsyncData)) {
        final newOrders = next.valueOrNull ?? [];
        final oldOrders = previous?.valueOrNull ?? [];
        if (newOrders.length > oldOrders.length) {
          final latest = newOrders.first;
          if (latest.status == 'pending') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🔔 New Order: ${latest.id.substring(0, 8)}'),
                backgroundColor: AppTheme.primaryOrange,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTab(0, 'Home'),
                _buildTab(1, 'Kitchens'),
                _buildTab(2, 'Orders'),
                _buildTab(3, 'Users'),
                _buildTab(4, 'Profile'),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
      floatingActionButton: _tabIndex == 1
          ? FloatingActionButton(
              onPressed: () => _showAddKitchenDialog(context),
              backgroundColor: AppTheme.primaryOrange,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildBody() {
    switch (_tabIndex) {
      case 0: return const AdminDashboardTab();
      case 1: return const AdminKitchensTab();
      case 2: return const AdminOrdersTab();
      case 3: return const AdminUsersTab();
      case 4: return const AdminProfileTab();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildTab(int index, String label) {
    final isSelected = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppTheme.primaryOrange : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppTheme.primaryOrange : Colors.grey,
          ),
        ),
      ),
    );
  }

  void _showAddKitchenDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final addressController = TextEditingController();
    final priceController = TextEditingController(text: '100');
    bool isVegVal = true;
    bool isNonVegVal = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Kitchen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
                TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
                TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address')),
                TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Price per meal'), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Pure Veg'),
                  value: isVegVal,
                  onChanged: (val) => setDialogState(() => isVegVal = val ?? false),
                ),
                CheckboxListTile(
                  title: const Text('Non-Veg Available'),
                  value: isNonVegVal,
                  onChanged: (val) => setDialogState(() => isNonVegVal = val ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final kitchen = KitchenModel(
                    id: const Uuid().v4(),
                    name: nameController.text,
                    imageUrl: '',
                    rating: 0,
                    description: descController.text,
                    isVeg: isVegVal,
                    isNonVeg: isNonVegVal,
                    lat: 26.9124,
                    lng: 75.7873,
                    address: addressController.text,
                    pricePerMeal: double.tryParse(priceController.text) ?? 100,
                    isApproved: true,
                  );
                  await ref.read(supabaseServiceProvider).createKitchen(kitchen);
                  ref.invalidate(adminKitchensProvider);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kitchen Added Successfully!')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding kitchen. Are you an Admin? $e'), backgroundColor: Colors.red));
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminDashboardTab extends ConsumerWidget {
  const AdminDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(adminOrdersProvider);

    return ordersAsync.when(
      data: (orders) {
        final totalOrders = orders.length;
        final totalRevenue = orders
            .where((o) => o.paymentStatus == 'paid' || o.status == 'delivered')
            .fold(0.0, (sum, o) => sum + o.totalPrice);
        final activeDeliveries = orders.where((o) => ['accepted', 'preparing', 'out_for_delivery'].contains(o.status)).length;

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(adminOrdersProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Live Overview', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildStatCard('Total Revenue', '₹${totalRevenue.toStringAsFixed(0)}', Colors.green, Icons.attach_money)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatCard('Active\nDeliveries', '$activeDeliveries', Colors.orange, Icons.delivery_dining)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildStatCard('Total Orders', '$totalOrders', Colors.blue, Icons.receipt_long),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error loading dashboard: $e')),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class AdminKitchensTab extends ConsumerWidget {
  const AdminKitchensTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kitchensAsync = ref.watch(adminKitchensProvider);

    return kitchensAsync.when(
      data: (kitchens) {
        if (kitchens.isEmpty) return const Center(child: Text('No Kitchens Found.'));
        return ListView.builder(
          itemCount: kitchens.length,
          itemBuilder: (context, index) {
            final k = kitchens[index];
            return AdminKitchenCard(kitchen: k);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }
}

class AdminKitchenCard extends ConsumerWidget {
  final KitchenModel kitchen;
  const AdminKitchenCard({super.key, required this.kitchen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menusAsync = ref.watch(kitchenMenusProvider(kitchen.id));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(kitchen.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(kitchen.address, maxLines: 1, overflow: TextOverflow.ellipsis),
        leading: Switch(
          value: kitchen.isApproved,
          onChanged: (val) async {
            await ref.read(supabaseServiceProvider).toggleKitchenApproval(kitchen.id, val);
            ref.invalidate(adminKitchensProvider);
          },
          activeThumbColor: AppTheme.primaryGreen,
        ),
        children: [
          Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit Kitchen'),
                        style: ElevatedButton.styleFrom(padding: EdgeInsets.zero),
                        onPressed: () => _showEditKitchenDialog(context, ref, kitchen),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                        label: const Text('Delete', style: TextStyle(color: Colors.red)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, padding: EdgeInsets.zero),
                        onPressed: () => _confirmDeleteKitchen(context, ref, kitchen),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Text('Menu Items:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Item'),
                      onPressed: () => _showAddMenuDialog(context, ref, kitchen.id),
                    ),
                  ],
                ),
                menusAsync.when(
                  data: (menus) {
                    if (menus.isEmpty) return const Padding(padding: EdgeInsets.all(16.0), child: Text('No items inside this kitchen.'));
                    return Column(
                      children: menus.map((m) => ListTile(
                        title: Text(m.name),
                        subtitle: Text('₹${m.price} - ${m.category}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _showEditMenuDialog(context, ref, m)),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _confirmDeleteMenu(context, ref, m)),
                          ],
                        ),
                      )).toList(),
                    );
                  },
                  loading: () => const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
                  error: (e, s) => Text('Error loading menus: $e', style: const TextStyle(color: Colors.red)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Future<void> _confirmDeleteKitchen(BuildContext context, WidgetRef ref, KitchenModel k) async {
    final res = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Delete Kitchen?'),
      content: Text("Are you sure you want to delete '${k.name}'? This will delete all its menu items too!"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
      ],
    ));
    if (res == true) {
      await ref.read(supabaseServiceProvider).deleteKitchen(k.id);
      ref.invalidate(adminKitchensProvider);
    }
  }

  Future<void> _confirmDeleteMenu(BuildContext context, WidgetRef ref, MenuModel m) async {
    final res = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Delete Item?'),
      content: Text("Are you sure you want to delete '${m.name}'?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
      ],
    ));
    if (res == true) {
      await ref.read(supabaseServiceProvider).deleteMenu(m.id);
      ref.invalidate(kitchenMenusProvider(m.kitchenId));
    }
  }

  void _showEditKitchenDialog(BuildContext context, WidgetRef ref, KitchenModel kitchen) {
    final nameController = TextEditingController(text: kitchen.name);
    final descController = TextEditingController(text: kitchen.description);
    final addressController = TextEditingController(text: kitchen.address);
    final priceController = TextEditingController(text: kitchen.pricePerMeal.toString());
    bool isVegVal = kitchen.isVeg;
    bool isNonVegVal = kitchen.isNonVeg;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Kitchen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
                TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
                TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address')),
                TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Price per meal'), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Pure Veg'),
                  value: isVegVal,
                  onChanged: (val) => setDialogState(() => isVegVal = val ?? false),
                ),
                CheckboxListTile(
                  title: const Text('Non-Veg Available'),
                  value: isNonVegVal,
                  onChanged: (val) => setDialogState(() => isNonVegVal = val ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final k = KitchenModel(
                    id: kitchen.id,
                    name: nameController.text,
                    imageUrl: kitchen.imageUrl,
                    rating: kitchen.rating,
                    description: descController.text,
                    isVeg: isVegVal,
                    isNonVeg: isNonVegVal,
                    lat: kitchen.lat,
                    lng: kitchen.lng,
                    address: addressController.text,
                    pricePerMeal: double.tryParse(priceController.text) ?? kitchen.pricePerMeal,
                    isApproved: kitchen.isApproved,
                  );
                  await ref.read(supabaseServiceProvider).updateKitchen(k);
                  ref.invalidate(adminKitchensProvider);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMenuDialog(BuildContext context, WidgetRef ref, String kitchenId) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final descController = TextEditingController();
    final categoryController = TextEditingController(text: 'Veg');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Menu Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Item Name')),
              TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
              TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Price'), keyboardType: TextInputType.number),
              DropdownButtonFormField<String>(
                value: 'Veg',
                items: ['Veg', 'Non-Veg'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => categoryController.text = val!,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                final menu = MenuModel(
                  id: const Uuid().v4(),
                  kitchenId: kitchenId,
                  name: nameController.text,
                  description: descController.text,
                  price: double.tryParse(priceController.text) ?? 0.0,
                  category: categoryController.text,
                  imageUrl: '',
                );
                await ref.read(supabaseServiceProvider).addMenu(menu);
                ref.invalidate(kitchenMenusProvider(kitchenId));
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item added successfully.')));
                }
              } catch(e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Add Item'),
          ),
        ],
      ),
    );
  }

  void _showEditMenuDialog(BuildContext context, WidgetRef ref, MenuModel m) {
    final nameController = TextEditingController(text: m.name);
    final priceController = TextEditingController(text: m.price.toString());
    final descController = TextEditingController(text: m.description);
    final categoryController = TextEditingController(text: m.category);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Menu Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Item Name')),
              TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
              TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Price'), keyboardType: TextInputType.number),
              DropdownButtonFormField<String>(
                value: m.category,
                items: ['Veg', 'Non-Veg'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => categoryController.text = val!,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                final menu = MenuModel(
                  id: m.id,
                  kitchenId: m.kitchenId,
                  name: nameController.text,
                  description: descController.text,
                  price: double.tryParse(priceController.text) ?? m.price,
                  category: categoryController.text,
                  imageUrl: m.imageUrl,
                );
                await ref.read(supabaseServiceProvider).updateMenu(menu);
                ref.invalidate(kitchenMenusProvider(m.kitchenId));
                if (context.mounted) Navigator.pop(context);
              } catch(e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}

class AdminOrdersTab extends ConsumerStatefulWidget {
  const AdminOrdersTab({super.key});

  @override
  ConsumerState<AdminOrdersTab> createState() => _AdminOrdersTabState();
}

class _AdminOrdersTabState extends ConsumerState<AdminOrdersTab> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(adminOrdersProvider);
    final usersAsync = ref.watch(allUsersProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'All', label: Text('All')),
                ButtonSegment(value: 'Pending', label: Text('Pending')),
                ButtonSegment(value: 'Delivered', label: Text('Delivered')),
              ],
              selected: {_filter},
              onSelectionChanged: (val) => setState(() => _filter = val.first),
              style: SegmentedButton.styleFrom(
                selectedForegroundColor: Colors.white,
                selectedBackgroundColor: AppTheme.primaryOrange,
              ),
            ),
          ),
        ),
        Expanded(
          child: ordersAsync.when(
            data: (orders) {
              final filtered = orders.where((o) {
                if (_filter == 'Pending') return o.status == 'pending';
                if (_filter == 'Delivered') return o.status == 'delivered';
                return true;
              }).toList();

              if (filtered.isEmpty) return const Center(child: Text('No orders found'));

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final o = filtered[index];
                  return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Order #${o.id.length > 8 ? o.id.substring(0, 8) : o.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('₹${o.totalPrice}', style: const TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                   Text('Status: ${o.status.toUpperCase()}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 12),
                  // 🔥 Denormalized Customer Info
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(o.customerName ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Text(o.customerPhone ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Update Status:'),
                      DropdownButton<String>(
                        value: o.status,
                        items: ['pending', 'accepted', 'preparing', 'out_for_delivery', 'delivered']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (val) async {
                          if (val != null) {
                            try {
                              await ref.read(supabaseServiceProvider).updateOrderStatus(o.id, val);
                              // NO manual invalidation required, streams auto-update
                            } catch (e) {
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  usersAsync.when(
                    data: (users) {
                      final deliveryBoys = users.where((u) => u.role == 'delivery').toList();
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Assign Delivery:'),
                          ElevatedButton(
                            onPressed: () => _showAssignDialog(context, ref, o.id, deliveryBoys),
                            child: const Text('Assign'),
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (e, s) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          );
        },
      );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    ),
  ),
      ],
    );
  }

  void _showAssignDialog(BuildContext context, WidgetRef ref, String orderId, List<UserModel> deliveryBoys) {
    if (deliveryBoys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No delivery personnel available.')));
      return;
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 16),
              const Text('Assign Delivery Partner', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              const SizedBox(height: 16),
              const Divider(height: 1),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: deliveryBoys.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 70),
                  itemBuilder: (context, index) {
                    final db = deliveryBoys[index];
                    return _DeliveryBoyListTile(orderId: orderId, db: db, refAction: ref);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeliveryBoyListTile extends StatefulWidget {
  final String orderId;
  final UserModel db;
  final WidgetRef refAction;

  const _DeliveryBoyListTile({
    required this.orderId,
    required this.db,
    required this.refAction,
  });

  @override
  State<_DeliveryBoyListTile> createState() => _DeliveryBoyListTileState();
}

class _DeliveryBoyListTileState extends State<_DeliveryBoyListTile> {
  bool _isLoading = false;
  bool _isSuccess = false;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: _isSuccess ? Colors.green.shade100 : AppTheme.primaryOrange.withOpacity(0.1),
        child: Icon(
          _isSuccess ? Icons.check : Icons.motorcycle,
          color: _isSuccess ? Colors.green : AppTheme.primaryOrange,
        ),
      ),
      title: Text(widget.db.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      subtitle: Text('Status: Available\n${widget.db.email}', style: const TextStyle(fontSize: 13)),
      trailing: _isLoading
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryOrange))
          : _isSuccess
              ? const Icon(Icons.check_circle, color: Colors.green, size: 28)
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  onPressed: () async {
                    setState(() => _isLoading = true);
                    try {
                      await widget.refAction.read(supabaseServiceProvider).assignDelivery(widget.orderId, widget.db.id);
                      if (mounted) {
                        setState(() {
                          _isLoading = false;
                          _isSuccess = true;
                        });
                        await Future.delayed(const Duration(milliseconds: 700));
                        if (mounted && Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(() => _isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
                      }
                    }
                  },
                  child: const Text('Assign'),
                ),
      isThreeLine: true,
    );
  }
}

class AdminUsersTab extends ConsumerWidget {
  const AdminUsersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);

    return usersAsync.when(
      data: (users) => ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return ListTile(
            title: Text(user.name),
            subtitle: Text('${user.email} (${user.role})'),
            trailing: DropdownButton<String>(
              value: ['user', 'admin', 'delivery'].contains(user.role) ? user.role : 'user',
              items: ['user', 'admin', 'delivery']
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (newRole) async {
                if (newRole != null) {
                  try {
                    await ref.read(supabaseServiceProvider).updateUserRole(user.id, newRole);
                    ref.invalidate(allUsersProvider);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Role Updated Successfully!')));
                  } catch(e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                  }
                }
              },
            ),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error loading users: $e')),
    );
  }
}

class AdminProfileTab extends ConsumerWidget {
  const AdminProfileTab({super.key});

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
                child: Icon(Icons.shield, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text(user?.name ?? 'Admin', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
                      leading: const Icon(Icons.admin_panel_settings, color: AppTheme.primaryOrange),
                      title: const Text('Account Type'),
                      trailing: Text(user?.role.toUpperCase() ?? 'ADMIN', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                        ref.invalidate(adminOrdersProvider);
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
