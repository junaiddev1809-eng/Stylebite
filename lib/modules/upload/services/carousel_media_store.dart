import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/utils/local_storage.dart';

/// Keeps the photos from a carousel on this phone so the post can still
/// swipe through every picture when the feed only returns the first one.
class CarouselMediaStore {
  static const _storageKey = 'carouselPostMedia';

  static List<String> pathsFor(String postId) {
    final id = postId.trim();
    if (id.isEmpty) {
      return const [];
    }
    final saved = _read()[id];
    if (saved == null) {
      return const [];
    }
    return [
      for (final path in saved)
        if (path.trim().isNotEmpty && File(path).existsSync()) path,
    ];
  }

  static Future<void> remember({
    required String postId,
    required List<String> sourcePaths,
  }) async {
    final id = postId.trim();
    if (id.isEmpty || sourcePaths.length < 2) {
      return;
    }
    final docs = await getApplicationDocumentsDirectory();
    final folder = Directory('${docs.path}/carousel_posts/$id');
    if (!folder.existsSync()) {
      await folder.create(recursive: true);
    }
    final stored = <String>[];
    for (var i = 0; i < sourcePaths.length && i < 10; i++) {
      final source = File(sourcePaths[i]);
      if (!source.existsSync()) {
        continue;
      }
      final ext = source.path.split('.').last;
      final target = File('${folder.path}/$i.$ext');
      if (target.path != source.path) {
        await source.copy(target.path);
      }
      stored.add(target.path);
    }
    if (stored.length < 2) {
      return;
    }
    final all = _read();
    all[id] = stored;
    await LocalStorage.prefs.setString(_storageKey, jsonEncode(all));
  }

  static Map<String, List<String>> _read() {
    final raw = LocalStorage.prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return {};
      }
      return {
        for (final entry in decoded.entries)
          entry.key.toString(): [
            for (final path in (entry.value as List? ?? const []))
              path.toString(),
          ],
      };
    } catch (_) {
      return {};
    }
  }
}
