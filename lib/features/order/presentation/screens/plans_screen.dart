import 'package:flutter/material.dart';
import 'package:boxino/core/theme/app_theme.dart';

class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Meal Plans'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildPlanCard(
              'Daily Plan',
              'Perfect for a single trial meal.',
              '₹150',
              ['Single Meal', 'Veg/Non-Veg Choice', 'No commitment'],
              Colors.blue,
            ),
            const SizedBox(height: 24),
            _buildPlanCard(
              'Weekly Plan',
              'Saves 10% on daily meals.',
              '₹945',
              ['7 Days', 'Cancel anytime', 'Free delivery'],
              Colors.orange,
            ),
            const SizedBox(height: 24),
            _buildPlanCard(
              'Monthly Plan',
              'The ultimate value for regulars.',
              '₹3600',
              ['30 Days', 'Pause feature', 'Free delivery', 'Priority support'],
              Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(String title, String desc, String price, List<String> features, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 8)),
        ],
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              Text(price, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(desc, style: const TextStyle(color: Colors.grey)),
          const Divider(height: 32),
          ...features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.check_circle, size: 18, color: color),
                const SizedBox(width: 8),
                Text(f),
              ],
            ),
          )),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Choose Plan', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
