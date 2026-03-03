class FeedbackEntity {
  final String? id;
  final String bookingId;
  final String providerId;
  final String seekerId;
  final double rating;
  final String? comment;
  final String? reviewerName;
  final DateTime? createdAt;

  const FeedbackEntity({
    this.id,
    required this.bookingId,
    required this.providerId,
    required this.seekerId,
    required this.rating,
    this.comment,
    this.reviewerName,
    this.createdAt,
  });

  FeedbackEntity copyWith({
    String? id,
    String? bookingId,
    String? providerId,
    String? seekerId,
    double? rating,
    String? comment,
    String? reviewerName,
    DateTime? createdAt,
  }) {
    return FeedbackEntity(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      providerId: providerId ?? this.providerId,
      seekerId: seekerId ?? this.seekerId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      reviewerName: reviewerName ?? this.reviewerName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
