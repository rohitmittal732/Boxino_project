// ─────────────────────────────────────────────────────────────────────────────
// Login Screen — Modern UI with cloud header, gradient button, Google Sign-In.
//
// FLOW:
//   1. User enters Email + Password
//   2. AuthNotifier.signIn() validates with Supabase
//   3. If INVALID → error shown via SnackBar
//   4. If VALID  → navigate to /home
//   5. Google Sign-In via Supabase OAuth
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:boxino/core/theme/app_theme.dart';
import 'package:boxino/core/providers/auth_notifier.dart';
import 'package:boxino/core/providers/app_providers.dart';
import 'package:boxino/features/auth/presentation/widgets/auth_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _googleLoading   = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset>  _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ─── Email/Password Sign In ────────────────────────────────────────────────
  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email    = _emailController.text.trim();
    final password = _passwordController.text;

    final success = await ref.read(authNotifierProvider.notifier).signIn(email, password);

    if (!mounted) return;
    if (success) {
      _showSnack('Welcome back! 🎉', isSuccess: true);
      context.go('/home');
    } else {
      final error = ref.read(authNotifierProvider).errorMessage ?? 'Login failed.';
      _showSnack(error, isSuccess: false);
    }
  }

  // ─── Google Sign In ────────────────────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    setState(() => _googleLoading = true);
    final success = await ref.read(authNotifierProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    setState(() => _googleLoading = false);
    if (success) {
      _showSnack('Signed in with Google! 🎉', isSuccess: true);
      context.go('/home');
    } else {
      final error = ref.read(authNotifierProvider).errorMessage;
      if (error != null) _showSnack(error, isSuccess: false);
    }
  }

  // ─── Forgot Password ───────────────────────────────────────────────────────
  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnack('Enter your email address first.', isSuccess: false);
      return;
    }
    try {
      await ref.read(supabaseServiceProvider).resetPassword(email);
      if (mounted) {
        _showSnack('Password reset link sent to $email 📧', isSuccess: true);
      }
    } catch (_) {
      if (mounted) _showSnack('Failed to send reset email. Please try again.', isSuccess: false);
    }
  }

  void _showSnack(String msg, {required bool isSuccess}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
      backgroundColor: isSuccess ? AppTheme.primaryGreen : AppTheme.errorRed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // ── Cloud Header ───────────────────────────────────
                const CloudHeader(
                  gradient: AppTheme.gradientHeaderOrange,
                  title: 'Welcome Back!',
                  subtitle: 'Sign in to your Boxino account',
                  icon: Icons.lunch_dining_rounded,
                ),

                // ── Form Card ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        padding: const EdgeInsets.all(28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Section title
                              const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Good to see you again!',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // ── Email field ──────────────────────
                              AuthTextField(
                                controller: _emailController,
                                hintText: 'Email address',
                                prefixIcon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Email is required';
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                                    return 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // ── Password field ───────────────────
                              AuthTextField(
                                controller: _passwordController,
                                hintText: 'Password',
                                prefixIcon: Icons.lock_outline_rounded,
                                obscureText: _obscurePassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppTheme.textGrey,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Password is required';
                                  return null;
                                },
                              ),

                              // ── Forgot password ──────────────────
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: isLoading ? null : _forgotPassword,
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.primaryOrange,
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                  ),
                                  child: const Text(
                                    'Forgot Password?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),

                              // ── Sign In button ────────────────────
                              GradientButton(
                                label: 'Sign In',
                                onPressed: isLoading ? null : _signIn,
                                isLoading: isLoading && !_googleLoading,
                                gradient: AppTheme.gradientOrangeGreen,
                              ),
                              const SizedBox(height: 24),

                              // ── OR divider ────────────────────────
                              const OrDivider(),
                              const SizedBox(height: 20),

                              // ── Google Sign-In ────────────────────
                              GoogleSignInButton(
                                onPressed: (isLoading || _googleLoading) ? null : _signInWithGoogle,
                                isLoading: _googleLoading,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Sign Up link ─────────────────────────────
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                          ),
                          GestureDetector(
                            onTap: isLoading ? null : () => context.push('/signup'),
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                color: AppTheme.primaryOrange,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
