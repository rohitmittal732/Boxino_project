import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:boxino/core/theme/app_theme.dart';

class RatingSuccessScreen extends StatefulWidget {
  const RatingSuccessScreen({super.key});

  @override
  State<RatingSuccessScreen> createState() => _RatingSuccessScreenState();
}

class _RatingSuccessScreenState extends State<RatingSuccessScreen> {
  @override
  void initState() {
    super.initState();
    // 🔥 V5 MASTER: Auto redirect after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) context.go('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.green.withOpacity(0.1), blurRadius: 20, spreadRadius: 5),
                ],
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 100,
              ),
            ),
            const SizedBox(height: 48),
            const Text(
              '✅ Feedback Submitted!',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your experience helps thousands of users.',
              style: TextStyle(color: Colors.grey, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            TextButton(
              onPressed: () => context.go('/home'),
              child: const Text('Back to Home', style: TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
