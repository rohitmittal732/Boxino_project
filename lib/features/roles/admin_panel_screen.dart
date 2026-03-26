import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boxino/core/theme/app_theme.dart';
import 'package:boxino/core/providers/app_providers.dart';
import 'package:boxino/domain/models/app_models.dart';
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
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(supabaseServiceProvider).signOut(),
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Row(
            children: [
              _buildTab(0, 'Dashboard'),
              _buildTab(1, 'Kitchens'),
              _buildTab(2, 'Orders'),
              _buildTab(3, 'Users'),
            ],
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
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildTab(int index, String label) {
    final isSelected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppTheme.primaryOrange : Colors.transparent,
                width: 2,
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
      ),
    );
  }

  void _showAddKitchenDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final addressController = TextEditingController();
    final priceController = TextEditingController(text: '100');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Kitchen'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
              TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address')),
              TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Price per meal'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final kitchen = KitchenModel(
                id: const Uuid().v4(),
                name: nameController.text,
                imageUrl: '',
                rating: 0,
                description: descController.text,
                isVeg: true,
                isNonVeg: false,
                lat: 26.9124,
                long: 75.7873,
                address: addressController.text,
                pricePerMeal: double.tryParse(priceController.text) ?? 100,
              );
              await ref.read(supabaseServiceProvider).createKitchen(kitchen);
              ref.invalidate(adminKitchensProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
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

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Overview', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildStatCard('Total Revenue', '₹${totalRevenue.toStringAsFixed(0)}', Colors.green, Icons.attach_money)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard('Active Deliveries', '$activeDeliveries', Colors.orange, Icons.delivery_dining)),
                ],
              ),
              const SizedBox(height: 16),
              _buildStatCard('Total Orders', '$totalOrders', Colors.blue, Icons.receipt_long),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error loading dashboard: $e')),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              Expanded(child: Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey))),
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
      data: (kitchens) => ListView.builder(
        itemCount: kitchens.length,
        itemBuilder: (context, index) {
          final k = kitchens[index];
          return ListTile(
            title: Text(k.name),
            subtitle: Text(k.address),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: k.isApproved,
                  onChanged: (val) async {
                    await ref.read(supabaseServiceProvider).toggleKitchenApproval(k.id, val);
                    ref.invalidate(adminKitchensProvider);
                  },
                  activeColor: AppTheme.primaryGreen,
                ),
                IconButton(
                  icon: const Icon(Icons.restaurant_menu),
                  onPressed: () => _showAddMenuDialog(context, ref, k.id),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    await ref.read(supabaseServiceProvider).deleteKitchen(k.id);
                    ref.invalidate(adminKitchensProvider);
                  },
                ),
              ],
            ),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
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
                initialValue: 'Veg',
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
              final menu = MenuModel(
                id: const Uuid().v4(),
                kitchenId: kitchenId,
                name: nameController.text,
                description: descController.text,
                price: double.parse(priceController.text),
                category: categoryController.text,
                imageUrl: '',
              );
              await ref.read(supabaseServiceProvider).addMenu(menu);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Add Item'),
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
                      Text('Order #${o.id.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('₹${o.totalPrice}', style: const TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Status: ${o.status.toUpperCase()}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
                            await ref.read(supabaseServiceProvider).updateOrderStatus(o.id, val);
                            ref.invalidate(adminOrdersProvider);
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
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    ));
  }

  void _showAssignDialog(BuildContext context, WidgetRef ref, String orderId, List<UserModel> deliveryBoys) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: deliveryBoys.map((db) => ListTile(
          title: Text(db.name),
          subtitle: Text(db.email),
          onTap: () async {
            await ref.read(supabaseServiceProvider).assignDelivery(orderId, db.id);
            ref.invalidate(adminOrdersProvider);
            if (context.mounted) Navigator.pop(context);
          },
        )).toList(),
      ),
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
              value: user.role,
              items: ['user', 'admin', 'delivery']
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (newRole) async {
                if (newRole != null) {
                  await ref.read(supabaseServiceProvider).updateUserRole(user.id, newRole);
                  ref.invalidate(allUsersProvider);
                }
              },
            ),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }
}
