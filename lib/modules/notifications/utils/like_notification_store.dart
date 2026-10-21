import 'dart:convert';

import '../../../core/utils/local_storage.dart';
import '../models/notification_item_model.dart';

/// Likes are often delivered by FCM (or a filtered inbox endpoint) but
/// omitted from the default `GET /notifications` list. Persist them so a
/// later fetch/refresh cannot wipe a like the user already received.
class LikeNotificationStore {
  LikeNotificationStore._();

  static const _key = 'localLikeNotifications';
  static const _maxItems = 50;

  static List<NotificationItemModel> load() {
    final raw = LocalStorage.prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) {
      return const <NotificationItemModel>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <NotificationItemModel>[];
      }
      return decoded
          .whereType<Map>()
          .map((item) {
            try {
              return NotificationItemModel.fromJson(
                Map<String, dynamic>.from(item),
              );
            } catch (_) {
              return null;
            }
          })
          .whereType<NotificationItemModel>()
          .toList();
    } catch (_) {
      return const <NotificationItemModel>[];
    }
  }

  static void upsert(NotificationItemModel item) {
    final like = item.kind == NotificationKind.like
        ? item
        : item.copyWith(kind: NotificationKind.like, type: 'like');
    final next = load()
        .where((existing) => !_sameLike(existing, like))
        .toList();
    next.insert(0, like);
    _save(next.take(_maxItems).toList());
  }

  static void remove(NotificationItemModel item) {
    _save(load().where((existing) => !_sameLike(existing, item)).toList());
  }

  static void removeMatching(Iterable<NotificationItemModel> remote) {
    final remaining = load()
        .where(
          (local) => !remote.any((item) => _sameLike(item, local)),
        )
        .toList();
    _save(remaining);
  }

  static bool _sameLike(
    NotificationItemModel left,
    NotificationItemModel right,
  ) {
    if (left.remoteId.isNotEmpty &&
        right.remoteId.isNotEmpty &&
        left.remoteId == right.remoteId) {
      return true;
    }
    if (left.id != 0 && left.id == right.id) {
      return true;
    }
    return left.username == right.username &&
        left.entityId == right.entityId &&
        left.entityId > 0 &&
        left.message == right.message;
  }

  static void _save(List<NotificationItemModel> items) {
    LocalStorage.prefs.setString(
      _key,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }
}
