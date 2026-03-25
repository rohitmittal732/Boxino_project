// ─────────────────────────────────────────────────────────────────────────────
// Login Screen — Email + Password Authentication.
//
// FLOW:
//   1. User enters Email + Password
//   2. Calls Supabase signInWithPassword() to validate credentials
//   3. If INVALID → show error message (incorrect email/password, network, etc.)
//   4. If VALID → Navigate directly to Home Screen.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:boxino/core/theme/app_theme.dart';
import 'package:boxino/core/providers/app_providers.dart';
import 'package:boxino/core/providers/auth_providers.dart';

/// Login screen — first step of login: email + password credentials.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  /// Called when user taps "Sign In" button.
  /// Validates credentials with Supabase and navigates to Home on success.
  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Basic empty check
    if (email.isEmpty || password.isEmpty) {
      _showSnack('Please enter email and password');
      return;
    }

    setState(() => _isLoading = true);
    try {
      print('DEBUG: Starting login process for $email');
      
      // Attempt login with Email + Password
      final response = await ref.read(supabaseServiceProvider).signInWithEmail(email, password);
      
      print('DEBUG: Login successful for User ID: ${response.user?.id}');

      if (mounted) {
        _showSnack('Welcome back! 🎉');
        // Login successful — navigate directly to Home Screen
        print('DEBUG: Redirecting directly to /home');
        context.go('/home');
      }
    } on AuthException catch (e) {
      // ── Specific Supabase Auth Exceptions ────────────────────
      print('DEBUG: Supabase AuthException during login: ${e.message} (Code: ${e.statusCode})');
      
      String errorMessage = 'Login failed. Please try again.';
      
      if (e.message.toLowerCase().contains('invalid login credentials') || e.message.toLowerCase().contains('invalid_grant')) {
        errorMessage = 'Incorrect email or password.';
      } else if (e.message.toLowerCase().contains('email not confirmed')) {
        errorMessage = 'Please verify your email first.';
      } else if (e.statusCode == '400') {
        errorMessage = 'Invalid login attempt. Please check your credentials.';
      }
      
      _showSnack(errorMessage);
    } catch (e) {
      // ── General Error handling ───────────────────────────────
      print('DEBUG: Unexpected error during login: $e');
      
      final msg = e.toString();
      if (msg.contains('network') || msg.contains('SocketException')) {
        _showSnack('No internet connection. Please check your network.');
      } else {
        _showSnack('Login failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Shows a floating snackbar message.
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: isWide ? _buildWideLayout() : _buildMobileLayout(),
      ),
    );
  }

  // ─── WIDE LAYOUT (Two-column) ──────────────────────────────────
  Widget _buildWideLayout() {
    return Row(
      children: [
        // Left — Login Card
        Expanded(
          flex: 5,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
              child: _buildLoginCard(),
            ),
          ),
        ),
        // Right — Promotional Illustration
        Expanded(
          flex: 5,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryOrange, AppTheme.primaryGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(40),
                bottomLeft: Radius.circular(40),
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.restaurant_menu, size: 70, color: Colors.white),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Boxino',
                      style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Ghar jaisa healthy khana\ndelivered to your door',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Colors.white70, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── MOBILE LAYOUT (Single column) ────────────────────────────
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Top gradient header with branding
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryOrange, AppTheme.primaryGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                  child: const Icon(Icons.restaurant_menu, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Boxino',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                const Text('Ghar jaisa healthy khana', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          // Login card below the header
          Padding(
            padding: const EdgeInsets.all(24),
            child: _buildLoginCard(),
          ),
        ],
      ),
    );
  }

  // ─── SHARED LOGIN CARD ─────────────────────────────────────────
  Widget _buildLoginCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Welcome Back', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Sign in to continue', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 28),

          // ── Email Input ─────────────────────────────────────────
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'Email address',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: AppTheme.background,
            ),
          ),
          const SizedBox(height: 16),

          // ── Password Input ──────────────────────────────────────
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: AppTheme.background,
            ),
          ),
          const SizedBox(height: 8),

          // ── Forgot Password ─────────────────────────────────────
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                final email = _emailController.text.trim();
                if (email.isEmpty) {
                  _showSnack('Enter your email first');
                  return;
                }
                ref.read(supabaseServiceProvider).resetPassword(email);
                _showSnack('Password reset link sent to $email');
              },
              child: const Text('Forgot Password?', style: TextStyle(color: AppTheme.primaryOrange)),
            ),
          ),
          const SizedBox(height: 8),

          // ── Sign In Button ──────────────────────────────────────
          // Validates credentials and goes directly to Home on success.
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _signIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),

          // ── Don't have an account? Sign Up link ─────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Don't have an account? ", style: TextStyle(color: Colors.grey)),
              GestureDetector(
                onTap: () => context.push('/signup'),
                child: const Text(
                  'Sign Up',
                  style: TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
