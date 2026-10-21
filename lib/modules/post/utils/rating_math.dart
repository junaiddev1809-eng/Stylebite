import '../../home/models/home_post_model.dart';

/// Next 1–5 average after one viewer changes their rating.
///
/// When the server sent an average but no count, treat that average as one
/// prior vote so the badge still moves on tap until the real count arrives.
double nextRatingAverage({
  required double average,
  required int count,
  required int previous,
  required int next,
}) {
  final nextVote = next.clamp(1, 5);
  final hadPrevious = previous >= 1 && previous <= 5;
  final safeAverage = average.isFinite && average > 0 ? average : 0.0;
  var safeCount = count < 0 ? 0 : count;
  if (safeCount == 0 && safeAverage > 0) {
    safeCount = 1;
  }
  if (!hadPrevious) {
    final nextCount = safeCount + 1;
    final raw = ((safeAverage * safeCount) + nextVote) / nextCount;
    return _clampRating(raw, fallback: nextVote.toDouble());
  }
  final base = safeCount < 1 ? 1 : safeCount;
  final raw = ((safeAverage * base) - previous + nextVote) / base;
  return _clampRating(raw, fallback: nextVote.toDouble());
}

double _clampRating(double raw, {required double fallback}) {
  if (!raw.isFinite || raw < 0) {
    return fallback;
  }
  if (raw > 5) {
    return 5;
  }
  return raw;
}

/// Same contest total the server stores: (average × 70) + (likes × 0.3).
/// Display only. The server remains the ranking source.
double contestTotalScore({
  required double averageRating,
  required int totalLikes,
}) {
  final average =
      averageRating.isFinite && averageRating > 0 ? averageRating : 0.0;
  final likes = totalLikes < 0 ? 0 : totalLikes;
  final raw = (average * 70) + (likes * 0.3);
  return (raw * 100).roundToDouble() / 100;
}

HomePostModel postWithRating({
  required HomePostModel post,
  required int rating,
  double? ratingAverage,
  int? ratingCount,
}) {
  final selected = rating.clamp(1, 5);
  final previous = post.defaultSelectedRate;
  final average = ratingAverage ??
      nextRatingAverage(
        average: post.displayRating,
        count: post.ratingCount,
        previous: previous,
        next: selected,
      );
  final hadPrevious = previous >= 1 && previous <= 5;
  final count = ratingCount ??
      (hadPrevious ? post.ratingCount : post.ratingCount + 1);
  return post.copyWith(
    displayRating: average,
    defaultSelectedRate: selected,
    ratingCount: count < 0 ? 0 : count,
  );
}

HomePostModel? postFromVotePayload(
  HomePostModel post,
  Map<String, dynamic> payload,
) {
  final rating = _readInt(payload['viewer_rating']);
  if (rating == null || rating < 1) {
    return null;
  }
  return postWithRating(
    post: post,
    rating: rating,
    ratingAverage: _readDouble(payload['rating_avg']),
    ratingCount: _readInt(payload['rating_count']),
  );
}

/// A later post refresh must not wipe a rating the viewer just submitted.
HomePostModel preferLocalVote({
  required HomePostModel incoming,
  required int? selected,
  required HomePostModel? local,
}) {
  if (selected == null || selected < 1 || selected > 5) {
    return incoming;
  }
  if (incoming.defaultSelectedRate == selected) {
    return incoming;
  }
  return incoming.copyWith(
    defaultSelectedRate: selected,
    displayRating: local?.displayRating ?? incoming.displayRating,
    ratingCount: local?.ratingCount ?? incoming.ratingCount,
  );
}

int? _readInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value.toString());
}

double? _readDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
