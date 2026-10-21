import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class AppImageCacheManager {
  AppImageCacheManager._();

  static final CacheManager instance = CacheManager(
    Config(
      'stylebite_images',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 600,
    ),
  );
}

class AppVideoCacheManager {
  AppVideoCacheManager._();

  static final CacheManager instance = CacheManager(
    Config(
      'stylebite_videos',
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 120,
    ),
  );
}
