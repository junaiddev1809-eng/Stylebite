import 'dart:convert';
import 'dart:developer';

import '../../../core/utils/app_time_formatter.dart';
import '../../../core/utils/verified_flag.dart';
import '../../post/utils/in_app_share.dart';

enum NotificationKind {
  vibeRequest,
  like,
  contest,
  comment,
  message,
  support,
  other,
}

class NotificationItemModel {
  const NotificationItemModel({
    required this.id,
    required this.kind,
    required this.type,
    required this.username,
    required this.title,
    required this.timeAgo,
    required this.message,
    required this.avatar,
    required this.actionUrl,
    required this.entityType,
    required this.entityId,
    required this.createdAt,
    required this.isVerifiedBadge,
    this.actorUsername = '',
    this.remoteId = '',
    this.hasActor = true,
    this.thumbnail,
    this.primaryActionText,
    this.secondaryActionText,
    this.unread = true,
    this.readAt,
    this.deliveryStatus,
  });

  final int id;
  // Original backend id (UUID or int). Network calls should use this when
  // present so hashed integer ids are not sent to `/notifications/{id}`.
  final String remoteId;
  final NotificationKind kind;
  final String type;
  final String username;
  final String actorUsername;
  final String title;
  final String timeAgo;
  final String message;
  final String avatar;
  final String actionUrl;
  final String entityType;
  final int entityId;
  final String createdAt;
  final bool isVerifiedBadge;
  // False when the backend sent no actor info — a system-generated
  // notification (e.g. a streak reminder) rather than a user action.
  final bool hasActor;
  final String? thumbnail;
  final String? primaryActionText;
  final String? secondaryActionText;
  final bool unread;
  final String? readAt;
  final String? deliveryStatus;

  String get profileHandle {
    final fromActor = actorUsername.trim().replaceFirst(RegExp(r'^@'), '');
    if (fromActor.isNotEmpty) {
      return fromActor;
    }
    if (hasActor) {
      final fallback = username.trim().replaceFirst(RegExp(r'^@'), '');
      if (fallback.isNotEmpty && !fallback.contains(' ')) {
        return fallback;
      }
    }
    return '';
  }

  // Mirrors the actual dispatch rules in
  // NotificationsScreen._handleActionTap — whether tapping the primary
  // "Open" button would go anywhere at all. entity_id/entity_type alone
  // are enough for message/contest/support even when action_url is null,
  // so this can't be a blind action_url-is-empty check without hiding
  // buttons that actually work.
  bool get hasOpenAction {
    switch (kind) {
      case NotificationKind.like:
        return actionUrl.trim().isNotEmpty || entityId > 0;
      case NotificationKind.comment:
        return actionUrl.trim().isNotEmpty ||
            (entityType == 'post' && entityId > 0);
      case NotificationKind.contest:
        return true;
      case NotificationKind.message:
        return true;
      case NotificationKind.support:
        return entityType == 'support_ticket' && entityId > 0;
      case NotificationKind.vibeRequest:
        return false;
      case NotificationKind.other:
        return actionUrl.trim().isNotEmpty;
    }
  }

