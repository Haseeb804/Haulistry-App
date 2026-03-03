import '../../../../core/domain/entities/feedback_entity.dart';

abstract class FeedbackRepository {
  Future<FeedbackEntity> submitProviderFeedback({
    required String bookingId,
    required String providerId,
    required String seekerId,
    required double rating,
    String? comment,
  });

  Future<FeedbackEntity> submitSeekerFeedback({
    required String bookingId,
    required String providerId,
    required String seekerId,
    required double rating,
    String? comment,
  });

  Future<List<FeedbackEntity>> getProviderFeedbacks(String providerId);
  
  Future<List<FeedbackEntity>> getSeekerFeedbacks(String seekerId);
  
  Future<bool> checkFeedbackExists(String bookingId, String reviewerType);
}
