import '../home/models/home_post_model.dart';

/// Hidden marker used so Style stories can ride the live posts API
/// and stay hidden from the regular feed / profile grids.
class StoryMarker {
  static const tag = 'sbstory';
  static const hashtag = '#sbstory';

  static bool isStory({
    required List<String> tags,
    required String caption,
  }) {
    final needle = hashtag.toLowerCase();
    for (final tag in tags) {
      if (normalizeHashtag(tag).toLowerCase() == needle) {
        return true;
      }
    }
    return caption.toLowerCase().contains(needle);
  }

  static String encodeCaption(String userCaption) {
    final trimmed = userCaption.trim();
    return trimmed.isEmpty ? hashtag : '$hashtag $trimmed';
  }

  static String displayCaption(String raw) {
    return raw
        .replaceFirst(RegExp(r'^#sbstory\s*', caseSensitive: false), '')
        .trim();
  }

  static List<String> encodeTags(String userCaption) {
    final tags = <String>[tag];
    final seen = <String>{tag};
    for (final item in hashtagsFromCaption(userCaption)) {
      final cleaned = normalizeHashtag(item)
          .replaceFirst('#', '')
          .trim()
          .toLowerCase();
      if (cleaned.isEmpty || !seen.add(cleaned)) {
        continue;
      }
      tags.add(cleaned);
    }
    return tags;
  }
}
