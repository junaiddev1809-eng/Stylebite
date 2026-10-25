import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/media/media_type_resolver.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_back_navigation.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/app_cached_video_player.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../../../core/widgets/app_verified_badge.dart';
import '../../../core/widgets/states/app_empty_state.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../landing/controllers/landing_controller.dart';
import '../../landing/screen/landing_screen.dart';
import '../../landing/widgets/landing_bottom_nav.dart';
import '../../messages/screen/messages_screen.dart';
import '../../post/utils/post_detail_open_helper.dart';
import '../../profile/controllers/profile_controller.dart';
import '../../profile/utils/profile_open_helper.dart';
import '../controllers/notifications_controller.dart';
import '../models/notification_item_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationsController _controller;
  final ScrollController _scrollController = ScrollController();
  final Map<int, String> _vibeResultById = <int, String>{};
  String? _openSwipeKey;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<NotificationsController>()
        ? Get.find<NotificationsController>()
        : Get.put(NotificationsController(), permanent: true);
    _scrollController.addListener(_onScroll);
    if (_controller.notifications.isEmpty) {
      _controller.fetchNotifications();
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Column(
            children: [
              const _TopBar(),
              Expanded(child: Obx(() => _buildContent())),
            ],
          ),
          const Align(alignment: Alignment.bottomCenter, child: _BottomNav()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed:
                    _controller.isMarkingAllRead.value ||
                        _controller.unreadCount.value == 0
                    ? null
                    : _controller.markAllRead,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                  backgroundColor: Colors.white.withValues(alpha: 0.55),
                ),
                child: Text(
                  _controller.isMarkingAllRead.value
                      ? 'Please wait'
                      : 'Mark Read',
                  style: AppFonts.beVietnam(
                    size: 11,
                    weight: FontWeight.w800,
                    color: AppColors.hintText,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              if (_controller.unreadCount.value > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_controller.unreadCount.value} New',
                    style: AppFonts.beVietnam(
                      size: 11,
                      weight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_controller.isInitialLoading.value) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller.hasError.value && _controller.notifications.isEmpty) {
      return AppErrorState(
        message: _controller.errorMessage.value.isEmpty
            ? 'Unable to load notifications right now.'
            : _controller.errorMessage.value,
        onRetry: _controller.refreshNotifications,
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _controller.refreshNotifications,
      child: _controller.notifications.isEmpty
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 152),
              children: [
                _buildHeader(),
                const SizedBox(height: 64),
                const AppEmptyState(
                  title: 'No notifications yet',
                  subtitle: 'When something new happens, it will show up here.',
                  icon: Icons.notifications_none_rounded,
                ),
              ],
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 152),
              itemCount:
                  _controller.notifications.length +
                  (_controller.isLoadingMore.value || !_controller.hasMore.value
                      ? 1
                      : 0),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 14),
                      _buildNotificationListItem(
                        _controller.notifications[index],
                      ),
                    ],
                  );
                }

                if (index >= _controller.notifications.length) {
                  if (_controller.isLoadingMore.value) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 12),
                    child: Center(
                      child: Text(
                        'No more data',
                        style: AppFonts.beVietnam(
                          size: 12,
                          weight: FontWeight.w600,
                          color: AppColors.hintText,
                        ),
                      ),
                    ),
                  );
                }

                return _buildNotificationListItem(
                  _controller.notifications[index],
                );
              },
            ),
    );
  }

  Widget _buildNotificationListItem(NotificationItemModel item) {
    final swipeKey =
        'notification-${item.remoteId.isNotEmpty ? item.remoteId : item.id}-${item.createdAt}-${item.username}-${item.entityId}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _SwipeRevealDelete(
        key: ValueKey<String>(swipeKey),
        isOpen: _openSwipeKey == swipeKey,
        onOpenChanged: (open) {
          setState(() {
            _openSwipeKey = open ? swipeKey : null;
          });
        },
        onDelete: () => _deleteNotification(item),
        child: item.kind == NotificationKind.contest
            ? _ContestCard(item: item, onTap: () => _handleActionTap(item))
            : _NotificationCard(
                item: item,
                resolvedVibeAction: _vibeResultById[item.id],
                onTapVibeAction: (label) => _handleVibeTap(item, label),
                onTapPrimary: () => _handleActionTap(item),
                onTapProfile: () => _openActorProfile(item),
              ),
      ),
    );
  }

  void _openActorProfile(NotificationItemModel item) {
    if (!item.hasActor) {
      return;
    }
    final username = item.profileHandle;
    if (username.isEmpty) {
      return;
    }
    ProfileOpenHelper.open(
      username: username,
      avatarUrl: item.avatar,
    );
  }

  void _handleVibeTap(NotificationItemModel item, String actionLabel) {
    setState(() {
      _vibeResultById[item.id] = actionLabel;
    });
    _controller.onVibeAction(item.id, actionLabel);
  }

  void _handleActionTap(NotificationItemModel item) {
    _controller.onNotificationAction(item.id);

    switch (item.kind) {
      case NotificationKind.like:
      case NotificationKind.comment:
        // For a comment notification, entity_id/entity_type refer to the
        // COMMENT ("entity_type": "comment"), not the post — action_url
        // ("/posts/{id}") is the only reliable source of the post id here.
        // entity_id is only trustworthy as a post id when entity_type
        // actually says "post" — except likes, where backends usually
        // attach the post id directly.
        if (_openFromActionUrl(item.actionUrl)) {
          break;
        }
        if (item.entityId > 0 &&
            (item.kind == NotificationKind.like || item.entityType == 'post')) {
          PostDetailOpenHelper.openById(item.entityId.toString());
        } else {
          _openLandingTab(0);
        }
        break;
      case NotificationKind.contest:
        if (item.entityId > 0) {
          Get.toNamed(
            AppRoutes.contestDetail,
            arguments: {'contestId': item.entityId},
          );
        } else {
          _openLandingTab(3);
        }
        break;
      case NotificationKind.message:
        Get.to<void>(() => const MessagesScreen());
        break;
      case NotificationKind.support:
        if (item.entityType == 'support_ticket' && item.entityId > 0) {
          Get.toNamed(
            AppRoutes.supportTicketDetail,
            arguments: {'ticketId': item.entityId},
          );
        }
        break;
      case NotificationKind.vibeRequest:
        break;
      case NotificationKind.other:
        // The backend sent a type string this client doesn't special-case
        // (e.g. "post"), but action_url still tells us exactly where to
        // go — e.g. "/posts/51" — so fall back to parsing that instead of
        // silently doing nothing.
        _openFromActionUrl(item.actionUrl);
        break;
    }
  }

  bool _openFromActionUrl(String actionUrl) {
    final uri = Uri.tryParse(actionUrl.trim());
    final segments =
        uri?.pathSegments.where((segment) => segment.isNotEmpty).toList() ??
        const <String>[];
    if (segments.length < 2) {
      return false;
    }

    final resource = segments[0].toLowerCase();
    final identifier = segments[1];

    switch (resource) {
      case 'posts':
      case 'post':
        PostDetailOpenHelper.openById(identifier);
        return true;
      case 'contests':
      case 'contest':
        final contestId = int.tryParse(identifier);
        if (contestId != null && contestId > 0) {
          Get.toNamed(
            AppRoutes.contestDetail,
            arguments: {'contestId': contestId},
          );
          return true;
        }
        return false;
      case 'chats':
      case 'chat':
        Get.to<void>(
          () => MessagesScreen(
            initialUsername: identifier.replaceFirst('@', ''),
          ),
        );
        return true;
      case 'support-tickets':
      case 'support_tickets':
        final ticketId = int.tryParse(identifier);
        if (ticketId != null && ticketId > 0) {
          Get.toNamed(
            AppRoutes.supportTicketDetail,
            arguments: {'ticketId': ticketId},
          );
          return true;
        }
        return false;
      case 'profiles':
      case 'profile':
      case 'users':
      case 'user':
      case 'u':
        ProfileOpenHelper.open(username: identifier);
        return true;
      default:
        return false;
    }
  }

  Future<void> _deleteNotification(NotificationItemModel item) async {
    final removedAt = _controller.softRemoveNotification(item);
    if (removedAt < 0 || !mounted) {
      return;
    }

    setState(() {
      _vibeResultById.remove(item.id);
      _openSwipeKey = null;
    });

    var undone = false;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Notification deleted',
          style: AppFonts.beVietnam(
            size: 14,
            weight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
        backgroundColor: const Color(0xFF1F1F22),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.primary,
          onPressed: () {
            undone = true;
            _controller.restoreNotification(item, removedAt);
            if (mounted) {
              setState(() {});
            }
          },
        ),
      ),
    );

    await controller.closed;
    if (undone) {
      return;
    }

    final committed = await _controller.commitDeleteNotification(item);
    if (!committed && mounted) {
      _controller.restoreNotification(item, removedAt);
      setState(() {});
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 160) {
      _controller.loadMoreNotifications();
    }
  }

  void _openLandingTab(int tabIndex) {
    Get.offAll<void>(() => LandingScreen(initialIndex: tabIndex));
  }
}