  factory NotificationItemModel.fromJson(Map<String, dynamic> json) {
    final source = _unwrapPayload(json);
    final actor = _asMap(source['actor']) ??
        _asMap(source['user']) ??
        _asMap(source['from']) ??
        _asMap(source['liker']) ??
        _asMap(source['liked_by']) ??
        _asMap(source['sender']) ??
        <String, dynamic>{};
    final type = _readType(source);
    final hasActor =
        _nullableString(actor['display_name']) != null ||
        _nullableString(actor['full_name']) != null ||
        _nullableString(actor['username']) != null ||
        _nullableString(source['actor_username']) != null ||
        _nullableString(source['liker_username']) != null;
    final username = hasActor
        ? _resolveUsername(actor, type, source)
        : 'StyleBite';
    final actorUsername = hasActor ? _resolveActorUsername(actor, source) : '';
    final kind = _kindFromJson(source, type);
    final rawId = source['id'] ?? json['id'];

    return NotificationItemModel(
      id: _readId(rawId),
      remoteId: (rawId ?? '').toString(),
      kind: kind,
      type: type,
      username: username,
      actorUsername: actorUsername,
      title: (source['title'] ?? json['title'] ?? '').toString(),
      timeAgo: AppTimeFormatter.formatCommentTime(
        (source['created_at'] ?? json['created_at'] ?? '').toString(),
      ),
      message: _resolveMessage(source, kind),
      avatar: (actor['avatar_url'] ??
              source['actor_avatar_url'] ??
              source['liker_avatar_url'] ??
              source['image_url'] ??
              json['image_url'] ??
              '')
          .toString(),
      actionUrl: (source['action_url'] ??
              source['click_action'] ??
              json['action_url'] ??
              '')
          .toString(),
      entityType: (source['entity_type'] ?? json['entity_type'] ?? '')
          .toString(),
      entityId: _readInt(
        source['entity_id'] ??
            json['entity_id'] ??
            source['post_id'] ??
            json['post_id'] ??
            source['reel_id'] ??
            json['reel_id'] ??
            source['feed_post_id'],
      ),
      createdAt: (source['created_at'] ?? json['created_at'] ?? '').toString(),
      isVerifiedBadge: VerifiedBadgeCache.resolve(
        hasActor ? username : '',
        parseVerifiedFlag(source) || parseVerifiedFlag(actor),
      ),
      hasActor: hasActor,
      thumbnail: _nullableString(source['image_url'] ?? json['image_url']),
      primaryActionText: _primaryActionLabel(kind),
      secondaryActionText: kind == NotificationKind.vibeRequest
          ? 'De-Vibe'
          : null,
      unread: !_asBool(source['is_read'] ?? json['is_read']),
      readAt: _nullableString(source['read_at'] ?? json['read_at']),
      deliveryStatus: _nullableString(
        source['delivery_status'] ?? json['delivery_status'],
      ),
    );
  }

  NotificationItemModel copyWith({
    int? id,
    String? remoteId,
    NotificationKind? kind,
    String? type,
    String? username,
    String? actorUsername,
    String? title,
    String? timeAgo,
    String? message,
    String? avatar,
    String? actionUrl,
    String? entityType,
    int? entityId,
    String? createdAt,
    bool? isVerifiedBadge,
    bool? hasActor,
    String? thumbnail,
    String? primaryActionText,
    String? secondaryActionText,
    bool? unread,
    String? readAt,
    String? deliveryStatus,
  }) {
    return NotificationItemModel(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      kind: kind ?? this.kind,
      type: type ?? this.type,
      username: username ?? this.username,
      actorUsername: actorUsername ?? this.actorUsername,
      title: title ?? this.title,
      timeAgo: timeAgo ?? this.timeAgo,
      message: message ?? this.message,
      avatar: avatar ?? this.avatar,
      actionUrl: actionUrl ?? this.actionUrl,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      createdAt: createdAt ?? this.createdAt,
      isVerifiedBadge: isVerifiedBadge ?? this.isVerifiedBadge,
      hasActor: hasActor ?? this.hasActor,
      thumbnail: thumbnail ?? this.thumbnail,
      primaryActionText: primaryActionText ?? this.primaryActionText,
      secondaryActionText: secondaryActionText ?? this.secondaryActionText,
      unread: unread ?? this.unread,
      readAt: readAt ?? this.readAt,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': remoteId.isNotEmpty ? remoteId : id,
      'type': type,
      'kind': kind.name,
      'actor_username': actorUsername.isNotEmpty ? actorUsername : username,
      'username': username,
      'title': title,
      'body': message,
      'message': message,
      'actor_avatar_url': avatar,
      'action_url': actionUrl,
      'entity_type': entityType,
      'entity_id': entityId,
      'created_at': createdAt,
      'is_read': !unread,
      'read_at': readAt,
      'image_url': thumbnail,
      'is_verified': isVerifiedBadge,
    };
  }

  static NotificationKind _kindFromType(String type) {
    final normalized = type
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll('.', '_');
    if (isLikeType(normalized)) {
      return NotificationKind.like;
    }
    if (normalized.contains('vibe')) {
      return NotificationKind.vibeRequest;
    }
    if (normalized.contains('contest')) {
      return NotificationKind.contest;
    }
    if (normalized.contains('comment') || normalized.contains('reply')) {
      return NotificationKind.comment;
    }
    if (normalized == 'message' || normalized.contains('chat')) {
      return NotificationKind.message;
    }
    if (normalized.contains('support') || normalized.contains('ticket')) {
      return NotificationKind.support;
    }
    return NotificationKind.other;
  }

  static bool isLikeType(String type) {
    final normalized = type
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll('.', '_');
    if (normalized.isEmpty) {
      return false;
    }
    return normalized == 'like' ||
        normalized == 'liked' ||
        normalized == 'love' ||
        normalized == 'heart' ||
        normalized == 'favorite' ||
        normalized == 'favourite' ||
        normalized.contains('like') ||
        normalized.contains('react') ||
        normalized.contains('heart') ||
        normalized.contains('favorite') ||
        normalized.contains('favourite');
  }

