import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:boxino/core/theme/app_theme.dart';
import 'package:boxino/core/providers/auth_notifier.dart';
import 'package:boxino/features/auth/presentation/widgets/auth_widgets.dart';

class OtpVerifyScreen extends ConsumerStatefulWidget {
  final String phone;
  const OtpVerifyScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  int _timerSeconds = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    setState(() => _timerSeconds = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds == 0) {
        timer.cancel();
      } else {
        setState(() => _timerSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final otp = _otpController.text.trim();
    final success = await ref.read(authNotifierProvider.notifier).verifyFirebaseOtp(otp);

    if (success && mounted) {
      context.go('/home'); 
    } else if (!success && mounted) {
      final error = ref.read(authNotifierProvider).errorMessage ?? 'Invalid OTP';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: AppTheme.errorRed,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            CloudHeader(
              gradient: AppTheme.gradientHeaderGreen,
              title: 'Verify OTP',
              subtitle: 'OTP sent to ${widget.phone}',
              icon: Icons.mark_email_read_rounded,
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    AuthTextField(
                      controller: _otpController,
                      hintText: '6 Digit OTP',
                      prefixIcon: Icons.lock_person_rounded,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      letterSpacing: 8,
                      maxLength: 6,
                      validator: (v) {
                        if (v == null || v.length != 6) return 'Enter 6 digits';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    GradientButton(
                      label: 'Verify & Login',
                      onPressed: authState.isLoading ? null : _verifyOtp,
                      isLoading: authState.isLoading,
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: _timerSeconds == 0 ? () {
                        ref.read(authNotifierProvider.notifier).sendFirebaseOtp(
                          phone: widget.phone,
                          onCodeSent: (_) => _startTimer(),
                          onError: (e) => ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e), backgroundColor: AppTheme.errorRed),
                          ),
                        );
                      } : null,
                      child: Text(
                        _timerSeconds == 0 
                          ? 'Resend OTP' 
                          : 'Resend in ${_timerSeconds}s',
                        style: TextStyle(
                          color: _timerSeconds == 0 ? AppTheme.primaryOrange : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
