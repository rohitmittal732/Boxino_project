// ─────────────────────────────────────────────────────────────────────────────
// Signup Screen — Allows new users to create an account.
//
// FLOW:
//   1. User enters Name, Email, Password, Confirm Password
//   2. Basic validation (non-empty, valid email format, password ≥6 chars, match)
//   3. Calls Supabase signUp() with name stored in metadata
//   4. On success → shows "Account created successfully!" → navigates to Login
//   5. NO OTP verification during signup (OTP is only used during login)
//
// IMPORTANT: Email confirmation must be DISABLED in Supabase Dashboard
//   → Authentication → Settings → Email Auth → Toggle off "Enable email confirmations"
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:boxino/core/theme/app_theme.dart';
import 'package:boxino/core/providers/app_providers.dart';

/// Signup screen where users create a new Boxino account.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  // Controllers for each text field
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // UI state
  bool _isLoading = false;
  bool _obscurePassword = true;  // Toggle password visibility
  bool _obscureConfirm = true;   // Toggle confirm password visibility

  /// Called when user taps "Sign Up" button.
  /// Validates all fields, then calls Supabase to create the account.
  Future<void> _signUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    // ── Validation ──────────────────────────────────────────────
    if (name.isEmpty) {
      _showSnack('Please enter your name');
      return;
    }
    if (email.isEmpty || password.isEmpty) {
      _showSnack('Please fill all fields');
      return;
    }
    // Simple email format check using regex
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      print('DEBUG: Invalid email format entered: $email');
      _showSnack('Please enter a valid email address');
      return;
    }
    if (password.length < 6) {
      print('DEBUG: Password too short: ${password.length} chars');
      _showSnack('Password must be at least 6 characters');
      return;
    }
    if (password != confirm) {
      print('DEBUG: Passwords do not match');
      _showSnack('Passwords do not match');
      return;
    }

    // ── Signup API call ─────────────────────────────────────────
    setState(() => _isLoading = true);
    try {
      print('DEBUG: Starting signup process for $email');
      // Use the service method that stores the user's name in auth metadata
      final response = await ref.read(supabaseServiceProvider).signUpWithEmailAndName(
            email,
            password,
            name,
          );

      print('DEBUG: Supabase signup response - User ID: ${response.user?.id}');

      if (mounted) {
        // Show success message and redirect to login screen
        _showSnack('Account created successfully! 🎉');
        context.go('/login');
      }
    } on AuthException catch (e) {
      // ── Specific Supabase Auth Exceptions ────────────────────
      print('DEBUG: Supabase AuthException during signup: ${e.message} (Code: ${e.statusCode})');
      
      String errorMessage = 'Signup failed. Please try again.';
      
      if (e.message.contains('User already registered') || e.message.contains('already exists')) {
        errorMessage = 'This email is already registered. Try signing in.';
      } else if (e.message.contains('weak_password') || e.message.contains('Password should be at least')) {
        errorMessage = 'Password is too weak. Please use a stronger password.';
      } else if (e.message.contains('Email address is invalid')) {
        errorMessage = 'The email address provided is invalid.';
      } else if (e.statusCode == '422') {
        errorMessage = 'Invalid signup data. Please check your inputs.';
      }
      
      _showSnack(errorMessage);
    } catch (e) {
      // ── General Error handling ───────────────────────────────
      print('DEBUG: Unexpected error during signup: $e');
      
      final msg = e.toString();
      if (msg.contains('network') || msg.contains('SocketException')) {
        _showSnack('Network error. Please check your internet connection.');
      } else {
        _showSnack('An unexpected error occurred. Please try again later.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Shows a floating snackbar message at the bottom of the screen.
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
    // Always dispose controllers to avoid memory leaks
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Use two-column layout on wide screens (tablets/web), single column on mobile
    final isWide = screenWidth > 800;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: isWide ? _buildWideLayout() : _buildMobileLayout(),
      ),
    );
  }

  // ─── WIDE LAYOUT (Two-column: promo left, form right) ──────────────────
  Widget _buildWideLayout() {
    return Row(
      children: [
        // Left side — promotional gradient panel
        Expanded(
          flex: 5,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryGreen, AppTheme.primaryOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 130, height: 130,
                    decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                    child: const Icon(Icons.restaurant_menu, size: 65, color: Colors.white),
                  ),
                  const SizedBox(height: 32),
                  const Text('Join Boxino', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 12),
                  const Text(
                    'Fresh homemade meals.\nSubscribe today!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.white70, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Right side — signup form card
        Expanded(
          flex: 5,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
              child: _buildSignupCard(),
            ),
          ),
        ),
      ],
    );
  }

  // ─── MOBILE LAYOUT (Single column: gradient header + form below) ───────
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Top gradient header with branding
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryGreen, AppTheme.primaryOrange],
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
                  width: 70, height: 70,
                  decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                  child: const Icon(Icons.restaurant_menu, size: 36, color: Colors.white),
                ),
                const SizedBox(height: 12),
                const Text('Join Boxino', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                const Text('Create your account', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          // Signup card below the header
          Padding(
            padding: const EdgeInsets.all(24),
            child: _buildSignupCard(),
          ),
        ],
      ),
    );
  }

  // ─── SIGNUP CARD (shared by both layouts) ──────────────────────────────
  Widget _buildSignupCard() {
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
          const Text('Create Account', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Fill in your details to get started', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 28),

          // ── Name Field ──────────────────────────────────────────
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Full Name',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: AppTheme.background,
            ),
          ),
          const SizedBox(height: 16),

          // ── Email Field ─────────────────────────────────────────
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

          // ── Password Field ──────────────────────────────────────
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: 'Password (min 6 chars)',
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
          const SizedBox(height: 16),

          // ── Confirm Password Field ──────────────────────────────
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              hintText: 'Confirm Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
              fillColor: AppTheme.background,
            ),
          ),
          const SizedBox(height: 24),

          // ── Sign Up Button ──────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _signUp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
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
                  : const Text('Sign Up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),

          // ── Already have account? Sign In link ──────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Already have an account? ', style: TextStyle(color: Colors.grey)),
              GestureDetector(
                onTap: () => context.go('/login'),
                child: const Text(
                  'Sign In',
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
