import 'package:flutter/services.dart';

import '../../home/models/home_post_model.dart';
import '../widgets/post_hashtag_chips.dart';

class HashtagCaptionLimit {
  HashtagCaptionLimit._();

  static const int maxTags = 5;

  static List<String> tagsIn(String caption) {
    return hashtagsFromCaption(caption).take(maxTags).toList(growable: false);
  }

  static Set<String> tappableKeys(String caption) {
    return tagsIn(caption).map((tag) => tag.toLowerCase()).toSet();
  }

  static String enforce(String text) {
    final matches = HashtagCaptionText.hashtagPattern.allMatches(text).toList();
    if (matches.isEmpty) {
      return text;
    }

    final seen = <String>{};
    final extraHashIndexes = <int>[];
    for (final match in matches) {
      final key = normalizeHashtag(match.group(0) ?? '').toLowerCase();
      if (key.isEmpty) {
        continue;
      }
      if (seen.contains(key)) {
        continue;
      }
      if (seen.length >= maxTags) {
        extraHashIndexes.add(match.start);
      } else {
        seen.add(key);
      }
    }
    if (extraHashIndexes.isEmpty) {
      return text;
    }

    final buffer = StringBuffer();
    var last = 0;
    for (final index in extraHashIndexes) {
      buffer.write(text.substring(last, index));
      last = index + 1;
    }
    buffer.write(text.substring(last));
    return buffer.toString();
  }
}

class MaxHashtagInputFormatter extends TextInputFormatter {
  const MaxHashtagInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final limited = HashtagCaptionLimit.enforce(newValue.text);
    if (limited == newValue.text) {
      return newValue;
    }
    final removed = newValue.text.length - limited.length;
    final offset = (newValue.selection.baseOffset - removed).clamp(
      0,
      limited.length,
    );
    return TextEditingValue(
      text: limited,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
