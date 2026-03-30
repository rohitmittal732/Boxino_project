import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:boxino/core/theme/app_theme.dart';
import 'package:boxino/core/providers/app_providers.dart';
import 'package:boxino/core/providers/auth_notifier.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);
    final unratedCountAsync = ref.watch(unratedKitchensCountProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: userAsync.when(
        data: (user) => SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 50,
                backgroundColor: AppTheme.primaryOrange,
                child: Icon(Icons.person, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                user?.email ?? 'User',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                'Role: ${user?.role.toUpperCase() ?? 'NONE'}',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              _buildProfileOption(Icons.edit_note, 'Edit Profile', () => context.push('/edit-profile')),
              _buildProfileOption(Icons.receipt_long, 'Order History', () => context.push('/history')),
              _buildProfileOption(Icons.calendar_month, 'Meal Plans', () => context.push('/plans')),
              _buildProfileOption(Icons.location_on, 'Saved Addresses', () {}),
              const SizedBox(height: 16),
              // ⭐ Premium Rate & Feedback Button
              _buildHighlightButton(
                Icons.star_rounded,
                'Rate & Feedback',
                Colors.amber.shade50,
                Colors.amber.shade900,
                () => context.push('/rate-selection'),
                badge: unratedCountAsync.valueOrNull != null && unratedCountAsync.value! > 0 ? 'NEW' : null,
              ),
              const SizedBox(height: 16),
              if (user?.role == 'admin')
                _buildProfileOption(Icons.admin_panel_settings, 'Admin Dashboard', () => context.push('/admin')),
              if (user?.role == 'delivery')
                _buildProfileOption(Icons.delivery_dining, 'Delivery Dashboard', () => context.push('/delivery')),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await ref.read(authNotifierProvider.notifier).signOut();
                      if (context.mounted) {
                        // 🔥 V5 MASTER: Absolute Clean Navigation
                        while (context.canPop()) {
                          context.pop();
                        }
                        context.go('/login');
                      }
                    } catch (e) {
                      if (context.mounted) context.go('/login');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.red,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
        loading: () => const SizedBox(),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildHighlightButton(IconData icon, String title, Color bgColor, Color textColor, VoidCallback onTap, {String? badge}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: textColor.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: textColor),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: textColor.withOpacity(0.5), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryGreen),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
