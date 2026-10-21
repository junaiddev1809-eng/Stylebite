import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/media/media_type_resolver.dart';
import '../../../core/media/picked_media.dart';
import '../../../core/utils/api_helper.dart';
import '../../../core/utils/app_time_formatter.dart';
import '../../home/models/home_post_model.dart';
import '../../profile/models/follower_model.dart';
import '../../profile/models/profile_model.dart';
import '../models/story_model.dart';
import '../story_marker.dart';

class StorySyncService {
  static const _maxFollowingPages = 3;
  static const _maxPeerOverviews = 20;
  static const _overviewBatch = 5;

  static Future<List<StoryPeer>> fetchFollowingPeers(String username) async {
    final me = username.trim().replaceFirst('@', '');
    if (me.isEmpty) {
      return const [];
    }

    final peers = <String, StoryPeer>{};
    var page = 1;
    var hasMore = true;
    while (hasMore && page <= _maxFollowingPages) {
      final response = await ApiHelper.fetchDataWithAuthorization(
        'profiles/${Uri.encodeComponent(me)}/following?page=$page',
      );
      if (response == null) {
        break;
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map) {
        break;
      }
      final parsed = FollowerListResponseModel.fromJson(
        payload.cast<String, dynamic>(),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        break;
      }
      for (final user in parsed.data) {
        final name = user.username.trim().replaceFirst('@', '');
        if (name.isEmpty || user.isSelf || name.toLowerCase() == me.toLowerCase()) {
          continue;
        }
        peers[name.toLowerCase()] = StoryPeer(
          username: name,
          avatarUrl: user.avatarUrl,
        );
      }
      hasMore = parsed.pagination.hasMorePages;
      page += 1;
    }
    return peers.values.toList(growable: false);
  }

  static Future<List<StoryItem>> fetchStories() async {
    try {
      final response = await ApiHelper.fetchDataWithAuthorization('stories');
      if (response == null ||
          response.statusCode < 200 ||
          response.statusCode >= 300) {
        return const [];
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map) {
        return const [];
      }
      final data = payload['data'];
      if (data is! List) {
        return const [];
      }
      final items = <StoryItem>[];
      for (final group in data.whereType<Map>()) {
        final map = _asMap(group);
        final username = (map['username'] ?? '')
            .toString()
            .trim()
            .replaceFirst('@', '');
        final avatarUrl = (map['avatar_url'] ?? '').toString().trim();
        final rawItems = map['items'];
        if (username.isEmpty || rawItems is! List) {
          continue;
        }
        for (final raw in rawItems.whereType<Map>()) {
          final item = _fromStoryPayload(
            _asMap(raw),
            username: username,
            avatarUrl: avatarUrl,
          );
          if (item != null) {
            items.add(item);
          }
        }
      }
      return items;
    } catch (_) {
      return const [];
    }
  }

  static Future<List<StoryItem>> fetchFeedStories() async {
    try {
      final response = await ApiHelper.fetchDataWithAuthorization(
        'feed/home?type=outfit&discover_type=for_you&page=1&per_page=30',
      );
      if (response == null ||
          response.statusCode < 200 ||
          response.statusCode >= 300) {
        return const [];
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map) {
        return const [];
      }
      final parsed = HomeFeedResponse.fromJson(payload.cast<String, dynamic>());
      return [
        for (final post in parsed.feed)
          if (StoryMarker.isStory(tags: post.tags, caption: post.caption))
            if (_fromHomePost(post) case final item?) item,
      ];
    } catch (_) {
      return const [];
    }
  }

  static Future<List<StoryItem>> fetchUserStories({
    required String username,
    String avatarUrl = '',
  }) async {
    final name = username.trim().replaceFirst('@', '');
    if (name.isEmpty) {
      return const [];
    }
    try {
      final uri = Uri(
        path: 'profiles/${Uri.encodeComponent(name)}/overview',
        queryParameters: const {'per_page': '12', 'outfit_page': '1'},
      );
      final response = await ApiHelper.fetchDataWithAuthorization(uri.toString());
      if (response == null ||
          response.statusCode < 200 ||
          response.statusCode >= 300) {
        return const [];
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map) {
        return const [];
      }
      final overview = ProfileOverviewResponseModel.fromMap(
        payload.cast<String, dynamic>(),
      ).overview;
      final avatar = avatarUrl.trim().isNotEmpty
          ? avatarUrl
          : overview.user.avatarUrl;
      return [
        for (final post in overview.outfitPosts)
          if (_fromProfilePost(
                post: post,
                username: overview.user.username.isNotEmpty
                    ? overview.user.username
                    : name,
                avatarUrl: avatar,
              )
              case final item?)
            item,
      ];
    } catch (_) {
      return const [];
    }
  }

  static Future<List<StoryItem>> fetchPeerStories(List<StoryPeer> peers) async {
    if (peers.isEmpty) {
      return const [];
    }
    final limited = peers.take(_maxPeerOverviews).toList(growable: false);
    final items = <StoryItem>[];
    for (var i = 0; i < limited.length; i += _overviewBatch) {
      final end = (i + _overviewBatch).clamp(0, limited.length);
      final batch = limited.sublist(i, end);
      final results = await Future.wait(
        batch.map(
          (peer) => fetchUserStories(
            username: peer.username,
            avatarUrl: peer.avatarUrl,
          ),
        ),
      );
      for (final list in results) {
        items.addAll(list);
      }
    }
    return items;
  }

