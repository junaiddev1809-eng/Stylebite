import 'dart:math' as math;

import '../../modules/home/models/home_post_model.dart';
import '../../modules/reel/models/reel_item_model.dart';

/// Instagram / TikTok style ranking used by Explore, For You, and Reels.
///
/// Volume alone does not win. A post trends when people take expensive
/// actions (comment, share, save) quickly, the like/view rate holds up
/// against peers, and the author is not stacked on top of themselves.
class TrendingSignals {
  const TrendingSignals({
    required this.id,
    required this.authorKey,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.saves,
    required this.views,
    required this.rating,
    required this.isVideo,
    required this.isFollowing,
    required this.isVerified,
    required this.inContest,
    this.publishedAt,
    this.postedAtLabel = '',
  });

  final String id;
  final String authorKey;
  final int likes;
  final int comments;
  final int shares;
  final int saves;
  final int views;
  final double rating;
  final bool isVideo;
  final bool isFollowing;
  final bool isVerified;
  final bool inContest;
  final DateTime? publishedAt;
  final String postedAtLabel;
}

class TrendingRanker {
  const TrendingRanker._();

  static const double _gravity = 1.58;
  static const double _freshHalfLifeHours = 30;
  static const double _viralWindowHours = 24 * 7;

  static TrendingSignals fromPost(HomePostModel post) {
    return TrendingSignals(
      id: post.id,
      authorKey: _authorKey(post.profileUsername, post.username),
      likes: parseCount(post.likes),
      comments: parseCount(post.comments),
      shares: post.shareCount,
      saves: post.saveCount,
      views: post.viewCount,
      rating: post.displayRating,
      isVideo: post.mediaType == HomeMediaType.video,
      isFollowing: post.isFollowingAuthor,
      isVerified: post.isVerifiedBadge,
      inContest: post.isInContest,
      publishedAt: post.publishedAt,
      postedAtLabel: post.postedAt,
    );
  }

  static TrendingSignals fromReel(ReelItemModel reel) {
    return TrendingSignals(
      id: reel.id,
      authorKey: _authorKey(reel.profileUsername, reel.handle),
      likes: reel.likeCount,
      comments: reel.commentCount,
      shares: reel.shareCount,
      saves: reel.saveCount,
      views: reel.viewCount,
      rating: double.tryParse(reel.rating) ?? 0,
      isVideo: reel.mediaType == ReelMediaType.video,
      isFollowing: reel.isFollowingAuthor,
      isVerified: reel.isVerifiedBadge,
      inContest: reel.ratingEnabled,
      publishedAt: reel.publishedAt,
    );
  }

  /// Weighted quality. Views are cheap (autoplay). Comments / shares / saves
  /// are the actions Instagram and TikTok treat as real intent.
  static double intentScore(TrendingSignals signal) {
    return signal.comments * 34 +
        signal.shares * 46 +
        signal.saves * 24 +
        signal.likes * 8 +
        signal.views * 0.035 +
        (signal.rating > 0 ? signal.rating * 7 : 0);
  }

  static double ageHours(TrendingSignals signal) {
    if (signal.publishedAt != null) {
      final hours =
          DateTime.now().difference(signal.publishedAt!).inMinutes / 60.0;
      return hours.clamp(0.15, 24.0 * 60);
    }
    return _ageFromLabel(signal.postedAtLabel);
  }

  /// Hot score: Reddit/HN gravity + Wilson conversion + freshness envelope.
  static double score(TrendingSignals signal) {
    final age = ageHours(signal);
    final intent = intentScore(signal);
    if (intent <= 0 && signal.likes <= 0 && signal.views <= 0) {
      return 0;
    }

    final gravity = 1 / math.pow(age + 2, _gravity);
    final freshness = math.exp(
      -math.max(0, age - 3) / _freshHalfLifeHours,
    );
    final quality = _wilsonConversion(signal);
    final video = _videoMultiplier(signal);
    final author = _authorMultiplier(signal);
    final emerging = age < 6 && quality >= 0.08 ? 1.12 : 1.0;

    return (intent + 12) *
        gravity *
        (0.52 + 0.48 * freshness) *
        (1 + 2.4 * quality) *
        video *
        author *
        emerging;
  }

