import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../home/models/home_post_model.dart';

class HashtagOpenHelper {
  static String? tagFromQuery(String raw) {
    final trimmed = raw.trim();
    if (!trimmed.startsWith('#')) {
      return null;
    }
    final tag = normalizeHashtag(trimmed);
    if (tag.length < 2) {
      return null;
    }
    return tag;
  }

  static String routeNameFor(String rawTag) {
    final plain = normalizeHashtag(rawTag).replaceFirst('#', '').toLowerCase();
    return '${AppRoutes.hashtagFeed}/${Uri.encodeComponent(plain)}';
  }

  static Future<void> open(String rawTag) async {
    final tag = normalizeHashtag(rawTag);
    if (tag.length < 2) {
      return;
    }
    await Get.toNamed<void>(
      routeNameFor(tag),
      preventDuplicates: false,
    );
  }
}