/// Short end-to-start swipe reveals a trash button; delete only runs on tap.
class _SwipeRevealDelete extends StatefulWidget {
  const _SwipeRevealDelete({
    super.key,
    required this.child,
    required this.onDelete,
    required this.isOpen,
    required this.onOpenChanged,
    this.revealWidth = 76,
  });

  final Widget child;
  final VoidCallback onDelete;
  final bool isOpen;
  final ValueChanged<bool> onOpenChanged;
  final double revealWidth;

  @override
  State<_SwipeRevealDelete> createState() => _SwipeRevealDeleteState();
}

class _SwipeRevealDeleteState extends State<_SwipeRevealDelete> {
  double _offset = 0;

  @override
  void didUpdateWidget(covariant _SwipeRevealDelete oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      _offset = widget.isOpen ? widget.revealWidth : 0;
    }
  }

  void _snapOpen(bool open) {
    setState(() {
      _offset = open ? widget.revealWidth : 0;
    });
    if (widget.isOpen != open) {
      widget.onOpenChanged(open);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: widget.revealWidth,
                child: Material(
                  color: const Color(0xFFE5484D),
                  child: InkWell(
                    onTap: widget.onDelete,
                    child: const Center(
                      child: AppHeroIconData(
                        Icons.delete_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              final next = (_offset - details.delta.dx).clamp(
                0.0,
                widget.revealWidth,
              );
              if (next == _offset) {
                return;
              }
              setState(() => _offset = next);
            },
            onHorizontalDragEnd: (_) {
              _snapOpen(_offset >= widget.revealWidth * 0.35);
            },
            onHorizontalDragCancel: () {
              _snapOpen(_offset >= widget.revealWidth * 0.35);
            },
            onTap: _offset > 0 ? () => _snapOpen(false) : null,
            child: Transform.translate(
              offset: Offset(-_offset, 0),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final profileController = Get.isRegistered<ProfileController>()
        ? Get.find<ProfileController>()
        : Get.put(ProfileController());

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: SafeArea(
          bottom: false,
          child: Container(
            height: 66,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: AppColors.background.withValues(alpha: 0.84),
            child: Row(
              children: [
                InkWell(
                  onTap: AppBackNavigation.handleBack,
                  borderRadius: BorderRadius.circular(999),
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: AppHeroIconData(
                      Icons.arrow_back_rounded,
                      color: AppColors.hintText,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Notifications',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.plusJakarta(
                      size: 22,
                      weight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    final username =
                        Get.isRegistered<ProfileController>()
                        ? Get.find<ProfileController>().username
                        : '';
                    if (username.trim().isNotEmpty) {
                      ProfileOpenHelper.open(username: username);
                      return;
                    }
                    Get.offAll<void>(
                      () => const LandingScreen(initialIndex: 4),
                    );
                  },
                  child: Obx(
                    () => Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.22),
                          width: 1.8,
                        ),
                      ),
                      child: ClipOval(
                        child:
                            profileController.avatarImageUrl.value
                                .trim()
                                .isNotEmpty
                            ? AppCachedImage(
                                imageUrl:
                                    profileController.avatarImageUrl.value,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              )
                            : const AppHeroIconData(Icons.person_rounded),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.resolvedVibeAction,
    required this.onTapVibeAction,
    required this.onTapPrimary,
    required this.onTapProfile,
  });

  final NotificationItemModel item;
  final String? resolvedVibeAction;
  final ValueChanged<String> onTapVibeAction;
  final VoidCallback onTapPrimary;
  final VoidCallback onTapProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.055),
            blurRadius: 28,
            offset: const Offset(0, 10),
            spreadRadius: -14,
          ),
        ],
      ),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: item.hasActor ? onTapProfile : null,
                    child: _NotificationAvatar(
                      imageUrl: item.avatar,
                      isSystem: !item.hasActor,
                    ),
                  ),
                  if (item.unread)
                    const Positioned(
                      right: -1,
                      top: -1,
                      child: CircleAvatar(
                        radius: 5,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 4,
                          backgroundColor: Color(0xFFFF4D6D),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: item.hasActor ? onTapProfile : null,
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  item.username,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppFonts.beVietnam(
                                    size: 14,
                                    weight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                              VerifiedBadgeSlot(
                                username: item.profileHandle.isNotEmpty
                                    ? item.profileHandle
                                    : item.username,
                                fallback: item.isVerifiedBadge,
                                size: 14,
                              ),
                            ],
                          ),
                          ),
                        ),
                        Text(
                          item.timeAgo,
                          style: AppFonts.beVietnam(
                            size: 11,
                            weight: FontWeight.w500,
                            color: AppColors.hintText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.kind == NotificationKind.like) ...[
                          const Padding(
                            padding: EdgeInsets.only(top: 2, right: 6),
                            child: Icon(
                              Icons.favorite_rounded,
                              size: 14,
                              color: Color(0xFFFF4D6D),
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            item.message,
                            style: AppFonts.beVietnam(
                              size: 13,
                              weight: FontWeight.w500,
                              color: AppColors.hintText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (item.kind == NotificationKind.vibeRequest) ...[
                      const SizedBox(height: 10),
                      _buildVibeActions(),
                    ] else if (item.hasOpenAction) ...[
                      const SizedBox(height: 10),
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: onTapPrimary,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.primaryActionText ?? 'Open',
                                style: AppFonts.beVietnam(
                                  size: 13,
                                  weight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              AppHeroIconData(
                                item.kind == NotificationKind.message
                                    ? Icons.chat_bubble_rounded
                                    : Icons.chevron_right_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (item.thumbnail != null) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onTapPrimary,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 54,
                      height: 54,
                      // The notifications API only sends one url per item —
                      // for a video post it's the raw video file, not a
                      // thumbnail, and AppCachedImage can't decode that as an
                      // image (shows a broken-image icon). Render the video's
                      // own first frame instead when that's what we got.
                      child:
                          MediaTypeResolver.resolve(
                                item.thumbnail!,
                                fallback: AppMediaType.image,
                              ) ==
                              AppMediaType.video
                          ? AppCachedVideoPlayer(
                              videoUrl: item.thumbnail!,
                              autoPlay: false,
                              showControls: false,
                            )
                          : AppCachedImage(
                              imageUrl: item.thumbnail!,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVibeActions() {
    if (resolvedVibeAction != null) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.9),
            disabledForegroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 11),
            textStyle: AppFonts.beVietnam(size: 13, weight: FontWeight.w700),
          ),
          child: Text(resolvedVibeAction!),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.secondary],
              ),
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(255, 77, 109, 0.28),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () => onTapVibeAction('Vibe Returned'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                textStyle: AppFonts.beVietnam(
                  size: 13,
                  weight: FontWeight.w700,
                ),
              ),
              child: const Text('Re-Vibe'),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: () => onTapVibeAction('De-Vibed'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.black.withValues(alpha: 0.2)),
              backgroundColor: Colors.white.withValues(alpha: 0.45),
              padding: const EdgeInsets.symmetric(vertical: 11),
            ),
            child: Text(
              'De-Vibe',
              style: AppFonts.beVietnam(
                size: 13,
                weight: FontWeight.w700,
                color: AppColors.hintText,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationAvatar extends StatelessWidget {
  const _NotificationAvatar({required this.imageUrl, this.isSystem = false});

  final String imageUrl;
  final bool isSystem;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: Color(0xFFF1EEEE),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: imageUrl.trim().isNotEmpty
            ? AppCachedImage(
                imageUrl: imageUrl,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
              )
            : isSystem
            ? const Padding(
                padding: EdgeInsets.all(7),
                child: Image(
                  image: AssetImage('assets/images/brand-logo.png'),
                  fit: BoxFit.contain,
                ),
              )
            : const AppHeroIconData(
                Icons.person_rounded,
                color: AppColors.hintText,
              ),
      ),
    );
  }
}

class _ContestCard extends StatelessWidget {
  const _ContestCard({required this.item, required this.onTap});

  final NotificationItemModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1E1E), Color(0xFF2D2D2D)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: AppHeroIconData(
              Icons.emoji_events_rounded,
              size: 86,
              color: const Color(0xFFF9CC61).withValues(alpha: 0.22),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9CC61),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const AppHeroIconData(
                      Icons.emoji_events_rounded,
                      color: Color(0xFF5B4400),
                    ),
                  ),
                  if (item.unread)
                    const Positioned(
                      right: -1,
                      top: -1,
                      child: CircleAvatar(
                        radius: 5,
                        backgroundColor: Color(0xFF2D2D2D),
                        child: CircleAvatar(
                          radius: 4,
                          backgroundColor: Color(0xFFFB5151),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  item.title.trim().isNotEmpty
                                      ? item.title.trim()
                                      : item.username,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppFonts.beVietnam(
                                    size: 14,
                                    weight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              VerifiedBadgeSlot(
                                username: item.username,
                                fallback: item.isVerifiedBadge,
                                size: 14,
                                color: const Color(0xFF7CC4FF),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          item.timeAgo,
                          style: AppFonts.beVietnam(
                            size: 11,
                            weight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.message,
                      style: AppFonts.beVietnam(
                        size: 13,
                        weight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF2D2D2D),
                        textStyle: AppFonts.beVietnam(
                          size: 12,
                          weight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      child: Text(item.primaryActionText ?? 'View Contest'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    final landingController = Get.isRegistered<LandingController>()
        ? Get.find<LandingController>()
        : Get.put(LandingController());

    return LandingBottomNav(
      tabs: landingController.tabs,
      currentIndex: -1,
      onTap: (index) => Get.offAll<void>(
        () => LandingScreen(initialIndex: index),
      ),
    );
  }
}
