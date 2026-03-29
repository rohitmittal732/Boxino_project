import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:boxino/core/theme/app_theme.dart';
import 'package:boxino/core/providers/app_providers.dart';
import 'package:boxino/domain/models/app_models.dart';

final navIndexProvider = StateProvider<int>((ref) => 0);

final selectedCategoryProvider = StateProvider<String>((ref) => 'All');
final searchQueryProvider = StateProvider<String>((ref) => '');

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
  }






  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(searchQueryProvider.notifier).state = query;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedIdx = ref.watch(navIndexProvider);
    final kitchensAsync = ref.watch(approvedKitchensProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final searchQuery = ref.watch(searchQueryProvider).toLowerCase();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: kitchensAsync.when(
          data: (kitchens) {
            final filteredKitchens = kitchens.where((k) {
              final matchesCategory = selectedCategory == 'All' || 
                                     (selectedCategory == 'Veg' && k.isVeg) || 
                                     (selectedCategory == 'Non-Veg' && k.isNonVeg);
              final matchesSearch = k.name.toLowerCase().contains(searchQuery);
              return matchesCategory && matchesSearch;
            }).toList();


            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopBar(context),

                        const SizedBox(height: 24),
                        _buildSearchBar(),
                        const SizedBox(height: 24),


                        _buildFilterChips(selectedCategory),

                        const SizedBox(height: 32),
                        const Text(
                          'Nearby Home Kitchens',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                if (filteredKitchens.isEmpty)
                  const SliverToBoxAdapter(
                    child: Center(child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No kitchens found in this category.'),
                    )),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: KitchenCard(kitchen: filteredKitchens[index]),
                          );
                        },
                        childCount: filteredKitchens.length,
                      ),
                    ),
                  ),
              ],
            );
          },
          loading: () => const SizedBox(),
          error: (error, stack) => Center(child: Text('Error: $error')),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIdx,
        onTap: (index) {
          ref.read(navIndexProvider.notifier).state = index;
          switch (index) {
            case 0: break; // Already on home
            case 1: context.push('/history'); break;
            case 2: context.push('/profile'); break;
          }
        },

        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryOrange,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],

      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {

    final userEmail = ref.watch(currentUserEmailProvider);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Row(
          children: [
            Icon(Icons.location_on, color: AppTheme.primaryOrange),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Delivering to', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text('Jaipur, Rajasthan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        Row(
          children: [
            Text(userEmail?.split('@')[0] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            const CircleAvatar(
              backgroundColor: AppTheme.primaryGreen,
              radius: 18,
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      onChanged: _onSearchChanged,
      decoration: InputDecoration(

        hintText: 'Search for homemade meals...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }


  Widget _buildFilterChips(String selected) {

    final categories = ['All', 'Veg', 'Non-Veg', 'Fast Delivery'];
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final label = categories[index];
          final isSelected = selected == label;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilterChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) => ref.read(selectedCategoryProvider.notifier).state = label,
              backgroundColor: Colors.white,
              selectedColor: AppTheme.primaryOrange,
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.shade300)),
            ),
          );
        },
      ),
    );
  }
}

class KitchenCard extends ConsumerWidget {
  final KitchenModel kitchen;
  const KitchenCard({super.key, required this.kitchen});


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(userRoleProvider).valueOrNull ?? 'user';
    final isRider = role == 'delivery';


    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 150,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              image: DecorationImage(
                image: NetworkImage(kitchen.imageUrl.isNotEmpty ? kitchen.imageUrl : 'https://via.placeholder.com/400x200?text=Kitchen+Image'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(kitchen.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(kitchen.rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(kitchen.description, style: const TextStyle(color: Colors.grey, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('₹${kitchen.pricePerMeal.toStringAsFixed(0)} / meal', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                    if (!isRider)
                      ElevatedButton(
                        onPressed: () => context.push('/kitchen-detail', extra: kitchen),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('View Menu'),
                      ),
                    if (isRider)
                      const Text('View Only', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),

                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
