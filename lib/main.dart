

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:boxino/core/theme/app_theme.dart';
import 'package:boxino/core/routes/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zmaddsjqbbbikaqkfmqo.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InptYWRkc2pxYmJiaWthcWtmbXFvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQzNTk2NDgsImV4cCI6MjA4OTkzNTY0OH0.EZ-yStIUwKBjIwZNxXveu1S0p2XiqH3C0XRnNaeFCA8',
  );

  runApp(
    const ProviderScope(
      child: BoxinoApp(),
    ),
  );
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
