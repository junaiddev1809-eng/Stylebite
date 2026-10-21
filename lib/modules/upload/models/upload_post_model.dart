enum UploadPostType { outfit, food }

enum UploadPostVisibility { public, followersOnly, private }

class FoodRatingItem {
  const FoodRatingItem({
    required this.key,
    required this.label,
    required this.initial,
  });

  final String key;
  final String label;
  final double initial;
}
