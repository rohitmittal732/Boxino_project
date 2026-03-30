import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:boxino/core/theme/app_theme.dart';
import 'package:boxino/core/providers/app_providers.dart';
import 'package:boxino/domain/models/app_models.dart';

class RatingScreen extends ConsumerStatefulWidget {
  final String kitchenId;
  final KitchenModel? kitchen;

  const RatingScreen({super.key, required this.kitchenId, this.kitchen});

  @override
  ConsumerState<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends ConsumerState<RatingScreen> {
  int? _rating; // Start with null to disable button
  final _feedbackController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _onRatingTapped(int rating) {
    setState(() => _rating = rating);
  }

  String _getRatingText() {
    if (_rating == null) return 'Select your rating';
    switch (_rating) {
      case 1: return '😡 Very Bad';
      case 2: return '😕 Bad';
      case 3: return '🙂 Okay';
      case 4: return '😊 Good';
      case 5: return '🤩 Excellent';
      default: return '';
    }
  }

  Future<void> _submitReview() async {
    if (_rating == null) return;
    setState(() => _isSubmitting = true);
    try {
      final service = ref.read(supabaseServiceProvider);
      await service.submitRating(
        kitchenId: widget.kitchenId,
        rating: _rating!,
        feedback: _feedbackController.text.trim(),
      );
      
      ref.invalidate(adminRatingsProvider);
      ref.invalidate(approvedKitchensProvider);
      
      if (mounted) {
        context.go('/rate-success');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.kitchen;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Rate Your Experience', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            if (k != null) ...[
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: NetworkImage(k.imageUrl),
                  backgroundColor: Colors.grey.shade100,
                ),
              ),
              const SizedBox(height: 16),
              Text(k.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(k.address, style: const TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
            ],
            const SizedBox(height: 48),
            Text(_rating == null ? 'Tap to rate' : 'You rated it:', style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starValue = index + 1;
                final isSelected = _rating != null && starValue <= _rating!;
                return GestureDetector(
                  onTap: () => _onRatingTapped(starValue),
                  child: AnimatedScale(
                    scale: isSelected ? 1.3 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.elasticOut,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.star_rounded,
                        size: 46,
                        color: isSelected ? Colors.amber : Colors.grey.shade300,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            if (_rating != null)
              Text(_getRatingText(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryOrange)),
            const SizedBox(height: 40),
            TextField(
              controller: _feedbackController,
              maxLines: 4,
              maxLength: 300,
              decoration: InputDecoration(
                hintText: 'Tell us about your experience...',
                filled: true,
                fillColor: Colors.grey.shade50,
                hintStyle: TextStyle(color: Colors.grey.shade400),
                contentPadding: const EdgeInsets.all(20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.grey.shade100)),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _rating == null ? 0.5 : 1.0,
                child: ElevatedButton(
                  onPressed: (_isSubmitting || _rating == null) ? null : _submitReview,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: Colors.white,
                    elevation: _rating == null ? 0 : 4,
                    shadowColor: AppTheme.primaryOrange.withOpacity(0.4),
                  ),
                  child: _isSubmitting 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Submit Review', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
