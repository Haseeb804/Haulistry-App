import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/feedback_repository.dart';
import 'feedback_event.dart';
import 'feedback_state.dart';

class FeedbackBloc extends Bloc<FeedbackEvent, FeedbackState> {
  final FeedbackRepository repository;

  FeedbackBloc({required this.repository}) : super(FeedbackInitial()) {
    on<SubmitProviderFeedbackEvent>(_onSubmitProviderFeedback);
    on<SubmitSeekerFeedbackEvent>(_onSubmitSeekerFeedback);
    on<LoadProviderFeedbacksEvent>(_onLoadProviderFeedbacks);
    on<LoadSeekerFeedbacksEvent>(_onLoadSeekerFeedbacks);
    on<CheckFeedbackExistsEvent>(_onCheckFeedbackExists);
  }

  Future<void> _onSubmitProviderFeedback(
    SubmitProviderFeedbackEvent event,
    Emitter<FeedbackState> emit,
  ) async {
    emit(FeedbackLoading());
    try {
      final feedback = await repository.submitProviderFeedback(
        bookingId: event.bookingId,
        providerId: event.providerId,
        seekerId: event.seekerId,
        rating: event.rating,
        comment: event.comment,
      );
      emit(FeedbackSubmitSuccess(feedback: feedback));
    } catch (e) {
      emit(FeedbackError(message: e.toString()));
    }
  }

  Future<void> _onSubmitSeekerFeedback(
    SubmitSeekerFeedbackEvent event,
    Emitter<FeedbackState> emit,
  ) async {
    emit(FeedbackLoading());
    try {
      final feedback = await repository.submitSeekerFeedback(
        bookingId: event.bookingId,
        providerId: event.providerId,
        seekerId: event.seekerId,
        rating: event.rating,
        comment: event.comment,
      );
      emit(FeedbackSubmitSuccess(feedback: feedback));
    } catch (e) {
      emit(FeedbackError(message: e.toString()));
    }
  }

  Future<void> _onLoadProviderFeedbacks(
    LoadProviderFeedbacksEvent event,
    Emitter<FeedbackState> emit,
  ) async {
    emit(FeedbackLoading());
    try {
      final feedbacks = await repository.getProviderFeedbacks(event.providerId);
      emit(FeedbacksLoaded(feedbacks: feedbacks));
    } catch (e) {
      emit(FeedbackError(message: e.toString()));
    }
  }

  Future<void> _onLoadSeekerFeedbacks(
    LoadSeekerFeedbacksEvent event,
    Emitter<FeedbackState> emit,
  ) async {
    emit(FeedbackLoading());
    try {
      final feedbacks = await repository.getSeekerFeedbacks(event.seekerId);
      emit(FeedbacksLoaded(feedbacks: feedbacks));
    } catch (e) {
      emit(FeedbackError(message: e.toString()));
    }
  }

  Future<void> _onCheckFeedbackExists(
    CheckFeedbackExistsEvent event,
    Emitter<FeedbackState> emit,
  ) async {
    try {
      final exists = await repository.checkFeedbackExists(
        event.bookingId,
        event.reviewerType,
      );
      emit(FeedbackExistsChecked(exists: exists));
    } catch (e) {
      emit(FeedbackError(message: e.toString()));
    }
  }
}
