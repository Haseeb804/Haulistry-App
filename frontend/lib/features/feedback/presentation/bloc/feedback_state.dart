import 'package:equatable/equatable.dart';
import '../../../../core/domain/entities/feedback_entity.dart';

abstract class FeedbackState extends Equatable {
  const FeedbackState();

  @override
  List<Object?> get props => [];
}

class FeedbackInitial extends FeedbackState {}

class FeedbackLoading extends FeedbackState {}

class FeedbackSubmitSuccess extends FeedbackState {
  final FeedbackEntity feedback;

  const FeedbackSubmitSuccess({required this.feedback});

  @override
  List<Object?> get props => [feedback];
}

class FeedbacksLoaded extends FeedbackState {
  final List<FeedbackEntity> feedbacks;

  const FeedbacksLoaded({required this.feedbacks});

  @override
  List<Object?> get props => [feedbacks];
}

class FeedbackExistsChecked extends FeedbackState {
  final bool exists;

  const FeedbackExistsChecked({required this.exists});

  @override
  List<Object?> get props => [exists];
}

class FeedbackError extends FeedbackState {
  final String message;

  const FeedbackError({required this.message});

  @override
  List<Object?> get props => [message];
}