  static NotificationKind _kindFromJson(
    Map<String, dynamic> json,
    String type,
  ) {
    final storedKind = (json['kind'] ?? '').toString().trim().toLowerCase();
    if (storedKind == 'like' || storedKind == 'liked') {
      return NotificationKind.like;
    }
    final fromType = _kindFromType(type);
    if (fromType != NotificationKind.other) {
      return fromType;
    }
    final entityType = (json['entity_type'] ?? '').toString();
    if (isLikeType(entityType)) {
      return NotificationKind.like;
    }
    if (json.containsKey('liker') ||
        json.containsKey('liked_by') ||
        json.containsKey('like_id') ||
        json.containsKey('liker_username')) {
      return NotificationKind.like;
    }
    final blob =
        '${json['title'] ?? ''} ${json['body'] ?? ''} ${json['message'] ?? ''} ${json['text'] ?? ''}'
            .toLowerCase();
    if (blob.contains('liked') ||
        blob.contains('like your') ||
        blob.contains('likes your') ||
        blob.contains('loved your')) {
      return NotificationKind.like;
    }
    if (blob.contains('comment') || blob.contains('replied')) {
      return NotificationKind.comment;
    }
    // Several StyleBite payloads type the row as the target ("post"/"reel")
    // instead of "like". An actor + empty/like-ish body on a post entity is
    // a like in practice; comments always say "comment" in type or body.
    final normalizedType = type.trim().toLowerCase();
    if ((normalizedType == 'post' ||
            normalizedType == 'reel' ||
            normalizedType == 'feed' ||
            entityType == 'post' ||
            entityType == 'reel') &&
        !blob.contains('comment') &&
        !blob.contains('contest') &&
        !blob.contains('vibe') &&
        (blob.isEmpty ||
            blob.contains('like') ||
            blob.contains('love') ||
            blob.contains('heart'))) {
      return NotificationKind.like;
    }
    return NotificationKind.other;
  }

  static String _readType(Map<String, dynamic> json) {
    return (json['type'] ??
            json['notification_type'] ??
            json['kind'] ??
            json['event'] ??
            json['event_type'] ??
            json['activity_type'] ??
            json['action'] ??
            json['category'] ??
            json['name'] ??
            '')
        .toString();
  }

  static String _resolveMessage(
    Map<String, dynamic> json,
    NotificationKind kind,
  ) {
    final body = (json['body'] ?? json['message'] ?? json['text'] ?? '')
        .toString()
        .trim();
    if (body.isNotEmpty) {
      return InAppSharePayload.previewText(body);
    }
    final title = (json['title'] ?? '').toString().trim();
    if (kind == NotificationKind.like) {
      return title.isNotEmpty ? title : 'liked your post';
    }
    return title;
  }

  static String _resolveActorUsername(
    Map<String, dynamic> actor,
    Map<String, dynamic> source,
  ) {
    return _nullableString(actor['username']) ??
        _nullableString(source['actor_username']) ??
        _nullableString(source['liker_username']) ??
        _nullableString(source['from_username']) ??
        '';
  }

  static String _resolveUsername(
    Map<String, dynamic> actor,
    String type,
    Map<String, dynamic> source,
  ) {
    final displayName = _nullableString(actor['display_name']);
    final fullName = _nullableString(actor['full_name']);
    final username = _nullableString(actor['username']) ??
        _nullableString(source['actor_username']) ??
        _nullableString(source['liker_username']) ??
        _nullableString(source['username']);

    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }
    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }
    if (username != null && username.isNotEmpty) {
      return username;
    }
    return type.replaceAll('_', ' ').trim().isEmpty ? 'Notification' : type;
  }

  static String? _primaryActionLabel(NotificationKind kind) {
    switch (kind) {
      case NotificationKind.comment:
      case NotificationKind.like:
        return 'View Post';
      case NotificationKind.contest:
        return 'View Contest';
      case NotificationKind.message:
        return 'Open Chat';
      case NotificationKind.vibeRequest:
        return 'Re-Vibe';
      case NotificationKind.support:
        return 'View Ticket';
      case NotificationKind.other:
        return 'Open';
    }
  }

  static Map<String, dynamic> _unwrapPayload(Map<String, dynamic> json) {
    var nested = json['data'] ?? json['notification'] ?? json['payload'];
    if (nested is String && nested.trim().isNotEmpty) {
      try {
        nested = jsonDecode(nested);
      } catch (_) {
        nested = null;
      }
    }
    if (nested is Map<String, dynamic>) {
      return {...json, ...nested};
    }
    if (nested is Map) {
      return {...json, ...Map<String, dynamic>.from(nested)};
    }
    return json;
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('$value') ?? 0;
  }

  static int _readId(dynamic value) {
    if (value is int) {
      return value;
    }
    final parsed = int.tryParse('$value');
    if (parsed != null) {
      return parsed;
    }
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text == 'null') {
      return 0;
    }
    return text.hashCode & 0x7fffffff;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  static String? _nullableString(dynamic value) {
    final resolved = value?.toString().trim();
    if (resolved == null || resolved.isEmpty || resolved == 'null') {
      return null;
    }
    return resolved;
  }
}

