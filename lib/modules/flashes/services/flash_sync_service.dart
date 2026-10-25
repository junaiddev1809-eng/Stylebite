import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/media/media_type_resolver.dart';
import '../../../core/media/picked_media.dart';
import '../../../core/utils/api_helper.dart';
import '../flash_marker.dart';
import '../models/flash_model.dart';

class FlashSyncService {
  static Future<List<FlashItem>> fetchFlashes() async {
    try {
      final response = await ApiHelper.fetchDataWithAuthorization('flashes');
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
      final items = <FlashItem>[];
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
          final item = _fromPayload(
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

  static Future<FlashItem?> publish({
    required FlashItem local,
    required PickedMedia media,
  }) async {
    final caption = FlashMarker.encodeCaption(local.caption);
    final fields = <String, String>{
      'post_type': local.isFood ? 'food' : 'outfit',
      'caption': caption,
      'tags': FlashMarker.encodeTags(local.caption).join(','),
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

  static Future<FlashItem?> republishFile({
    required FlashItem local,
    required String filePath,
  }) async {
    if (filePath.trim().isEmpty) {
      return null;
    }
    return publish(
      local: local,
      media: PickedMedia(
        file: File(filePath),
        type: AppMediaType.image,
      ),
    );
  }

  static Future<bool> deleteRemote(String remoteId) async {
    final id = remoteId.trim();
    if (id.isEmpty) {
      return false;
    }
    try {
      final response = await ApiHelper.deleteRequestWithAuthorization(
        'posts/$id',
      );
      if (response == null) {
        return false;
      }
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  static FlashItem? _fromPayload(
    Map<String, dynamic> raw, {
    required String username,
    required String avatarUrl,
  }) {
    final mediaUrl =
        (raw['media_url'] ?? raw['file_url'] ?? '').toString().trim();
    if (mediaUrl.isEmpty) {
      return null;
    }
    final created = DateTime.tryParse((raw['posted_at'] ?? '').toString()) ??
        DateTime.now();
    final expires = DateTime.tryParse((raw['expires_at'] ?? '').toString());
    if (expires != null && DateTime.now().isAfter(expires)) {
      return null;
    }
    if (expires == null &&
        DateTime.now().isAfter(created.add(FlashItem.lifetime))) {
      return null;
    }
    final id = (raw['id'] ?? '').toString().trim();
    if (id.isEmpty) {
      return null;
    }
    return FlashItem(
      id: 'f$id',
      remoteId: id,
      username: username,
      avatarUrl: avatarUrl,
      mediaPath: '',
      mediaUrl: mediaUrl,
      createdAt: created,
      caption: FlashMarker.displayCaption((raw['caption'] ?? '').toString()),
      kind: flashKindFrom(raw['post_type'] ?? raw['feed_type']),
    );
  }

  static String _firstMediaUrl(Map<String, dynamic> post) {
    final media = post['media'];
    if (media is List) {
      for (final item in media.whereType<Map>()) {
        final url = (item['optimized_url'] ??
                item['file_url'] ??
                item['url'] ??
                '')
            .toString()
            .trim();
        if (url.isNotEmpty) {
          return url;
        }
      }
    }
    for (final key in <String>[
      'file_url',
      'media_url',
      'optimized_url',
      'url',
      'image_url',
    ]) {
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
