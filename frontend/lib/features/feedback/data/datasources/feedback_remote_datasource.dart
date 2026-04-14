import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/domain/entities/feedback_entity.dart';

class FeedbackRemoteDataSource {
  final String baseUrl;
  final http.Client client;

  FeedbackRemoteDataSource({
    required this.baseUrl,
    http.Client? client,
  }) : client = client ?? http.Client();

  Future<FeedbackEntity> submitProviderFeedback({
    required String bookingId,
    required String providerId,
    required String seekerId,
    required double rating,
    String? comment,
  }) async {
    final response = await client.post(
      Uri.parse('$baseUrl${ApiEndpoints.feedbackProvider}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'bookingId': bookingId,
        'providerId': providerId,
        'seekerId': seekerId,
        'rating': rating,
        if (comment != null) 'comment': comment,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return _parseFeedback(data['feedback']);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to submit feedback');
    }
  }

  Future<FeedbackEntity> submitSeekerFeedback({
    required String bookingId,
    required String providerId,
    required String seekerId,
    required double rating,
    String? comment,
  }) async {
    final response = await client.post(
      Uri.parse('$baseUrl${ApiEndpoints.feedbackSeeker}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'bookingId': bookingId,
        'providerId': providerId,
        'seekerId': seekerId,
        'rating': rating,
        if (comment != null) 'comment': comment,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return _parseFeedback(data['feedback']);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to submit feedback');
    }
  }

  Future<List<FeedbackEntity>> getProviderFeedbacks(String providerId) async {
    final response = await client.get(
      Uri.parse('$baseUrl${ApiEndpoints.providerFeedbacks(providerId)}'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final feedbacks = data['feedbacks'] as List;
      return feedbacks.map((f) => _parseFeedback(f)).toList();
    } else {
      throw Exception('Failed to load feedbacks');
    }
  }

  Future<List<FeedbackEntity>> getSeekerFeedbacks(String seekerId) async {
    final response = await client.get(
      Uri.parse('$baseUrl${ApiEndpoints.seekerFeedbacks(seekerId)}'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final feedbacks = data['feedbacks'] as List;
      return feedbacks.map((f) => _parseFeedback(f)).toList();
    } else {
      throw Exception('Failed to load feedbacks');
    }
  }

  Future<bool> checkFeedbackExists(String bookingId, String reviewerType) async {
    final response = await client.get(
      Uri.parse('$baseUrl${ApiEndpoints.feedbackExists(bookingId, reviewerType)}'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['exists'] ?? false;
    } else {
      return false;
    }
  }

  FeedbackEntity _parseFeedback(Map<String, dynamic> json) {
    return FeedbackEntity(
      id: json['id'],
      bookingId: json['bookingId'] ?? json['booking_id'] ?? '',
      providerId: json['providerId'] ?? json['provider_id'] ?? '',
      seekerId: json['seekerId'] ?? json['seeker_id'] ?? '',
      rating: (json['rating'] as num).toDouble(),
      comment: json['comment'],
      reviewerName: json['reviewerName'] ?? json['reviewer_name'],
      createdAt: json['createdAt'] != null || json['created_at'] != null
          ? DateTime.parse(json['createdAt'] ?? json['created_at'])
          : null,
    );
  }
}