  static Future<StoryItem?> publish({
    required StoryItem local,
    required PickedMedia media,
  }) async {
    final caption = StoryMarker.encodeCaption(local.caption);
    final fields = <String, String>{
      'post_type': local.isFood ? 'food' : 'outfit',
      'caption': caption,
      'tags': StoryMarker.encodeTags(local.caption).join(','),
      'visibility': 'public',
      'rating_enabled': '0',
    };

    final response = await ApiHelper.multipartRequestWithAuthorization(
      'posts',
      fields: fields,
      fileFieldName: 'file',
      filePath: media.path,
    );
    if (response == null) {
      return null;
    }
    final materialized = await http.Response.fromStream(response);
    if (materialized.statusCode < 200 || materialized.statusCode >= 300) {
      return null;
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(materialized.body);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) {
      return null;
    }
    final payload = decoded.cast<String, dynamic>();
    if (payload.containsKey('status_code') &&
        payload['status_code'] != 1 &&
        payload['status_code'] != true) {
      return null;
    }
    final post = _asMap(
      payload['data'] ?? payload['post'] ?? payload['item'] ?? payload,
    );
    final remoteId = (post['id'] ?? payload['id'] ?? '').toString();
    if (remoteId.isEmpty || remoteId == 'null') {
      return null;
    }
    final mediaUrl = _firstMediaUrl(post);
    return local.copyWith(
      remoteId: remoteId,
      mediaUrl: mediaUrl.isNotEmpty ? mediaUrl : local.mediaUrl,
    );
  }

  static Future<StoryItem?> republishFile({
    required StoryItem local,
    required String filePath,
  }) async {
    if (filePath.trim().isEmpty) {
      return null;
    }
    return publish(
      local: local,
      media: PickedMedia(
        file: File(filePath),
        type: local.isVideo ? AppMediaType.video : AppMediaType.image,
      ),
    );
  }

  static StoryItem? _fromStoryPayload(
    Map<String, dynamic> raw, {
    required String username,
    required String avatarUrl,
  }) {
    final mediaUrl = (raw['media_url'] ?? raw['file_url'] ?? '').toString().trim();
    if (mediaUrl.isEmpty) {
      return null;
    }
    final created = DateTime.tryParse((raw['posted_at'] ?? '').toString()) ??
        DateTime.now();
    final expires = DateTime.tryParse((raw['expires_at'] ?? '').toString());
    if (expires != null && DateTime.now().isAfter(expires)) {
      return null;
    }
    if (expires == null && DateTime.now().isAfter(created.add(StoryItem.lifetime))) {
      return null;
    }
    final id = (raw['id'] ?? '').toString().trim();
    if (id.isEmpty) {
      return null;
    }
    return StoryItem(
      id: 'p$id',
      remoteId: id,
      username: username,
      avatarUrl: avatarUrl,
      mediaPath: '',
      mediaUrl: mediaUrl,
      createdAt: created,
      caption: StoryMarker.displayCaption((raw['caption'] ?? '').toString()),
      isVideo: (raw['media_type'] ?? '').toString().toLowerCase() == 'video',
      kind: storyKindFrom(raw['post_type'] ?? raw['feed_type']),
    );
  }

  static StoryItem? _fromHomePost(HomePostModel post) {
    final created = post.publishedAt ?? DateTime.now();
    if (DateTime.now().isAfter(created.add(StoryItem.lifetime))) {
      return null;
    }
    final mediaUrl = post.primaryMediaUrl.trim();
    if (mediaUrl.isEmpty) {
      return null;
    }
    final username = post.profileUsername.trim().isNotEmpty
        ? post.profileUsername
        : post.username.replaceFirst('@', '');
    return StoryItem(
      id: 'p${post.id}',
      remoteId: post.id,
      username: username.replaceFirst('@', ''),
      avatarUrl: post.avatarUrl,
      mediaPath: '',
      mediaUrl: mediaUrl,
      createdAt: created,
      caption: StoryMarker.displayCaption(post.caption),
      isVideo: post.mediaType == HomeMediaType.video,
      kind: post.isFoodPost || post.feedType == HomeFeedType.bite
          ? StoryKind.food
          : StoryKind.outfit,
    );
  }

  static StoryItem? _fromProfilePost({
    required ProfilePostModel post,
    required String username,
    required String avatarUrl,
  }) {
    if (!StoryMarker.isStory(tags: post.tags, caption: post.caption)) {
      return null;
    }
    final created = AppTimeFormatter.parse(post.createdAt) ?? DateTime.now();
    if (DateTime.now().isAfter(created.add(StoryItem.lifetime))) {
      return null;
    }
    var isVideo = post.mediaKind.trim().toLowerCase() == 'video';
    var mediaUrl = '';
    for (final item in post.media) {
      if (item.fileUrl.trim().isEmpty) {
        continue;
      }
      mediaUrl = item.fileUrl.trim();
      if (item.mediaType.trim().toLowerCase() == 'video') {
        isVideo = true;
      }
      break;
    }
    if (mediaUrl.isEmpty) {
      return null;
    }
    return StoryItem(
      id: 'p${post.id}',
      remoteId: post.id.toString(),
      username: username.replaceFirst('@', ''),
      avatarUrl: avatarUrl,
      mediaPath: '',
      mediaUrl: mediaUrl,
      createdAt: created,
      caption: StoryMarker.displayCaption(post.caption),
      isVideo: isVideo,
      kind: storyKindFrom(post.postType),
    );
  }

  static String _firstMediaUrl(Map<String, dynamic> post) {
    final media = post['media'];
    if (media is List) {
      for (final item in media.whereType<Map>()) {
        final url = (item['file_url'] ?? item['url'] ?? '').toString().trim();
        if (url.isNotEmpty) {
          return url;
        }
      }
    }
    for (final key in <String>['file_url', 'media_url', 'url', 'image_url']) {
      final url = (post[key] ?? '').toString().trim();
      if (url.isNotEmpty) {
        return url;
      }
    }
    return '';
  }

  static Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

}
