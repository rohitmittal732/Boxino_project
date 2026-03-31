

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:boxino/core/theme/app_theme.dart';
import 'package:boxino/core/routes/app_router.dart';
import 'package:firebase_core/firebase_core.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 🚀 Start UI immediately!
  runApp(
    const ProviderScope(
      child: BoxinoApp(),
    ),
  );

  // 🔥 Initialize AFTER UI start (background task)
  Future.microtask(() async {
    try {
      print('DEBUG: Supabase async initialization starting...');
      await Supabase.initialize(
        url: 'https://zmaddsjqbbbikaqkfmqo.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InptYWRkc2pxYmJiaWthcWtmbXFvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQzNTk2NDgsImV4cCI6MjA4OTkzNTY0OH0.EZ-yStIUwKBjIwZNxXveu1S0p2XiqH3C0XRnNaeFCA8',
      );
      print('DEBUG: Supabase ready');

      print('DEBUG: Firebase initialization starting...');
      await Firebase.initializeApp();
      print('DEBUG: Firebase ready');
    } catch (e) {
      print('FATAL ERROR: Initialization failed: $e');
    }
  });
}

class BoxinoApp extends ConsumerWidget {
  const BoxinoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Boxino',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
