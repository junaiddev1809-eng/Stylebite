class StyleRatingModel {
  const StyleRatingModel({
    required this.averageRating,
    required this.totalRatings,
    required this.distribution,
  });

  final double averageRating;
  final int totalRatings;
  final Map<int, int> distribution;

  factory StyleRatingModel.fromJson(Map<String, dynamic> json) {
    final distRaw = (json['distribution'] as Map?) ?? {};
    final dist = <int, int>{};
    for (var i = 1; i <= 5; i++) {
      dist[i] = (distRaw[i.toString()] as num?)?.toInt() ?? 0;
    }

    return StyleRatingModel(
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      totalRatings: (json['total_ratings'] as num?)?.toInt() ?? 0,
      distribution: dist,
    );
  }

  // Mock data for development if API is not ready
  factory StyleRatingModel.mock() {
    return const StyleRatingModel(
      averageRating: 4.7,
      totalRatings: 1240,
      distribution: {
        5: 850,
        4: 250,
        3: 100,
        2: 30,
        1: 10,
      },
    );
  }
}