class NotificationsResponseModel {
  const NotificationsResponseModel({
    required this.statusCode,
    required this.message,
    required this.notifications,
    required this.pagination,
    required this.unreadCount,
  });

  final int statusCode;
  final String message;
  final List<NotificationItemModel> notifications;
  final NotificationsPaginationModel pagination;
  final int unreadCount;

  factory NotificationsResponseModel.fromJson(Map<String, dynamic> json) {
    final notifications = _resolveNotifications(json)
        .map((item) {
          try {
            return NotificationItemModel.fromJson(item);
          } catch (error, stackTrace) {
            log(
              'Dropped notification parse: $error keys=${item.keys.toList()} '
              'type=${item['type']} data=${item['data']}',
              stackTrace: stackTrace,
            );
            return null;
          }
        })
        .whereType<NotificationItemModel>()
        .toList();

    return NotificationsResponseModel(
      statusCode: NotificationItemModel._readInt(json['status_code']),
      message: (json['message'] ?? '').toString(),
      notifications: notifications,
      pagination: NotificationsPaginationModel.fromJson(
        NotificationItemModel._asMap(json['pagination']) ??
            (json['data'] is Map
                ? NotificationItemModel._asMap(
                    (json['data'] as Map)['pagination'],
                  )
                : null) ??
            <String, dynamic>{},
      ),
      unreadCount: NotificationItemModel._readInt(
        json['unread_count'] ??
            (json['data'] is Map ? json['data']['unread_count'] : null),
      ),
    );
  }

  static List<Map<String, dynamic>> _resolveNotifications(
    Map<String, dynamic> json,
  ) {
    final collected = <Map<String, dynamic>>[];
    final seen = <String>{};

    void addList(dynamic candidate) {
      if (candidate is! List) {
        return;
      }
      for (final item in candidate) {
        if (item is! Map) {
          continue;
        }
        final map = Map<String, dynamic>.from(item);
        final key =
            '${map['id']}_${map['type']}_${map['created_at']}_${map['entity_id']}_${map['post_id']}';
        if (seen.add(key)) {
          collected.add(map);
        }
      }
    }

    addList(json['notifications']);
    addList(json['items']);
    addList(json['likes']);
    addList(json['activities']);
    addList(json['records']);
    if (json['data'] is List) {
      addList(json['data']);
    }
    if (json['data'] is Map) {
      final data = json['data'] as Map;
      addList(data['notifications']);
      addList(data['items']);
      addList(data['likes']);
      addList(data['activities']);
      addList(data['records']);
      addList(data['data']);
    }

    return collected;
  }
}

class NotificationsPaginationModel {
  const NotificationsPaginationModel({
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.lastPage,
    required this.hasMorePages,
  });

  final int currentPage;
  final int perPage;
  final int total;
  final int lastPage;
  final bool hasMorePages;

  factory NotificationsPaginationModel.fromJson(Map<String, dynamic> json) {
    final currentPage = NotificationItemModel._readInt(json['current_page']);
    final lastPage = NotificationItemModel._readInt(json['last_page']);
    final hasMoreFlag = json['has_more_pages'] ?? json['has_more'];
    final hasMorePages = hasMoreFlag == true ||
        hasMoreFlag == 1 ||
        hasMoreFlag == '1' ||
        hasMoreFlag == 'true' ||
        (lastPage > 0 && currentPage > 0 && currentPage < lastPage);
    return NotificationsPaginationModel(
      currentPage: currentPage,
      perPage: NotificationItemModel._readInt(json['per_page']),
      total: NotificationItemModel._readInt(json['total']),
      lastPage: lastPage,
      hasMorePages: hasMorePages,
    );
  }
}
