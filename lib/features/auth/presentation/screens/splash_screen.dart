import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:boxino/core/theme/app_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double>   _scaleAnim;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.elasticOut)),
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );

    _controller.forward();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      // Async initialization without blocking the UI thread on cold start
      await Supabase.initialize(
        url: 'https://zmaddsjqbbbikaqkfmqo.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InptYWRkc2pxYmJiaWthcWtmbXFvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQzNTk2NDgsImV4cCI6MjA4OTkzNTY0OH0.EZ-yStIUwKBjIwZNxXveu1S0p2XiqH3C0XRnNaeFCA8',
      );

      // Ensure splash is visible for at least 1.4s (animation duration)
      await Future.delayed(const Duration(milliseconds: 1400));

      if (!mounted) return;

      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        // This will allow GoRouter's redirect guard to route users
        // to /home, /admin, or /delivery based on their role
        context.go('/home');
      } else {
        context.go('/login');
      }
    } catch (e) {
      debugPrint('Initialization error: $e');
      if (mounted) context.go('/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.gradientOrangeGreen,
        ),
        child: Stack(
          children: [
            // Center content
            Center(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: ClipOval(
                            child: Image(
                              image: AssetImage('assets/images/app_logo.png'),
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Boxino',
                        style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Healthy Ghar Jaisa Khana',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
