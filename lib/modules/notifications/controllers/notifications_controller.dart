import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:get/get.dart';

import '../../../core/utils/api_helper.dart';
import '../../../core/utils/app_helper.dart';
import '../../../core/utils/verified_badge_hydrator.dart';
import '../../messages/services/chat_event_bus.dart';
import '../models/notification_item_model.dart';
import '../utils/like_notification_store.dart';

class NotificationsController extends GetxController {
  static const int _perPage = 50;

  final RxList<NotificationItemModel> notifications =
      <NotificationItemModel>[].obs;

  final RxBool isInitialLoading = true.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool isMarkingAllRead = false.obs;
  final RxList<int> deletingNotificationIds = <int>[].obs;
  final RxBool hasError = false.obs;
  final RxBool hasMore = true.obs;
  final RxString errorMessage = ''.obs;
  final RxInt unreadCount = 0.obs;

  int _currentPage = 0;
  StreamSubscription<ChatPushEvent>? _pushSubscription;
  int _localLikeId = 0;

  @override
  void onInit() {
    super.onInit();
    _pushSubscription = ChatEventBus.instance.stream.listen(_handlePushEvent);
    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      if (isClosed) {
        return;
      }
      fetchNotifications();
    });
  }

  Future<void> fetchNotifications({bool reset = true}) async {
    if (reset) {
      if (notifications.isEmpty) {
        isInitialLoading.value = true;
      }
      hasError.value = false;
      errorMessage.value = '';
      _currentPage = 0;
      hasMore.value = true;
    } else {
      if (isLoadingMore.value || !hasMore.value) {
        return;
      }
      isLoadingMore.value = true;
    }

    try {
      final page = reset ? 1 : _currentPage + 1;
      final parsed = await _loadNotificationPage(page, includeLikeFeed: reset);
      if (reset) {
        notifications.assignAll(_mergeLocalLikes(parsed.notifications));
      } else {
        notifications.addAll(parsed.notifications);
        notifications.assignAll(_mergeLocalLikes(notifications.toList()));
      }

      _currentPage = parsed.pagination.currentPage == 0
          ? page
          : parsed.pagination.currentPage;
      hasMore.value = parsed.pagination.hasMorePages;
      unreadCount.value = parsed.unreadCount;
      VerifiedBadgeHydrator.hydrate(
        parsed.notifications.map((item) => item.username),
      );
    } catch (error) {
      hasError.value = true;
      errorMessage.value = error.toString().replaceFirst('Exception: ', '');
      if (reset) {
        final localLikes = _mergeLocalLikes(notifications.toList());
        if (localLikes.isNotEmpty) {
          notifications.assignAll(localLikes);
          hasError.value = false;
        }
      } else {
        errorSnackBar(message: errorMessage.value);
      }
    } finally {
      if (reset) {
        isInitialLoading.value = false;
      } else {
        isLoadingMore.value = false;
      }
    }
  }

  Future<void> refreshNotifications() async {
    await fetchNotifications();
  }

  Future<void> loadMoreNotifications() async {
    await fetchNotifications(reset: false);
  }

  Future<void> markAllRead() async {
    if (isMarkingAllRead.value || unreadCount.value == 0) {
      return;
    }

    isMarkingAllRead.value = true;
    try {
      final response = await ApiHelper.patchRequestWithAuthorization(
        'notifications/read-all',
      );
      if (response == null) {
        throw Exception('No response returned from mark-all-read endpoint.');
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          (payload['status_code'] != 1 && payload['status_code'] != '1')) {
        throw Exception(
          (payload['message'] ?? 'Failed to mark notifications as read')
              .toString(),
        );
      }

      notifications.assignAll(
        notifications
            .map(
              (item) => item.unread
                  ? item.copyWith(
                      unread: false,
                      readAt: DateTime.now().toIso8601String(),
                    )
                  : item,
            )
            .toList(),
      );
      unreadCount.value = 0;
      infoSnackBar(message: 'All notifications marked as read');
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      isMarkingAllRead.value = false;
    }
  }

  Future<void> markRead(int id, {bool showToast = false}) async {
    final index = notifications.indexWhere((item) => item.id == id);
    if (index == -1) {
      return;
    }

    if (!notifications[index].unread) {
      if (showToast) {
        infoSnackBar(message: 'Opened');
      }
      return;
    }

    try {
      final item = notifications[index];
      if (_isLocalItem(item)) {
        notifications[index] = item.copyWith(
          unread: false,
          readAt: DateTime.now().toIso8601String(),
        );
        if (unreadCount.value > 0) {
          unreadCount.value -= 1;
        }
        LikeNotificationStore.upsert(notifications[index]);
        if (showToast) {
          infoSnackBar(message: 'Marked as read');
        }
        return;
      }

      final response = await ApiHelper.patchRequestWithAuthorization(
        'notifications/${_apiId(item)}/read',
      );
      if (response == null) {
        throw Exception('No response returned from mark-read endpoint.');
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          (payload['status_code'] != 1 && payload['status_code'] != '1')) {
        throw Exception(
          (payload['message'] ?? 'Failed to mark notification as read')
              .toString(),
        );
      }

      notifications[index] = notifications[index].copyWith(
        unread: false,
        readAt: DateTime.now().toIso8601String(),
      );
      if (unreadCount.value > 0) {
        unreadCount.value -= 1;
      }
      if (showToast) {
        infoSnackBar(message: 'Marked as read');
      }
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Soft-removes a row for undoable delete. Returns the original index, or
  /// `-1` if the item was not found / already being deleted.
  int softRemoveNotification(NotificationItemModel item) {
    final id = item.id;
    if (deletingNotificationIds.contains(id)) {
      return -1;
    }
    final index = notifications.indexWhere((entry) => entry.id == id);
    if (index == -1) {
      return -1;
    }
    deletingNotificationIds.add(id);
    notifications.removeAt(index);
    if (item.unread && unreadCount.value > 0) {
      unreadCount.value -= 1;
    }
    if (notifications.isEmpty) {
      hasMore.value = false;
    }
    return index;
  }

  void restoreNotification(NotificationItemModel item, int index) {
    final insertAt = index.clamp(0, notifications.length);
    if (notifications.any((entry) => entry.id == item.id)) {
      deletingNotificationIds.remove(item.id);
      return;
    }
    notifications.insert(insertAt, item);
    if (item.unread) {
      unreadCount.value += 1;
    }
    hasMore.value = true;
    deletingNotificationIds.remove(item.id);
  }

  /// Commits a soft-removed notification to the API / local store.
  Future<bool> commitDeleteNotification(NotificationItemModel item) async {
    try {
      if (_isLocalItem(item)) {
        LikeNotificationStore.remove(item);
        return true;
      }

      final response = await ApiHelper.deleteRequestWithAuthorization(
        'notifications/${_apiId(item)}',
      );
      if (response == null) {
        throw Exception('No response returned from delete endpoint.');
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          (payload['status_code'] != 1 && payload['status_code'] != '1')) {
        throw Exception(
          (payload['message'] ?? 'Failed to delete notification').toString(),
        );
      }

      LikeNotificationStore.remove(item);
      return true;
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
      return false;
    } finally {
      deletingNotificationIds.remove(item.id);
    }
  }

  // Returns whether the notification was actually removed — kept for any
  // callers that still want an immediate hard delete.
  Future<bool> deleteNotification(int id) async {
    final index = notifications.indexWhere((item) => item.id == id);
    if (index == -1) {
      return false;
    }
    final item = notifications[index];
    final removedAt = softRemoveNotification(item);
    if (removedAt < 0) {
      return false;
    }
    final committed = await commitDeleteNotification(item);
    if (!committed) {
      restoreNotification(item, removedAt);
    }
    return committed;
  }

  Future<void> onVibeAction(int id, String actionLabel) async {
    await markRead(id);
    infoSnackBar(message: actionLabel);
  }

  Future<void> onNotificationAction(int id) async {
    // Tapping a notification already navigates somewhere — a "View Post"
    // toast on top of that navigation is redundant, unlike onVibeAction
    // above where the toast is the only feedback since there's no
    // navigation.
    await markRead(id);
  }

  void _handlePushEvent(ChatPushEvent event) {
    if (!_isLikePush(event)) {
      return;
    }
    _ingestLikeFromPush(event.payload);
    fetchNotifications(reset: true);
  }

  bool _isLikePush(ChatPushEvent event) {
    if (NotificationItemModel.isLikeType(event.type)) {
      return true;
    }
    final entityType = (event.payload['entity_type'] ?? '').toString();
    if (NotificationItemModel.isLikeType(entityType)) {
      return true;
    }
    final blob =
        '${event.payload['title'] ?? ''} ${event.payload['body'] ?? ''} ${event.payload['message'] ?? ''} ${event.payload['text'] ?? ''}'
            .toLowerCase();
    if (blob.contains('liked') ||
        blob.contains('like your') ||
        blob.contains('likes your') ||
        blob.contains('loved your')) {
      return true;
    }
    final eventName = (event.payload['event'] ?? '').toString().toLowerCase();
    return eventName.contains('like');
  }

  void _ingestLikeFromPush(Map<String, dynamic> payload) {
    try {
      final item = NotificationItemModel.fromJson(payload);
      final like = item.kind == NotificationKind.like
          ? item
          : item.copyWith(kind: NotificationKind.like, type: 'like');
      final resolved = like.id > 0
          ? like
          : like.copyWith(
              id: --_localLikeId,
              remoteId: like.remoteId.isNotEmpty
                  ? like.remoteId
                  : 'local-$_localLikeId',
            );

      LikeNotificationStore.upsert(resolved);

      final alreadyVisible = notifications.any(
        (existing) => _sameNotification(existing, resolved),
      );
      if (alreadyVisible) {
        return;
      }

      notifications.insert(0, resolved);
      if (resolved.unread) {
        unreadCount.value += 1;
      }
    } catch (error, stackTrace) {
      log(
        'Failed to ingest like notification: $error',
        stackTrace: stackTrace,
      );
    }
  }

  Future<NotificationsResponseModel> _loadNotificationPage(
    int page, {
    required bool includeLikeFeed,
  }) async {
    final main = await _fetchNotifications('page=$page&per_page=$_perPage');
    if (main == null) {
      throw Exception('No response returned from notifications endpoint.');
    }

    final parsed = NotificationsResponseModel.fromJson(main);
    log(
      'Notifications page $page kinds: '
      '${parsed.notifications.map((item) => '${item.kind.name}/${item.type}').join(', ')}',
    );
    log(
      'Notifications page $page like count: '
      '${parsed.notifications.where((item) => item.kind == NotificationKind.like).length}',
    );

    if (!includeLikeFeed) {
      return parsed;
    }

    final extras = await Future.wait([
      _fetchNotifications('page=$page&per_page=$_perPage&type=like'),
      _fetchNotifications(
        'page=$page&per_page=$_perPage&notification_type=like',
      ),
      _fetchNotifications('page=$page&per_page=$_perPage&filter%5Btype%5D=like'),
    ]);

    final merged = <NotificationItemModel>[...parsed.notifications];
    for (final extra in extras) {
      if (extra == null) {
        continue;
      }
      final extraParsed = NotificationsResponseModel.fromJson(extra);
      for (final item in extraParsed.notifications) {
        if (merged.any((existing) => _sameNotification(existing, item))) {
          continue;
        }
        merged.add(item);
      }
    }

    return NotificationsResponseModel(
      statusCode: parsed.statusCode,
      message: parsed.message,
      notifications: merged,
      pagination: parsed.pagination,
      unreadCount: parsed.unreadCount,
    );
  }

  Future<Map<String, dynamic>?> _fetchNotifications(String query) async {
    final response = await ApiHelper.fetchDataWithAuthorization(
      'notifications?$query',
    );
    if (response == null) {
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      if (decoded['status_code'] != 1 && decoded['status_code'] != '1') {
        return null;
      }
      return decoded;
    } catch (_) {
      return null;
    }
  }

  List<NotificationItemModel> _mergeLocalLikes(
    List<NotificationItemModel> remote,
  ) {
    final local = LikeNotificationStore.load();
    LikeNotificationStore.removeMatching(
      remote.where((item) => item.kind == NotificationKind.like),
    );

    final merged = <NotificationItemModel>[...remote];
    for (final like in local) {
      if (merged.any((existing) => _sameNotification(existing, like))) {
        continue;
      }
      merged.insert(0, like);
    }
    return merged;
  }

  bool _sameNotification(
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
    return left.kind == right.kind &&
        left.username == right.username &&
        left.entityId == right.entityId &&
        left.entityId > 0 &&
        left.message == right.message;
  }

  bool _isLocalItem(NotificationItemModel item) {
    return item.id < 0 || item.remoteId.startsWith('local-');
  }

  String _apiId(NotificationItemModel item) {
    if (item.remoteId.trim().isNotEmpty &&
        item.remoteId != '0' &&
        item.remoteId != 'null') {
      return Uri.encodeComponent(item.remoteId);
    }
    return '${item.id}';
  }

  @override
  void onClose() {
    _pushSubscription?.cancel();
    super.onClose();
  }
}
