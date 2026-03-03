import 'package:equatable/equatable.dart';
import '../../../../core/domain/entities/feedback_entity.dart';

abstract class FeedbackEvent extends Equatable {
  const FeedbackEvent();

  @override
  List<Object?> get props => [];
}

class SubmitProviderFeedbackEvent extends FeedbackEvent {
  final String bookingId;
  final String providerId;
  final String seekerId;
  final double rating;
  final String? comment;

  const SubmitProviderFeedbackEvent({
    required this.bookingId,
    required this.providerId,
    required this.seekerId,
    required this.rating,
    this.comment,
  });

  @override
  List<Object?> get props => [bookingId, providerId, seekerId, rating, comment];
}

class SubmitSeekerFeedbackEvent extends FeedbackEvent {
  final String bookingId;
  final String providerId;
  final String seekerId;
  final double rating;
  final String? comment;

  const SubmitSeekerFeedbackEvent({
    required this.bookingId,
    required this.providerId,
    required this.seekerId,
    required this.rating,
    this.comment,
  });

  @override
  List<Object?> get props => [bookingId, providerId, seekerId, rating, comment];
}

class LoadProviderFeedbacksEvent extends FeedbackEvent {
  final String providerId;

  const LoadProviderFeedbacksEvent({required this.providerId});

  @override
  List<Object?> get props => [providerId];
}

class LoadSeekerFeedbacksEvent extends FeedbackEvent {
  final String seekerId;

  const LoadSeekerFeedbacksEvent({required this.seekerId});

  @override
  List<Object?> get props => [seekerId];
}

class CheckFeedbackExistsEvent extends FeedbackEvent {
  final String bookingId;
  final String reviewerType;

  const CheckFeedbackExistsEvent({
    required this.bookingId,
    required this.reviewerType,
  });

  @override
  List<Object?> get props => [bookingId, reviewerType];
}
