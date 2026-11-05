import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/media/media_type_resolver.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_back_navigation.dart';
import '../../../core/utils/app_helper.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/app_cached_video_player.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../../../core/widgets/app_user_avatar.dart';
import '../../../core/widgets/app_verified_badge.dart';
import '../../../core/widgets/states/app_empty_state.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../landing/controllers/landing_controller.dart';
import '../../landing/screen/landing_screen.dart';
import '../../landing/widgets/landing_bottom_nav.dart';
import '../../profile/controllers/profile_controller.dart';
import '../../profile/utils/profile_open_helper.dart';
import '../controllers/notifications_controller.dart';
import '../models/notification_item_model.dart';
import '../utils/notification_navigator.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationsController _controller;
  final ScrollController _scrollController = ScrollController();
  final Map<int, String> _vibeResultById = <int, String>{};
  final Map<int, String> _followRequestResultById = <int, String>{};
  final Map<String, GlobalKey> _itemKeys = <String, GlobalKey>{};
  String? _openSwipeKey;
  String? _scrolledToHighlightId;
  Worker? _highlightWorker;

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
    _highlightWorker = ever<String?>(_controller.highlightNotificationId, (_) {
      _scrolledToHighlightId = null;
      _scheduleHighlightScroll();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleHighlightScroll();
    });
  }

  @override
  void dispose() {
    _highlightWorker?.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _scheduleHighlightScroll() {
    final target = _controller.highlightNotificationId.value?.trim() ?? '';
    if (target.isEmpty || target == _scrolledToHighlightId) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      NotificationItemModel? match;
      for (final item in _controller.notifications) {
        if (_controller.matchesHighlight(item)) {
          match = item;
          break;
        }
      }
      if (match == null) {
        return;
      }
      final keyId =
          match.remoteId.isNotEmpty ? match.remoteId : match.id.toString();
      final ctx = _itemKeys[keyId]?.currentContext;
      if (ctx == null) {
        return;
      }
      _scrolledToHighlightId = target;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.18,
      );
    });
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
                  side: BorderSide(color: AppColors.cardBorder),
                  backgroundColor: AppColors.chip,
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
    final keyId = item.remoteId.isNotEmpty ? item.remoteId : item.id.toString();
    final itemKey = _itemKeys.putIfAbsent(keyId, GlobalKey.new);
    final swipeKey =
        'notification-$keyId-${item.createdAt}-${item.username}-${item.entityId}';
    return Obx(() {
      final highlighted = _controller.matchesHighlight(item);
      if (highlighted) {
        _scheduleHighlightScroll();
      }
      return Padding(
        key: itemKey,
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
          child: _NotificationGlow(
            glowing: highlighted,
            child: item.kind == NotificationKind.contest
                ? _ContestCard(item: item, onTap: () => _handleActionTap(item))
                : _NotificationCard(
                    item: item,
                    resolvedVibeAction: _vibeResultById[item.id],
                    onTapVibeAction: (label) => _handleVibeTap(item, label),
                    resolvedFollowRequestAction:
                        _followRequestResultById[item.id],
                    onTapFollowRequestAction: (label) =>
                        _handleFollowRequestTap(item, label),
                    onTapPrimary: () => _handleActionTap(item),
                    onTapProfile: () => _openActorProfile(item),
                  ),
          ),
        ),
      );
    });
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

  void _handleFollowRequestTap(NotificationItemModel item, String actionLabel) {
    setState(() {
      _followRequestResultById[item.id] = actionLabel;
    });
    _controller.onFollowRequestAction(
      item,
      approve: actionLabel.toLowerCase().contains('approv'),
    );
  }

  void _handleActionTap(NotificationItemModel item) {
    _controller.onNotificationAction(item.id);
    unawaited(NotificationNavigator.openItem(item));
  }

  Future<void> _deleteNotification(NotificationItemModel item) async {
    final removedAt = _controller.softRemoveNotification(item);
    if (removedAt < 0 || !mounted) {
      return;
    }

    setState(() {
      _vibeResultById.remove(item.id);
      _followRequestResultById.remove(item.id);
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
    // Only paint the delete strip once the card has started sliding —
    // otherwise a translucent light-mode card lets the red bleed through.
    final showDelete = _offset > 0.5;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          if (showDelete)
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
                  child: SizedBox(
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
                      child: AppUserAvatar(
                        imageUrl: profileController.avatarImageUrl.value,
                        size: 40,
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

class _NotificationGlow extends StatefulWidget {
  const _NotificationGlow({
    required this.glowing,
    required this.child,
  });

  final bool glowing;
  final Widget child;

  @override
  State<_NotificationGlow> createState() => _NotificationGlowState();
}

class _NotificationGlowState extends State<_NotificationGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.glowing) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _NotificationGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.glowing && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.glowing && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.glowing) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = _pulse.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.22 + t * 0.38),
                blurRadius: 16 + t * 18,
                spreadRadius: 0.5 + t * 2.5,
              ),
            ],
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.45 + t * 0.45),
              width: 1.6,
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.resolvedVibeAction,
    required this.onTapVibeAction,
    required this.resolvedFollowRequestAction,
    required this.onTapFollowRequestAction,
    required this.onTapPrimary,
    required this.onTapProfile,
  });

  final NotificationItemModel item;
  final String? resolvedVibeAction;
  final ValueChanged<String> onTapVibeAction;
  final String? resolvedFollowRequestAction;
  final ValueChanged<String> onTapFollowRequestAction;
  final VoidCallback onTapPrimary;
  final VoidCallback onTapProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Opaque surface — translucent card let the swipe-delete red show
        // through on light backgrounds.
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
            spreadRadius: -10,
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
                    Positioned(
                      right: -1,
                      top: -1,
                      child: CircleAvatar(
                        radius: 5,
                        backgroundColor: AppColors.surface,
                        child: const CircleAvatar(
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
                    // Tap body (not just the Open link) → content screen,
                    // same as Instagram / TikTok notification rows.
                    GestureDetector(
                      onTap: onTapPrimary,
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                              ] else if (item.kind == NotificationKind.follow) ...[
                                const Padding(
                                  padding: EdgeInsets.only(top: 2, right: 6),
                                  child: Icon(
                                    Icons.person_add_alt_1_rounded,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ] else if (item.kind ==
                                  NotificationKind.storyReply) ...[
                                const Padding(
                                  padding: EdgeInsets.only(top: 2, right: 6),
                                  child: Icon(
                                    Icons.auto_stories_rounded,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                              Expanded(
                                child: item.kind == NotificationKind.storyReply
                                    ? _StoryReplyMessageBody(item: item)
                                    : Text(
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
                          if (item.hasOpenAction) ...[
                            const SizedBox(height: 10),
                            Row(
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
                          ],
                        ],
                      ),
                    ),
                    if (item.kind == NotificationKind.followRequest) ...[
                      const SizedBox(height: 10),
                      _buildFollowRequestActions(),
                    ] else if (item.kind == NotificationKind.vibeRequest) ...[
                      const SizedBox(height: 10),
                      _buildVibeActions(),
                    ],
                  ],
                ),
              ),
              if (item.thumbnail != null) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onTapPrimary,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: item.kind == NotificationKind.storyReply
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppColors.primary, AppColors.secondary],
                            ),
                          )
                        : null,
                    padding: item.kind == NotificationKind.storyReply
                        ? const EdgeInsets.all(2)
                        : EdgeInsets.zero,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        item.kind == NotificationKind.storyReply ? 10 : 10,
                      ),
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
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFollowRequestActions() {
    if (resolvedFollowRequestAction != null) {
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
          child: Text(resolvedFollowRequestAction!),
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
            ),
            child: ElevatedButton(
              onPressed: () => onTapFollowRequestAction('Approved'),
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
              child: const Text('Approve'),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: () => onTapFollowRequestAction('Cancelled'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.cardBorder),
              backgroundColor: AppColors.chip,
              padding: const EdgeInsets.symmetric(vertical: 11),
            ),
            child: Text(
              'Cancel',
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
              side: BorderSide(color: AppColors.cardBorder),
              backgroundColor: AppColors.chip,
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

class _StoryReplyMessageBody extends StatelessWidget {
  const _StoryReplyMessageBody({required this.item});

  final NotificationItemModel item;

  bool get _isReaction {
    final text = item.message.trim();
    if (text.isEmpty) {
      return false;
    }
    return text.runes.length <= 4 && !RegExp(r'[A-Za-z0-9]').hasMatch(text);
  }

  @override
  Widget build(BuildContext context) {
    final reply = item.message.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isReaction ? 'reacted to your story' : 'replied to your story',
          style: AppFonts.beVietnam(
            size: 13,
            weight: FontWeight.w500,
            color: AppColors.hintText,
          ),
        ),
        if (reply.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            reply,
            maxLines: _isReaction ? 1 : 4,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.beVietnam(
              size: _isReaction ? 22 : 13,
              height: _isReaction ? 1.1 : 1.35,
              weight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
        ],
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
      decoration: BoxDecoration(color: AppColors.chip,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: isSystem && imageUrl.trim().isEmpty
            ? const Padding(
                padding: EdgeInsets.all(7),
                child: Image(
                  image: AssetImage('assets/images/brand-logo.png'),
                  fit: BoxFit.contain,
                ),
              )
            : AppUserAvatar(imageUrl: imageUrl, size: 40),
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
    const trophyGold = Color(0xFFE0B23A);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
            spreadRadius: -10,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -6,
            top: -8,
            child: IgnorePointer(
              child: AppHeroIconData(
                Icons.emoji_events_rounded,
                size: 72,
                color: trophyGold.withValues(alpha: 0.12),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: trophyGold.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: trophyGold.withValues(alpha: 0.45),
                      ),
                    ),
                    child: const AppHeroIconData(
                      Icons.emoji_events_rounded,
                      color: trophyGold,
                      size: 22,
                    ),
                  ),
                  if (item.unread)
                    Positioned(
                      right: -1,
                      top: -1,
                      child: CircleAvatar(
                        radius: 5,
                        backgroundColor: AppColors.surface,
                        child: const CircleAvatar(
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
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                              VerifiedBadgeSlot(
                                username: item.username,
                                fallback: item.isVerifiedBadge,
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
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
                    const SizedBox(height: 4),
                    Text(
                      item.message,
                      style: AppFonts.beVietnam(
                        size: 13,
                        weight: FontWeight.w500,
                        color: AppColors.hintText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: onTap,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          textStyle: AppFonts.beVietnam(
                            size: 12,
                            weight: FontWeight.w700,
                          ),
                        ),
                        child: Text(item.contestActionLabel),
                      ),
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
