import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:boxino/core/theme/app_theme.dart';
import 'package:boxino/core/providers/auth_notifier.dart';
import 'package:boxino/features/auth/presentation/widgets/auth_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey         = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passController  = TextEditingController();
  bool _obscureText      = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email    = _emailController.text.trim();
    final password = _passController.text;

    final success = await ref.read(authNotifierProvider.notifier).signIn(email, password);

    if (!mounted) return;
    if (success) {
      if (mounted) {
        // 🔥 IMPROVEMENT: Role-based redirection
        final profile = await ref.read(userProfileProvider.future);
        final role = profile?.role ?? 'user';
        
        if (role == 'delivery') {
          context.go('/delivery');
        } else if (role == 'admin') {

          context.go('/admin');
        } else {
          context.go('/');
        }
      }
    } else {

      final state = ref.read(authNotifierProvider);
      final error = state.errorMessage ?? 'Login failed.';
      _showSnack(error, isSuccess: false);
    }
  }

  void _showSnack(String msg, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isSuccess ? AppTheme.primaryGreen : AppTheme.errorRed,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const CloudHeader(
              gradient: AppTheme.gradientHeaderOrange,
              title: 'Welcome Back!',
              subtitle: 'Ready to order your healthy meal?',
              icon: Icons.lunch_dining_rounded,
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    AuthTextField(
                      controller: _emailController,
                      hintText: 'Email address',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => !v!.contains('@') ? 'Invalid email' : null,
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      controller: _passController,
                      hintText: 'Password',
                      prefixIcon: Icons.lock_outline,
                      obscureText: _obscureText,
                      suffixIcon: IconButton(
                        icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscureText = !_obscureText),
                      ),
                      validator: (v) => v!.isEmpty ? 'Password required' : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.go('/forgot-password'),
                        child: const Text('Forgot Password?'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    GradientButton(
                      label: 'Sign In',
                      onPressed: authState.isLoading ? null : _signIn,
                      isLoading: authState.isLoading,
                    ),
                    const SizedBox(height: 24),
                    GoogleSignInButton(
                      onPressed: () => ref.read(authNotifierProvider.notifier).signInWithGoogle(),
                      isLoading: authState.isLoading,
                    ),
                    const SizedBox(height: 32),
                    TextButton(
                      onPressed: () => context.go('/signup'),
                      child: const Text('New to Boxino? Create Account'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

