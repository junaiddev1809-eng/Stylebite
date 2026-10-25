/// Hidden marker so Flashes/Bites ride the posts API without appearing
/// in the regular Style/Bite feed grids.
class FlashMarker {
  static const tag = 'sbflash';
  static const hashtag = '#sbflash';

  static bool isFlash({
    required List<String> tags,
    required String caption,
  }) {
    final needle = hashtag.toLowerCase();
    for (final tag in tags) {
      if (normalizeTag(tag) == needle.replaceFirst('#', '')) {
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
        .replaceFirst(RegExp(r'^#sbflash\s*', caseSensitive: false), '')
        .trim();
  }

  static List<String> encodeTags(String userCaption) {
    final tags = <String>[tag];
    final seen = <String>{tag};
    final matches = RegExp(r'#(\w+)').allMatches(userCaption);
    for (final match in matches) {
      final cleaned = (match.group(1) ?? '').trim().toLowerCase();
      if (cleaned.isEmpty || !seen.add(cleaned)) {
        continue;
      }
      tags.add(cleaned);
    }
    return tags;
  }

  static String normalizeTag(String raw) {
    return raw.trim().toLowerCase().replaceFirst(RegExp(r'^#'), '');
  }
}
