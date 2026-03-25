// ─────────────────────────────────────────────────────────────────────────────
// OTP Verification Screen — Step 2 of two-step authentication.
//
// FLOW:
//   1. User arrives here after successful email+password login
//   2. An OTP has already been sent to their email (by the Login screen)
//   3. User enters the 6-digit code in 6 separate input boxes
//   4. Calls Supabase verifyOTP() to validate the code
//   5. If VALID → creates a session → navigates to /home
//   6. If INVALID → shows error, user can retry or resend OTP
//
// UI FEATURES:
//   • 6 separate input boxes (one digit each)
//   • Auto-focus moves to next box after typing a digit
//   • Backspace moves focus back to previous box
//   • Active box has highlighted orange border
//   • "Resend OTP" button with a 30-second cooldown timer
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:boxino/core/theme/app_theme.dart';
import 'package:boxino/core/providers/app_providers.dart';
import 'package:boxino/core/providers/auth_providers.dart';

/// OTP verification screen — second step of login.
/// Verifies the 6-digit code sent to the user's email.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  // 6 controllers — one for each digit input box
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());

  // 6 focus nodes — to control which box is currently focused
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;

  // ── Resend OTP timer state ──────────────────────────────────────
  int _resendSeconds = 30; // Countdown starts at 30 seconds
  Timer? _resendTimer;
  bool _canResend = false; // Initially false (timer running)

  @override
  void initState() {
    super.initState();
    _startResendTimer(); // Start the 30s cooldown when screen opens
  }

  /// Starts a 30-second countdown timer for the "Resend OTP" button.
  /// While the timer is running, the resend button is disabled.
  void _startResendTimer() {
    setState(() {
      _resendSeconds = 30;
      _canResend = false;
    });
    _resendTimer?.cancel(); // Cancel any existing timer
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds <= 1) {
        // Timer finished — enable the resend button
        timer.cancel();
        if (mounted) setState(() => _canResend = true);
      } else {
        if (mounted) setState(() => _resendSeconds--);
      }
    });
  }

  /// Called when user taps "Verify OTP" button.
  /// Combines all 6 digits and calls Supabase verifyOTP().
  Future<void> _verifyOtp() async {
    // Combine the 6 individual digit inputs into a single OTP string
    final otp = _controllers.map((c) => c.text.trim()).join();

    // Validate that all 6 digits have been entered
    if (otp.length != 6) {
      _showSnack('Please enter all 6 digits');
      return;
    }

    // Read the email that was stored by the login screen
    final email = ref.read(otpEmailProvider);
    if (email.isEmpty) {
      print('DEBUG: OTP Verification failed - email provider is empty');
      _showSnack('Session expired. Please login again.');
      if (mounted) context.go('/login');
      return;
    }

    setState(() => _isLoading = true);
    try {
      print('DEBUG: Starting OTP verification for $email with code $otp');
      // Call Supabase to verify the OTP code
      final response = await ref.read(supabaseServiceProvider).verifyEmailOtp(email, otp);

      print('DEBUG: OTP verification successful for ${response.user?.id}');

      if (mounted) {
        _showSnack('Login successful! Welcome to Boxino 🎉');
        // OTP verified — user is now fully authenticated, go to Home
        print('DEBUG: Redirecting to /home');
        context.go('/home');
      }
    } on AuthException catch (e) {
      // ── Specific Supabase Auth Exceptions ────────────────────
      print('DEBUG: Supabase AuthException during OTP verify: ${e.message} (Code: ${e.statusCode})');
      
      String errorMessage = 'OTP verification failed. Please try again.';
      
      if (e.message.contains('expired')) {
        errorMessage = 'OTP has expired. Please request a new one.';
      } else if (e.message.contains('invalid') || e.message.contains('Incorrect')) {
        errorMessage = 'Invalid OTP code. Please check and try again.';
      }
      
      _showSnack(errorMessage);
    } catch (e) {
      // ── General Error handling ───────────────────────────────
      print('DEBUG: Unexpected error during OTP verify: $e');
      
      final msg = e.toString();
      if (msg.contains('network') || msg.contains('SocketException')) {
        _showSnack('Network error. Please check your connection.');
      } else {
        _showSnack('OTP verification failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Resends the OTP to the user's email and restarts the cooldown timer.
  Future<void> _resendOtp() async {
    final email = ref.read(otpEmailProvider);
    if (email.isEmpty) {
      print('DEBUG: Resend OTP failed - email provider is empty');
      _showSnack('Session expired. Please login again.');
      if (mounted) context.go('/login');
      return;
    }

    try {
      print('DEBUG: Requesting OTP resend for $email');
      await ref.read(supabaseServiceProvider).sendEmailOtp(email);
      print('DEBUG: OTP resend request successful');
      _showSnack('New OTP sent to $email');
      _startResendTimer(); // Restart the 30s cooldown
    } on AuthException catch (e) {
      print('DEBUG: Supabase AuthException during OTP resend: ${e.message}');
      _showSnack('Failed to resend OTP: ${e.message}');
    } catch (e) {
      print('DEBUG: Unexpected error during OTP resend: $e');
      _showSnack('Failed to resend OTP. Please try again.');
    }
  }

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
    // Clean up all controllers, focus nodes, and the timer
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _resendTimer?.cancel();
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

  // ─── WIDE LAYOUT ──────────────────────────────────────────────────
  Widget _buildWideLayout() {
    return Row(
      children: [
        // Left — OTP Card
        Expanded(
          flex: 5,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
              child: _buildOtpCard(),
            ),
          ),
        ),
        // Right — Security illustration
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
                    child: const Icon(Icons.verified_user, size: 70, color: Colors.white),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Secure Login',
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'One more step to keep\nyour account safe',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.white70, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── MOBILE LAYOUT ────────────────────────────────────────────────
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Top gradient header
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
                  child: const Icon(Icons.verified_user, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Verify Identity',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                const Text('One more step for your security', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          // OTP card
          Padding(
            padding: const EdgeInsets.all(24),
            child: _buildOtpCard(),
          ),
        ],
      ),
    );
  }

  // ─── OTP CARD (shared by both layouts) ────────────────────────────
  Widget _buildOtpCard() {
    // Read the email to display it (partially masked for privacy)
    final email = ref.watch(otpEmailProvider);

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
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Title ────────────────────────────────────────────────
          const Text(
            'Verify your identity',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the 6-digit code sent to\n$email',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, height: 1.4),
          ),
          const SizedBox(height: 32),

          // ── 6 OTP Input Boxes ───────────────────────────────────
          // Each box holds exactly one digit. Focus auto-moves on input.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (index) => _buildOtpBox(index)),
          ),
          const SizedBox(height: 32),

          // ── Verify OTP Button ───────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _verifyOtp,
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
                  : const Text('Verify OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),

          // ── Resend OTP Button with Timer ─────────────────────────
          // Disabled during the 30s cooldown, enabled after timer ends.
          _canResend
              ? TextButton(
                  onPressed: _resendOtp,
                  child: const Text(
                    'Resend OTP',
                    style: TextStyle(
                      color: AppTheme.primaryOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : Text(
                  'Resend OTP in ${_resendSeconds}s',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                ),

          const SizedBox(height: 16),

          // ── Back to Login link ──────────────────────────────────
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text(
              '← Back to Login',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a single OTP input box at the given [index].
  ///
  /// Features:
  ///   • Accepts exactly 1 digit
  ///   • Auto-focuses the next box when a digit is entered
  ///   • Moves focus to the previous box on backspace
  ///   • Active box has an orange border highlight
  Widget _buildOtpBox(int index) {
    return Container(
      width: 48,
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: (event) {
          // Handle backspace: if the current box is empty and user presses
          // backspace, move focus to the previous box
          if (event is RawKeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              _controllers[index].text.isEmpty &&
              index > 0) {
            _controllers[index - 1].clear();
            _focusNodes[index - 1].requestFocus();
          }
        },
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          // Only allow single digits (0-9)
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(1),
          ],
          decoration: InputDecoration(
            counterText: '', // Hide the "0/1" counter
            filled: true,
            fillColor: AppTheme.background,
            // The border color changes based on focus:
            // Orange when focused (active), light grey when not
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primaryOrange, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onChanged: (value) {
            if (value.isNotEmpty && index < 5) {
              // Digit entered → auto-focus the next box
              _focusNodes[index + 1].requestFocus();
            }
            if (value.isEmpty && index > 0) {
              // Digit deleted → move focus back to previous box
              _focusNodes[index - 1].requestFocus();
            }
          },
        ),
      ),
    );
  }
}
