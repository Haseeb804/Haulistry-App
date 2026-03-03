import '../../domain/repositories/feedback_repository.dart';
import '../datasources/feedback_remote_datasource.dart';
import '../../../../core/domain/entities/feedback_entity.dart';

class FeedbackRepositoryImpl implements FeedbackRepository {
  final FeedbackRemoteDataSource remoteDataSource;

  FeedbackRepositoryImpl({required this.remoteDataSource});

  @override
  Future<FeedbackEntity> submitProviderFeedback({
    required String bookingId,
    required String providerId,
    required String seekerId,
    required double rating,
    String? comment,
  }) async {
    return await remoteDataSource.submitProviderFeedback(
      bookingId: bookingId,
      providerId: providerId,
      seekerId: seekerId,
      rating: rating,
      comment: comment,
    );
  }

  @override
  Future<FeedbackEntity> submitSeekerFeedback({
    required String bookingId,
    required String providerId,
    required String seekerId,
    required double rating,
    String? comment,
  }) async {
    return await remoteDataSource.submitSeekerFeedback(
      bookingId: bookingId,
      providerId: providerId,
      seekerId: seekerId,
      rating: rating,
      comment: comment,
    );
  }

  @override
  Future<List<FeedbackEntity>> getProviderFeedbacks(String providerId) async {
    return await remoteDataSource.getProviderFeedbacks(providerId);
  }

  @override
  Future<List<FeedbackEntity>> getSeekerFeedbacks(String seekerId) async {
    return await remoteDataSource.getSeekerFeedbacks(seekerId);
  }

  @override
  Future<bool> checkFeedbackExists(String bookingId, String reviewerType) async {
    return await remoteDataSource.checkFeedbackExists(bookingId, reviewerType);
  }
}
