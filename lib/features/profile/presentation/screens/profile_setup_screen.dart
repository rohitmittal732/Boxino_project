import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:boxino/core/theme/app_theme.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  String _selectedPreference = 'Veg';
  String _selectedGoal = 'Normal';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill name if available from auth metadata
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _nameController.text = user.userMetadata?['display_name'] ?? '';
      _phoneController.text = user.userMetadata?['phone'] ?? '';
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final location = _locationController.text.trim();

    if (name.isEmpty) {
      _showSnack('Please enter your name');
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      _showSnack('Please enter your phone number');
      return;
    }
    if (location.isEmpty) {
      _showSnack('Please enter your location');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      // Update profile in public.users table
      await Supabase.instance.client.from('users').update({
        'name': name,
        'phone': _phoneController.text.trim(),
        'location_name': location,
        'preference': _selectedPreference,
        // (Other fields can be added if your schema has them, e.g., 'dietary_goal')
      }).eq('id', user.id);

      if (mounted) {
        _showSnack('Profile saved! 🎉');
        context.go('/home');
      }
    } catch (e) {
      _showSnack('Failed to save profile. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Setup Your Profile'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Tell us about yourself',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'This helps us personalize your meal experience',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 28),

            // Name Input
             TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Full Name',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true, fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Phone Input
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'Phone Number',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true, fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Location Input
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: 'Delivery Location',
                prefixIcon: const Icon(Icons.location_on_outlined),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.my_location, color: AppTheme.primaryOrange),
                  onPressed: () {
                    // GPS auto-detect placeholder
                    _locationController.text = 'Detecting location...';
                  },
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true, fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 32),

            // Food Preference
            const Text('Food Preference', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildSelectionCard('Veg', Icons.grass, _selectedPreference == 'Veg', () => setState(() => _selectedPreference = 'Veg'))),
                const SizedBox(width: 16),
                Expanded(child: _buildSelectionCard('Non-Veg', Icons.kebab_dining, _selectedPreference == 'Non-Veg', () => setState(() => _selectedPreference = 'Non-Veg'))),
              ],
            ),
            const SizedBox(height: 32),

            // Dietary Goal
            const Text('Dietary Goal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: ['Normal', 'Weight Loss', 'Gym/Protein'].map((goal) {
                final isSelected = _selectedGoal == goal;
                return ChoiceChip(
                  label: Text(goal),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedGoal = goal);
                  },
                  selectedColor: AppTheme.primaryOrange.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.primaryOrange : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: Colors.grey.shade100,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: isSelected ? AppTheme.primaryOrange : Colors.transparent),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 48),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving
                    ? const SizedBox(height: 22, width: 22)
                    : const Text('Save & Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionCard(String title, IconData icon, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen.withOpacity(0.1) : Colors.white,
          border: Border.all(color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade300, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade600, size: 32),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