  static List<HomePostModel> rankPosts(
    Iterable<HomePostModel> source, {
    bool exploreLayout = false,
  }) {
    final items = source.toList(growable: false);
    return _rank(
      items,
      idOf: (item) => item.id,
      authorOf: (item) => _authorKey(item.profileUsername, item.username),
      isVideoOf: (item) => item.mediaType == HomeMediaType.video,
      signalOf: fromPost,
      exploreLayout: exploreLayout,
    );
  }

  static List<ReelItemModel> rankReels(Iterable<ReelItemModel> source) {
    final items = source.toList(growable: false);
    return _rank(
      items,
      idOf: (item) => item.id,
      authorOf: (item) => _authorKey(item.profileUsername, item.handle),
      isVideoOf: (item) => item.mediaType == ReelMediaType.video,
      signalOf: fromReel,
      exploreLayout: false,
    );
  }

  /// Keeps viral / trending reels near the front, but does not always
  /// start on the same #1 item. Higher score = more likely to appear first.
  static List<ReelItemModel> shuffleTrendingStart(
    Iterable<ReelItemModel> source,
  ) {
    final ranked = rankReels(source);
    if (ranked.length <= 1) {
      return ranked;
    }

    final random = math.Random();
    final keyed = <({ReelItemModel reel, double key})>[
      for (final reel in ranked)
        (
          reel: reel,
          key: -math.log(random.nextDouble().clamp(1e-9, 1.0)) /
              math.max(score(fromReel(reel)), 0.4),
        ),
    ]..sort((a, b) => a.key.compareTo(b.key));

    return [for (final entry in keyed) entry.reel];
  }

  static Set<String> trendingIds(Iterable<HomePostModel> pool) {
    return _trendingIds(pool.map(fromPost));
  }

  static bool isViral(HomePostModel post, {Iterable<HomePostModel>? pool}) {
    if (pool != null) {
      return trendingIds(pool).contains(post.id);
    }
    final signal = fromPost(post);
    return _meetsViralFloor(signal) && score(signal) >= 18;
  }

  static int parseCount(String raw) {
    final value = raw.trim().toLowerCase().replaceAll(',', '');
    if (value.isEmpty) {
      return 0;
    }
    if (value.endsWith('k')) {
      return ((double.tryParse(value.substring(0, value.length - 1)) ?? 0) *
              1000)
          .round();
    }
    if (value.endsWith('m')) {
      return ((double.tryParse(value.substring(0, value.length - 1)) ?? 0) *
              1000000)
          .round();
    }
    return int.tryParse(value) ?? 0;
  }

