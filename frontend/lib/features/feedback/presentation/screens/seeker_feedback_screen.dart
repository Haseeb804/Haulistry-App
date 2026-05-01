import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/feedback_bloc.dart';
import '../bloc/feedback_event.dart';
import '../bloc/feedback_state.dart';

class SeekerFeedbackScreen extends StatefulWidget {
  final String bookingId;
  final String providerId;
  final String providerName;

  const SeekerFeedbackScreen({
    super.key,
    required this.bookingId,
    required this.providerId,
    required this.providerName,
  });

  @override
  State<SeekerFeedbackScreen> createState() => _SeekerFeedbackScreenState();
}

class _SeekerFeedbackScreenState extends State<SeekerFeedbackScreen> {
  static const int _minCommentLength = 10;

  double _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _hasNavigatedAfterSubmit = false;
  // Tracks the trimmed comment length so the submit button + helper text
  // can react live as the user types.
  int _commentLength = 0;

  @override
  void initState() {
    super.initState();
    _commentController.addListener(_handleCommentChanged);
  }

  @override
  void dispose() {
    _commentController.removeListener(_handleCommentChanged);
    _commentController.dispose();
    super.dispose();
  }

  void _handleCommentChanged() {
    final length = _commentController.text.trim().length;
    if (length != _commentLength) {
      setState(() => _commentLength = length);
    }
  }

  bool get _isCommentValid => _commentLength >= _minCommentLength;
  bool get _canSubmit => _rating > 0 && _isCommentValid;

  /// Sanitize any error that slips through to the UI so the user never
  /// sees backend tokens like "Exception:", "loc:", "input:", "value_error".
  String _userFriendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('comment') ||
        lower.contains('value_error') ||
        lower.contains('string_too_short') ||
        lower.contains('characters long')) {
      return 'Review must be at least 10 characters long.';
    }
    if (lower.contains('rating')) {
      return 'Please select a rating between 1 and 5 stars.';
    }
    if (lower.contains('already submitted')) {
      return 'You have already reviewed this booking.';
    }
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network')) {
      return 'Please check your internet connection and try again.';
    }
    final stripped = raw.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    if (stripped.isEmpty ||
        stripped.contains('{') ||
        stripped.contains('[') ||
        stripped.contains('loc:') ||
        stripped.contains('type:') ||
        stripped.contains('input:')) {
      return 'Something went wrong. Please try again.';
    }
    return stripped;
  }

  void _goToDashboard() {
    if (_hasNavigatedAfterSubmit) return;
    _hasNavigatedAfterSubmit = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(AppRoutes.seekerHome);
    });
  }

  void _submitFeedback() {
    // The submit button is disabled when these aren't met, but we double-check
    // here so a misfire never reaches the backend with invalid data.
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating before submitting.')),
      );
      return;
    }

    final comment = _commentController.text.trim();
    if (comment.length < _minCommentLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Review must be at least 10 characters long.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    context.read<FeedbackBloc>().add(
          SubmitProviderFeedbackEvent(
            bookingId: widget.bookingId,
            providerId: widget.providerId,
            seekerId: user.uid,
            rating: _rating,
            comment: comment,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text('Rate ${widget.providerName}'),
          centerTitle: true,
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: BlocConsumer<FeedbackBloc, FeedbackState>(
        listenWhen: (previous, current) =>
            current is FeedbackSubmitSuccess || current is FeedbackError,
        listener: (context, state) {
          if (state is FeedbackSubmitSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Feedback submitted successfully!')),
            );
            _goToDashboard();
          } else if (state is FeedbackError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_userFriendlyError(state.message))),
            );
          }
        },
          builder: (context, state) {
            final isLoading = state is FeedbackLoading;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.35)),
                    ),
                    child: const Text(
                      'Feedback is required to continue.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                // Provider info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppTheme.primaryColor,
                        child: Text(
                          widget.providerName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Rate Your Experience',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'with ${widget.providerName}',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Rating section
                const Text(
                  'How was the service?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starValue = index + 1.0;
                      return IconButton(
                        iconSize: 48,
                        onPressed: isLoading
                            ? null
                            : () => setState(() => _rating = starValue),
                        icon: Icon(
                          starValue <= _rating ? Icons.star : Icons.star_border,
                          color: starValue <= _rating
                              ? AppTheme.primaryColor
                              : Colors.grey[400],
                        ),
                      );
                    }),
                  ),
                ),
                if (_rating > 0)
                  Center(
                    child: Text(
                      _getRatingText(_rating),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                const SizedBox(height: 32),

                // Comment section
                const Text(
                  'Share your experience (Required)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Write a short review about the provider',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _commentController,
                  enabled: !isLoading,
                  maxLines: 5,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: 'Tell us about your experience with this provider...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    helperText: _isCommentValid
                        ? 'Looks good — ready to submit'
                        : 'Review must be at least 10 characters long ($_commentLength/$_minCommentLength).',
                    helperStyle: TextStyle(
                      color: _isCommentValid
                          ? Colors.green.shade700
                          : AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (isLoading || !_canSubmit) ? null : _submitFeedback,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Submit Feedback',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _getRatingText(double rating) {
    if (rating <= 1) return 'Poor';
    if (rating <= 2) return 'Below Average';
    if (rating <= 3) return 'Average';
    if (rating <= 4) return 'Good';
    return 'Excellent';
  }
}
