// ─────────────────────────────────────────────────────────────────────────────
// Auth Widgets — Shared reusable widgets for Login and Signup screens.
//
// Includes:
//   • GradientButton       — full-width gradient CTA button with loading state
//   • AuthTextField        — styled input field with leading icon
//   • CloudHeader          — cloud-shaped gradient top section
//   • GoogleSignInButton   — white button with Google "G" branding
//   • OrDivider            — "──── OR ────" divider line
//   • PasswordStrengthBar  — animated strength bar for signup
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:boxino/core/theme/app_theme.dart';

// ─── Gradient CTA Button ──────────────────────────────────────────────────────
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final LinearGradient gradient;
  final List<BoxShadow>? boxShadow;

  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.gradient = AppTheme.gradientOrangeGreen,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: onPressed == null ? null : gradient,
        color: onPressed == null ? Colors.grey.shade300 : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: (onPressed != null && !isLoading)
            ? (boxShadow ?? AppTheme.buttonShadow)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (isLoading || onPressed == null) ? null : onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isLoading
                ? const SizedBox(height: 24, width: 24)
                : Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Styled Auth Text Field ───────────────────────────────────────────────────
class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      onChanged: onChanged,
      style: const TextStyle(
        fontSize: 15,
        color: AppTheme.textDark,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(
          prefixIcon,
          color: AppTheme.textGrey,
          size: 20,
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

// ─── Cloud Header Widget ──────────────────────────────────────────────────────
// Creates a top section with a curved/cloud-shaped bottom edge.
class CloudHeader extends StatelessWidget {
  final LinearGradient gradient;
  final String title;
  final String subtitle;
  final IconData icon;
  final double height;

  const CloudHeader({
    super.key,
    required this.gradient,
    required this.title,
    required this.subtitle,
    this.icon = Icons.lunch_dining_rounded,
    this.height = 280,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _CloudClipper(),
      child: Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              // Logo circle
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                ),
                child: Icon(icon, color: Colors.white, size: 38),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 40), // space for the cloud curve
            ],
          ),
        ),
      ),
    );
  }
}

// Custom cloud-shaped clipper
class _CloudClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 50);

    // Left cloud bump
    path.quadraticBezierTo(
      size.width * 0.1, size.height - 80,
      size.width * 0.2, size.height - 50,
    );

    // Mid-left valley
    path.quadraticBezierTo(
      size.width * 0.3, size.height - 20,
      size.width * 0.4, size.height - 45,
    );

    // Center cloud bump (prominent)
    path.quadraticBezierTo(
      size.width * 0.5, size.height - 75,
      size.width * 0.6, size.height - 45,
    );

    // Mid-right valley
    path.quadraticBezierTo(
      size.width * 0.7, size.height - 20,
      size.width * 0.8, size.height - 50,
    );

    // Right cloud bump
    path.quadraticBezierTo(
      size.width * 0.9, size.height - 80,
      size.width, size.height - 50,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ─── Google Sign-In Button ────────────────────────────────────────────────────
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(width: 20, height: 20)
              else ...[
                // Google "G" letter icon using Text for reliability
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: const _GoogleGIcon(),
                ),
                const SizedBox(width: 12),
                Text(
                  'Continue with Google',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Renders the colorful Google "G" using a custom painter
class _GoogleGIcon extends StatelessWidget {
  const _GoogleGIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GoogleGPainter(),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw colored arcs
    final colors = [
      const Color(0xFF4285F4), // Blue
      const Color(0xFF34A853), // Green
      const Color(0xFFFBBC05), // Yellow
      const Color(0xFFEA4335), // Red
    ];

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.butt;

    const sweepAngle = 3.14159 / 2; // 90 degrees each
    for (int i = 0; i < 4; i++) {
      paint.color = colors[i];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 1.5),
        -3.14159 / 2 + i * sweepAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── OR Divider ───────────────────────────────────────────────────────────────
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1.2)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1.2)),
      ],
    );
  }
}

// ─── Password Strength Bar ────────────────────────────────────────────────────
enum PasswordStrength { empty, weak, medium, strong }

class PasswordStrengthBar extends StatelessWidget {
  final PasswordStrength strength;

  const PasswordStrengthBar({super.key, required this.strength});

  static PasswordStrength evaluate(String password) {
    if (password.isEmpty) return PasswordStrength.empty;
    if (password.length < 6) return PasswordStrength.weak;
    final hasUpper = password.contains(RegExp(r'[A-Z]'));
    final hasNumber = password.contains(RegExp(r'[0-9]'));
    final hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    final score = (hasUpper ? 1 : 0) + (hasNumber ? 1 : 0) + (hasSpecial ? 1 : 0);
    if (password.length >= 10 && score >= 2) return PasswordStrength.strong;
    if (password.length >= 8 || score >= 1) return PasswordStrength.medium;
    return PasswordStrength.weak;
  }

  Color get _color {
    switch (strength) {
      case PasswordStrength.weak:   return const Color(0xFFFF4757);
      case PasswordStrength.medium: return const Color(0xFFFFA502);
      case PasswordStrength.strong: return const Color(0xFF2ED573);
      default:                      return Colors.grey.shade200;
    }
  }

  String get _label {
    switch (strength) {
      case PasswordStrength.weak:   return 'Weak';
      case PasswordStrength.medium: return 'Medium';
      case PasswordStrength.strong: return 'Strong';
      default:                      return '';
    }
  }

  int get _activeSegments {
    switch (strength) {
      case PasswordStrength.weak:   return 1;
      case PasswordStrength.medium: return 2;
      case PasswordStrength.strong: return 3;
      default:                      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (strength == PasswordStrength.empty) return const SizedBox.shrink();
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            children: List.generate(3, (i) {
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: i < _activeSegments ? _color : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            'Password strength: $_label',
            style: TextStyle(fontSize: 12, color: _color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
