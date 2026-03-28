

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:boxino/core/theme/app_theme.dart';
import 'package:boxino/core/routes/app_router.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    print('DEBUG: Initializing Supabase...');
    await Supabase.initialize(
      url: 'https://zmaddsjqbbbikaqkfmqo.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InptYWRkc2pxYmJiaWthcWtmbXFvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQzNTk2NDgsImV4cCI6MjA4OTkzNTY0OH0.EZ-yStIUwKBjIwZNxXveu1S0p2XiqH3C0XRnNaeFCA8',
    );
    print('DEBUG: Supabase initialized successfully.');

    runApp(
      const ProviderScope(
        child: BoxinoApp(),
      ),
    );
  } catch (e) {
    print('FATAL ERROR: Supabase initialization failed: $e');
    // Still run the app but it will likely show errors that we can handle in the UI
    runApp(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Failed to connect to server: $e\nPlease check your internet connection.'),
            ),
          ),
        ),
      ),
    );
  }
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
