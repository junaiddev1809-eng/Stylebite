import 'video_cache_service.dart';

/// Downloads a short window of upcoming reel files. No decoders — that is
/// what was crashing the Android process when done off-screen.
class ReelReadyService {
  ReelReadyService._();

  static const int defaultLimit = 4;

  static void prefetch(Iterable<String> urls, {int limit = defaultLimit}) {
    var count = 0;
    for (final raw in urls) {
      final url = raw.trim();
      if (url.isEmpty || url.startsWith('/')) {
        continue;
      }
      VideoCacheService.prefetch(url);
      count++;
      if (count >= limit) {
        break;
      }
    }
  }
}