  static Set<String> _trendingIds(Iterable<TrendingSignals> pool) {
    final items = [
      for (final item in pool)
        if (item.id.trim().isNotEmpty) item,
    ];
    if (items.isEmpty) {
      return const <String>{};
    }

    final scores = <String, double>{
      for (final item in items) item.id: score(item),
    };
    final peer = scores.values.where((value) => value > 0).toList()..sort();
    if (peer.isEmpty) {
      return const <String>{};
    }

    final median = peer[peer.length ~/ 2];
    final p80 = peer[(peer.length * 0.80).floor().clamp(0, peer.length - 1)];

    final eligible = items.where((item) {
      if (!_meetsViralFloor(item)) {
        return false;
      }
      final value = scores[item.id] ?? 0;
      if (value < p80 && (median <= 0 || value < median * 1.55)) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => (scores[b.id] ?? 0).compareTo(scores[a.id] ?? 0));

    final maxBadges = items.length < 8
        ? 1
        : (items.length * 0.12).floor().clamp(1, 4);

    final ids = <String>{};
    final authors = <String>{};
    for (final item in eligible) {
      if (ids.length >= maxBadges) {
        break;
      }
      if (item.authorKey.isNotEmpty && !authors.add(item.authorKey)) {
        continue;
      }
      ids.add(item.id);
    }
    return ids;
  }

  static bool _meetsViralFloor(TrendingSignals signal) {
    if (ageHours(signal) > _viralWindowHours) {
      return false;
    }

    final quality = _wilsonConversion(signal);
    if (signal.likes < 6 && signal.comments < 2 && signal.saves < 2) {
      return false;
    }
    if (quality < 0.035 && signal.likes < 18) {
      return false;
    }

    var signals = 0;
    if (signal.likes >= (signal.isVideo ? 12 : 16)) {
      signals++;
    }
    if (signal.comments >= 3) {
      signals++;
    }
    if (signal.saves >= 4) {
      signals++;
    }
    if (signal.shares >= 2) {
      signals++;
    }
    if (signal.isVideo && signal.views >= 180 && quality >= 0.05) {
      signals++;
    }
    if (quality >= 0.09) {
      signals++;
    }
    return signals >= 2;
  }

  static List<T> _rank<T>(
    List<T> items, {
    required String Function(T item) idOf,
    required String Function(T item) authorOf,
    required bool Function(T item) isVideoOf,
    required TrendingSignals Function(T item) signalOf,
    required bool exploreLayout,
  }) {
    if (items.length <= 1) {
      return items;
    }

    final signals = <String, TrendingSignals>{
      for (final item in items) idOf(item): signalOf(item),
    };
    final scores = <String, double>{
      for (final entry in signals.entries) entry.key: score(entry.value),
    };
    if (scores.values.every((value) => value <= 0)) {
      return items;
    }

    final sorted = [...items]
      ..sort((a, b) {
        final delta = (scores[idOf(b)] ?? 0).compareTo(scores[idOf(a)] ?? 0);
        if (delta != 0) {
          return delta;
        }
        return ageHours(signals[idOf(a)]!).compareTo(ageHours(signals[idOf(b)]!));
      });

    if (!exploreLayout) {
      return _spreadAuthors(sorted, authorOf);
    }

    final viral = _trendingIds(signals.values);
    final heroes = <T>[];
    final rest = <T>[];
    for (final item in sorted) {
      if (viral.contains(idOf(item))) {
        heroes.add(item);
      } else {
        rest.add(item);
      }
    }

    final photos = rest.where((item) => !isVideoOf(item)).toList();
    final videos = rest.where(isVideoOf).toList();
    final mixed = _mixMedia(photos, videos);
    return _interleaveHeroes(heroes, mixed, authorOf);
  }

  static List<T> _spreadAuthors<T>(
    List<T> sorted,
    String Function(T item) authorOf,
  ) {
    final placed = <T>[];
    final waiting = <T>[];
    for (final item in sorted) {
      final author = authorOf(item);
      final recent = placed.length >= 2
          ? placed.sublist(placed.length - 2)
          : placed;
      final stacked = author.isNotEmpty &&
          recent.any((other) => authorOf(other) == author);
      if (stacked) {
        waiting.add(item);
        continue;
      }
      placed.add(item);
      if (waiting.isNotEmpty) {
        placed.add(waiting.removeAt(0));
      }
    }
    placed.addAll(waiting);
    return placed;
  }

  static List<T> _mixMedia<T>(List<T> photos, List<T> videos) {
    final mixed = <T>[];
    var photoIndex = 0;
    var videoIndex = 0;
    var slot = 0;
    while (photoIndex < photos.length || videoIndex < videos.length) {
      final preferVideo = slot % 3 == 2 && videoIndex < videos.length;
      if (preferVideo || photoIndex >= photos.length) {
        mixed.add(videos[videoIndex++]);
      } else {
        mixed.add(photos[photoIndex++]);
      }
      slot++;
    }
    return mixed;
  }

  static List<T> _interleaveHeroes<T>(
    List<T> heroes,
    List<T> rest,
    String Function(T item) authorOf,
  ) {
    if (heroes.isEmpty) {
      return _spreadAuthors(rest, authorOf);
    }

    final out = <T>[];
    var heroIndex = 0;
    var restIndex = 0;
    out.add(heroes[heroIndex++]);

    var sinceHero = 0;
    while (heroIndex < heroes.length || restIndex < rest.length) {
      final shouldHero = heroIndex < heroes.length &&
          (restIndex >= rest.length || sinceHero >= 5);
      if (shouldHero) {
        out.add(heroes[heroIndex++]);
        sinceHero = 0;
        continue;
      }
      out.add(rest[restIndex++]);
      sinceHero++;
    }
    return _spreadAuthors(out, authorOf);
  }

  /// Wilson lower bound of "meaningful actions / impressions".
  /// Stops a 3-like lucky spike from beating a real breakout.
  static double _wilsonConversion(TrendingSignals signal) {
    final successes = signal.likes +
        signal.comments * 3 +
        signal.shares * 4 +
        signal.saves * 3;
    final trials = math.max(
      signal.views,
      math.max(successes, 10),
    );
    if (successes <= 0) {
      return 0;
    }
    return _wilsonLowerBound(successes, trials);
  }

  static double _wilsonLowerBound(num positives, num trials, {double z = 1.64}) {
    if (trials <= 0) {
      return 0;
    }
    final n = trials.toDouble();
    final p = (positives / n).clamp(0.0, 1.0);
    final z2 = z * z;
    final denom = 1 + z2 / n;
    final center = p + z2 / (2 * n);
    final margin = z * math.sqrt((p * (1 - p) + z2 / (4 * n)) / n);
    return ((center - margin) / denom).clamp(0.0, 1.0);
  }

  static double _videoMultiplier(TrendingSignals signal) {
    if (!signal.isVideo) {
      return 1;
    }
    final impressions = math.max(signal.views, signal.likes * 6);
    if (impressions <= 0) {
      return 1.04;
    }
    final likeRate = signal.likes / impressions;
    if (likeRate >= 0.05) {
      return 1.14;
    }
    if (likeRate >= 0.025) {
      return 1.08;
    }
    if (signal.views >= 400 && likeRate < 0.008) {
      return 0.84;
    }
    return 1.03;
  }

  static double _authorMultiplier(TrendingSignals signal) {
    var multiplier = 1.0;
    if (signal.isFollowing) {
      multiplier *= 1.07;
    }
    if (signal.isVerified) {
      multiplier *= 1.03;
    }
    if (signal.inContest) {
      multiplier *= 1.05;
    }
    return multiplier;
  }

  static String _authorKey(String primary, String fallback) {
    final raw = primary.trim().isNotEmpty ? primary : fallback;
    return raw.replaceFirst(RegExp(r'^@+'), '').trim().toLowerCase();
  }

  static double _ageFromLabel(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty || value == 'just now' || value == 'now') {
      return 0.3;
    }
    final minutes = RegExp(r'^(\d+)\s*m').firstMatch(value);
    if (minutes != null) {
      return (int.parse(minutes.group(1)!) / 60).clamp(0.15, 24.0 * 60);
    }
    final hours = RegExp(r'^(\d+)\s*h').firstMatch(value);
    if (hours != null) {
      return double.parse(hours.group(1)!);
    }
    final days = RegExp(r'^(\d+)\s*d').firstMatch(value);
    if (days != null) {
      return double.parse(days.group(1)!) * 24;
    }
    final weeks = RegExp(r'^(\d+)\s*w').firstMatch(value);
    if (weeks != null) {
      return double.parse(weeks.group(1)!) * 24 * 7;
    }
    if (value.contains('yesterday')) {
      return 24;
    }
    if (RegExp(r'^\d+\s*month').hasMatch(value) || value.contains('year')) {
      return 24 * 45;
    }
    // Clock labels ("4:30 PM") are used for posts younger than 12h.
    if (RegExp(r'\d{1,2}:\d{2}').hasMatch(value)) {
      return 2;
    }
    return 16;
  }
}
