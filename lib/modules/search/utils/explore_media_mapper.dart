import '../../../core/ranking/trending_ranker.dart';
import '../../home/models/home_post_model.dart';
import '../../profile/models/profile_model.dart';
import '../../reel/models/reel_item_model.dart';
import '../../story/story_marker.dart';

class ExploreMediaMapper {
  const ExploreMediaMapper._();

  static String coverUrl(HomePostModel post) {
    final thumb = post.thumbnailUrl?.trim() ?? '';
    if (thumb.isNotEmpty) {
      return thumb;
    }
    if (post.imageUrl.trim().isNotEmpty) {
      return post.imageUrl;
    }
    for (final media in post.media) {
      if (media.previewUrl.trim().isNotEmpty) {
        return media.previewUrl;
      }
    }
    return post.primaryMediaUrl;
  }

  static bool isVideo(HomePostModel post) =>
      post.mediaType == HomeMediaType.video;

  static String restaurantLabel(HomePostModel post) {
    final named = post.restaurant.trim();
    if (named.isNotEmpty) {
      return named;
    }
    if (!post.isFoodPost) {
      return '';
    }
    final location = post.location.trim();
    if (location.isEmpty) {
      return '';
    }
    final city = post.authorCity.trim().toLowerCase();
    if (city.isNotEmpty && location.toLowerCase() == city) {
      return '';
    }
    return location;
  }

  static HomePostModel fromReel(ReelItemModel reel) => reel.toHomePost();

  static HomePostModel fromProfilePost({
    required ProfilePostModel post,
    required ProfileUserModel user,
  }) {
    final authorName = user.displayName.trim().isNotEmpty
        ? user.displayName
        : (user.fullName.trim().isNotEmpty ? user.fullName : user.username);
    return post.toHomePostModel(
      username: user.username,
      avatarUrl: user.avatarUrl,
      profileUsername: user.username,
      authorName: authorName,
    );
  }

  static List<HomePostModel> mix({
    required List<HomePostModel> posts,
    required List<HomePostModel> reels,
  }) {
    final videos = <HomePostModel>[];
    final photos = <HomePostModel>[];
    final seen = <String>{};

    void take(HomePostModel item) {
      if (StoryMarker.isStory(tags: item.tags, caption: item.caption)) {
        return;
      }
      final id = item.id.trim();
      if (id.isEmpty || !seen.add(id)) {
        return;
      }
      if (item.mediaType == HomeMediaType.video) {
        videos.add(item);
      } else {
        photos.add(item);
      }
    }

    for (final reel in reels) {
      take(reel);
    }
    for (final post in posts) {
      take(post);
    }

    final mixed = <HomePostModel>[];
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

  static int parseCount(String raw) => TrendingRanker.parseCount(raw);

  static int engagementScore(HomePostModel post) =>
      TrendingRanker.intentScore(TrendingRanker.fromPost(post)).round();

  static double trendingScore(HomePostModel post) =>
      TrendingRanker.score(TrendingRanker.fromPost(post));

  static Set<String> trendingIds(Iterable<HomePostModel> pool) =>
      TrendingRanker.trendingIds(pool);

  static bool isViral(
    HomePostModel post, {
    Iterable<HomePostModel>? pool,
  }) =>
      TrendingRanker.isViral(post, pool: pool);

  static List<HomePostModel> rankForExplore({
    required List<HomePostModel> posts,
    required List<HomePostModel> reels,
  }) {
    final photos = <HomePostModel>[];
    final videos = <HomePostModel>[];
    for (final item in dedupe([...posts, ...reels])) {
      if (isVideo(item)) {
        videos.add(item);
      } else {
        photos.add(item);
      }
    }
    if (photos.isEmpty && videos.isEmpty) {
      return const <HomePostModel>[];
    }
    final rankedPosts = TrendingRanker.rankPosts(photos);
    final rankedReels = TrendingRanker.rankPosts(videos);
    final mixed = <HomePostModel>[];
    var postIndex = 0;
    var reelIndex = 0;
    while (postIndex < rankedPosts.length || reelIndex < rankedReels.length) {
      if (postIndex < rankedPosts.length) {
        mixed.add(rankedPosts[postIndex++]);
      }
      if (reelIndex < rankedReels.length) {
        mixed.add(rankedReels[reelIndex++]);
      }
    }
    return mixed;
  }

  static List<HomePostModel> dedupe(Iterable<HomePostModel> source) {
    final seen = <String>{};
    final unique = <HomePostModel>[];
    for (final item in source) {
      if (StoryMarker.isStory(tags: item.tags, caption: item.caption)) {
        continue;
      }
      final id = item.id.trim();
      if (id.isEmpty || !seen.add(id)) {
        continue;
      }
      unique.add(item);
    }
    return unique;
  }

  static bool matchesQuery(HomePostModel post, String rawQuery) {
    final needle = rawQuery.trim().replaceFirst(RegExp(r'^[#@]+'), '').toLowerCase();
    if (needle.isEmpty) {
      return false;
    }
    bool contains(String value) => value.toLowerCase().contains(needle);
    if (contains(post.username) ||
        contains(post.profileUsername) ||
        contains(post.authorName) ||
        contains(post.caption) ||
        contains(post.location) ||
        contains(post.dishName) ||
        contains(post.restaurant)) {
      return true;
    }
    if (post.containsHashtag(needle)) {
      return true;
    }
    for (final tag in post.tags) {
      if (contains(tag)) {
        return true;
      }
    }
    return false;
  }
}
