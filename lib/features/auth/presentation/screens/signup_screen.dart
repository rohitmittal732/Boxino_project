// ─────────────────────────────────────────────────────────────────────────────
// Signup Screen — Modern UI with green cloud header, password strength bar,
//                 Google Sign-In, and redirect to Profile Setup on success.
//
// FLOW:
//   1. User enters Name, Email, Password, Confirm Password
//   2. Client-side validation (format, match, strength)
//   3. AuthNotifier.signUp() → Supabase signUp()
//   4. On success → /profile-setup
//   5. Google Sign-In also supported
//
// NOTE: Email confirmation must be DISABLED in Supabase Dashboard
//   → Authentication → Settings → Email Auth → Toggle off "Enable email confirmations"
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:boxino/core/theme/app_theme.dart';
import 'package:boxino/core/providers/auth_notifier.dart';
import 'package:boxino/features/auth/presentation/widgets/auth_widgets.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey                  = GlobalKey<FormState>();
  final _nameController           = TextEditingController();
  final _emailController          = TextEditingController();
  final _passwordController       = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm  = true;
  bool _googleLoading   = false;
  PasswordStrength _strength = PasswordStrength.empty;

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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ─── Email Sign Up ─────────────────────────────────────────────────────────
  Future<void> _signUp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name     = _nameController.text.trim();
    final email    = _emailController.text.trim();
    final password = _passwordController.text;

    final success = await ref.read(authNotifierProvider.notifier).signUp(email, password, name);

    if (!mounted) return;
    if (success) {
      _showSnack('Account created! Welcome to Boxino 🎉', isSuccess: true);
      context.go('/profile-setup');
    } else {
      final error = ref.read(authNotifierProvider).errorMessage ?? 'Signup failed.';
      _showSnack(error, isSuccess: false);
    }
  }

  // ─── Google Sign In (also covers signup flow) ──────────────────────────────
  Future<void> _signInWithGoogle() async {
    setState(() => _googleLoading = true);
    final success = await ref.read(authNotifierProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    setState(() => _googleLoading = false);
    if (success) {
      _showSnack('Signed in with Google! 🎉', isSuccess: true);
      context.go('/profile-setup');
    } else {
      final error = ref.read(authNotifierProvider).errorMessage;
      if (error != null) _showSnack(error, isSuccess: false);
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
                // ── Cloud Header (Green) ────────────────────────────
                const CloudHeader(
                  gradient: AppTheme.gradientHeaderGreen,
                  title: 'Create Account',
                  subtitle: 'Join Boxino — Ghar jaisa healthy khana',
                  icon: Icons.eco_rounded,
                ),

                // ── Form Card ───────────────────────────────────────
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
                                'Sign Up',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Fill in your details to get started',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // ── Full Name ────────────────────────
                              AuthTextField(
                                controller: _nameController,
                                hintText: 'Full Name',
                                prefixIcon: Icons.person_outline_rounded,
                                textCapitalization: TextCapitalization.words,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Name is required';
                                  if (v.trim().length < 2) return 'Name is too short';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // ── Email ────────────────────────────
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

                              // ── Password ─────────────────────────
                              AuthTextField(
                                controller: _passwordController,
                                hintText: 'Password (min 6 chars)',
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
                                onChanged: (v) => setState(() {
                                  _strength = PasswordStrengthBar.evaluate(v);
                                }),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Password is required';
                                  if (v.length < 6) return 'Password must be at least 6 characters';
                                  return null;
                                },
                              ),

                              // ── Password strength bar ─────────────
                              PasswordStrengthBar(strength: _strength),
                              const SizedBox(height: 16),

                              // ── Confirm Password ──────────────────
                              AuthTextField(
                                controller: _confirmPasswordController,
                                hintText: 'Confirm Password',
                                prefixIcon: Icons.lock_reset_rounded,
                                obscureText: _obscureConfirm,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirm
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppTheme.textGrey,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscureConfirm = !_obscureConfirm),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Please confirm your password';
                                  if (v != _passwordController.text) return 'Passwords do not match';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 28),

                              // ── Sign Up Button ────────────────────
                              GradientButton(
                                label: 'Create Account',
                                onPressed: isLoading ? null : _signUp,
                                isLoading: isLoading && !_googleLoading,
                                gradient: AppTheme.gradientGreenOrange,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryGreen.withOpacity(0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
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

                      // ── Already have account link ─────────────────
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                          ),
                          GestureDetector(
                            onTap: isLoading ? null : () => context.go('/login'),
                            child: const Text(
                              'Sign In',
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
