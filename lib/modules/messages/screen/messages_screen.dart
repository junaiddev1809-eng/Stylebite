import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_back_navigation.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../../../core/widgets/app_verified_badge.dart';
import '../../../core/widgets/states/app_empty_state.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_shimmer_box.dart';
import '../../landing/screen/landing_screen.dart';
import '../../profile/controllers/profile_controller.dart';
import '../../settings/screen/settings_screen.dart';
import '../../post/utils/in_app_share.dart';
import '../controllers/messages_controller.dart';
import '../models/chat_models.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    super.key,
    this.initialUsername,
    this.initialConversationId,
  });

  final String? initialUsername;
  final int? initialConversationId;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late final String _tag;
  late final MessagesController _controller;
  late final FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _tag = '${MessagesScreen}_${DateTime.now().microsecondsSinceEpoch}';
    _controller = Get.put(MessagesController(), tag: _tag);
    _searchFocusNode = FocusNode();

    final initialUsername = widget.initialUsername?.trim();
    if (initialUsername != null && initialUsername.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.openFromPayload(
          username: initialUsername,
          conversationId: widget.initialConversationId,
        );
      });
    }
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    if (Get.isRegistered<MessagesController>(tag: _tag)) {
      Get.delete<MessagesController>(tag: _tag);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _MessagesBackdrop()),
          Column(
            children: [
              const _MessagesTopBar(),
              Expanded(
                child: Obx(
                  () => RefreshIndicator(
                    onRefresh: _controller.refreshChats,
                    color: AppColors.primary,
                    child: ListView(
                      controller: _controller.scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        10,
                        16,
                        safeBottom + 24,
                      ),
                      children: [
                        _buildSearch(),
                        const SizedBox(height: 16),
                        if (_controller.query.value.trim().isNotEmpty &&
                            _controller.chats.isEmpty &&
                            !_controller.isInitialLoading.value &&
                            !_controller.hasError.value)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Showing results for "${_controller.query.value.trim()}"',
                              style: AppFonts.beVietnam(
                                size: 12,
                                weight: FontWeight.w600,
                                color: AppColors.hintText,
                              ),
                            ),
                          ),
                        if (_controller.chats.isNotEmpty) ...[
                          Row(
                            children: [
                              Text(
                                'Conversations',
                                style: AppFonts.plusJakarta(
                                  size: 18,
                                  weight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(width: 10),
                              _Pill(
                                label: '${_controller.chats.length}',
                                background: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                foreground: AppColors.primary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_controller.isInitialLoading.value)
                          const _ChatListShimmer()
                        else if (_controller.hasError.value &&
                            _controller.chats.isEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            decoration: _softCardDecoration(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 18,
                                horizontal: 8,
                              ),
                              child: AppErrorState(
                                message: _controller.errorMessage.value,
                                onRetry: () =>
                                    _controller.fetchChats(reset: true),
                              ),
                            ),
                          )
                        else if (_controller.chats.isEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            decoration: _softCardDecoration(),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: 20,
                                horizontal: 8,
                              ),
                              child: _MessagesEmptyState(
                                controller: _controller,
                              ),
                            ),
                          )
                        else
                          ...List<Widget>.generate(
                            _controller.chats.length + 1,
                            (index) {
                              if (index == _controller.chats.length) {
                                return ChatListFooter(
                                  isLoadingMore:
                                      _controller.isLoadingMore.value,
                                  hasMore: _controller.hasMore.value,
                                );
                              }

                              final thread = _controller.chats[index];
                              return _StaggeredFadeIn(
                                key: ValueKey(
                                  'chat_thread_${thread.conversationId}',
                                ),
                                index: index,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _MessageTile(
                                    thread: thread,
                                    onTap: () => _controller.openChat(thread),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return ListenableBuilder(
      listenable: _searchFocusNode,
      builder: (context, _) {
        final isFocused = _searchFocusNode.hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isFocused ? 0.95 : 0.72),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isFocused
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.8),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: (isFocused ? AppColors.primary : const Color(0xFF2F2F2E))
                    .withValues(alpha: isFocused ? 0.16 : 0.07),
                blurRadius: isFocused ? 26 : 20,
                offset: const Offset(0, 8),
                spreadRadius: -10,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, Color(0xFFFF8A5B)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const AppHeroIconData(
                  Icons.search_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _controller.searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _controller.onQueryChanged,
                  style: AppFonts.beVietnam(size: 14, weight: FontWeight.w600),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Search contacts or chats...',
                    hintStyle: AppFonts.beVietnam(
                      size: 14,
                      weight: FontWeight.w500,
                      color: AppColors.hintText.withValues(alpha: 0.72),
                    ),
                  ),
                ),
              ),
              if (_controller.query.value.trim().isNotEmpty)
                IconButton(
                  onPressed: () {
                    _controller.searchController.clear();
                    _controller.onQueryChanged('');
                  },
                  icon: const AppHeroIconData(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.hintText,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Shared soft glass-card surface used by the empty/error states and the
/// loading shimmer, so they read as one consistent premium surface language.
BoxDecoration _softCardDecoration() {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.7),
    borderRadius: BorderRadius.circular(28),
    border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.1),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF2F2F2E).withValues(alpha: 0.07),
        blurRadius: 26,
        offset: const Offset(0, 12),
        spreadRadius: -14,
      ),
    ],
  );
}

/// End-of-list marker for the chat list's pagination: an in-flight spinner
/// while loading the next page, a "No more data" line once every page has
/// been loaded, or nothing while there's simply more to fetch on scroll.
@visibleForTesting
class ChatListFooter extends StatelessWidget {
  const ChatListFooter({
    super.key,
    required this.isLoadingMore,
    required this.hasMore,
  });

  final bool isLoadingMore;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    if (isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
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

    return const SizedBox.shrink();
  }
}

/// Compact rounded label used for counts/timestamps/status chips across this
/// screen — one shared shape/weight so every badge reads as the same design
/// language instead of several one-off pills.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
    this.fontSize = 11,
  });

  final String label;
  final Color background;
  final Color foreground;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppFonts.beVietnam(
          size: fontSize,
          weight: FontWeight.w700,
          letterSpacing: 0.2,
          color: foreground,
        ),
      ),
    );
  }
}

/// Staggered fade + rise-in for list rows. Keyed by the caller on a stable
/// identity (e.g. conversation id) so a live reorder/update — which rebuilds
/// the whole Obx-wrapped list — relocates the existing element instead of
/// recreating it, and the entrance animation only plays once per row.
class _StaggeredFadeIn extends StatefulWidget {
  const _StaggeredFadeIn({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<_StaggeredFadeIn> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: 35 * widget.index.clamp(0, 10));
    Future.delayed(delay, () {
      if (mounted) {
        setState(() => _visible = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(0, 0.05),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _MessagesEmptyState extends StatelessWidget {
  const _MessagesEmptyState({this.controller});

  final MessagesController? controller;

  @override
  Widget build(BuildContext context) {
    final resolvedController = controller;
    if (resolvedController == null) {
      return const SizedBox.shrink();
    }

    return Obx(() {
      final query = resolvedController.query.value.trim();
      final isSearching = query.isNotEmpty;
      return AppEmptyState(
        title: isSearching ? 'No results found' : 'No chats yet',
        subtitle: isSearching
            ? 'We could not find a chat that matches "$query".'
            : 'Start a conversation from a profile or search result.',
        icon: isSearching
            ? Icons.manage_search_rounded
            : Icons.chat_bubble_outline_rounded,
      );
    });
  }
}

class _MessagesBackdrop extends StatelessWidget {
  const _MessagesBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFF6F2),
            Color(0xFFFDF2EE),
            AppColors.background,
            Color(0xFFF6EFEA),
          ],
          stops: [0.0, 0.28, 0.62, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -40,
            child: _GlowBlob(size: 190, color: Color(0xFFFFD1C3)),
          ),
          Positioned(
            top: 110,
            left: -60,
            child: _GlowBlob(size: 150, color: Color(0xFFFFE7A8)),
          ),
          Positioned(
            bottom: 200,
            right: -50,
            child: _GlowBlob(size: 140, color: Color(0xFFFFC0CB)),
          ),
          Positioned(
            bottom: -60,
            left: -30,
            child: _GlowBlob(
              size: 150,
              color: AppColors.primary,
              opacity: 0.14,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({
    required this.size,
    required this.color,
    this.opacity = 0.26,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _MessagesTopBar extends StatelessWidget {
  const _MessagesTopBar();

  @override
  Widget build(BuildContext context) {
    final profileController = Get.isRegistered<ProfileController>()
        ? Get.find<ProfileController>()
        : Get.put(ProfileController());

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: SafeArea(
          bottom: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            color: AppColors.background.withValues(alpha: 0.95),
            child: Row(
              children: [
                InkWell(
                  onTap: AppBackNavigation.handleBack,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: const AppHeroIconData(
                      Icons.arrow_back_rounded,
                      color: AppColors.hintText,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => Get.offAll<void>(
                    () => const LandingScreen(initialIndex: 4),
                  ),
                  borderRadius: BorderRadius.circular(999),
                  child: Obx(
                    () => SizedBox(
                      width: 42,
                      height: 42,
                      child: ClipOval(
                        child:
                            profileController.avatarImageUrl.value
                                .trim()
                                .isNotEmpty
                            ? AppCachedImage(
                                imageUrl:
                                    profileController.avatarImageUrl.value,
                                width: 42,
                                height: 42,
                              )
                            : const CircleAvatar(
                                backgroundColor: Color(0xFFE7E3E1),
                                child: AppHeroIconData(
                                  Icons.person_rounded,
                                  color: AppColors.hintText,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [AppColors.primary, Color(0xFFFF8A5B)],
                    ).createShader(bounds),
                    child: Text(
                      'Messages',
                      style: AppFonts.plusJakarta(
                        size: 24,
                        weight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Get.to<void>(() => const SettingsScreen()),
                  icon: const AppHeroIconData(Icons.settings_rounded),
                  color: AppColors.hintText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.thread, required this.onTap});

  final ChatThreadModel thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasPreview = thread.lastMessage.trim().isNotEmpty;
    final isUnread = thread.hasUnread;
    final hasTimeLabel = thread.lastMessageTimeLabel.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        splashColor: AppColors.primary.withValues(alpha: 0.08),
        highlightColor: AppColors.primary.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          decoration: BoxDecoration(
            color: isUnread
                ? Colors.white.withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: isUnread
                  ? AppColors.primary.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.75),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: (isUnread ? AppColors.primary : const Color(0xFF2F2F2E))
                    .withValues(alpha: isUnread ? 0.14 : 0.07),
                blurRadius: 26,
                offset: const Offset(0, 12),
                spreadRadius: -16,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(thread: thread),
              const SizedBox(width: 13),
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
                                  thread.user.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppFonts.plusJakarta(
                                    size: 16,
                                    weight: FontWeight.w800,
                                    letterSpacing: -0.1,
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                              VerifiedBadgeSlot(
                                username: thread.user.username,
                                fallback: thread.user.isVerifiedBadge,
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                        if (hasTimeLabel) ...[
                          const SizedBox(width: 8),
                          _Pill(
                            label: thread.lastMessageTimeLabel,
                            background: const Color(0xFFF4EEEC),
                            foreground: AppColors.hintText,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hasPreview
                                ? InAppSharePayload.previewText(
                                    thread.lastMessage,
                                  )
                                : 'Tap to start chatting',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.beVietnam(
                              size: 13.5,
                              weight: isUnread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isUnread
                                  ? AppColors.text
                                  : hasPreview
                                  ? AppColors.hintText
                                  : AppColors.hintText.withValues(alpha: 0.78),
                            ),
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 8),
                          _UnreadBadge(count: thread.unreadCount),
                        ],
                      ],
                    ),
                    if (thread.isBlocked ||
                        thread.isStopped ||
                        thread.isIncomingRequest) ...[
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          if (thread.isIncomingRequest)
                            const _Pill(
                              label: 'Request',
                              background: Color(0xFFFFF4E5),
                              foreground: Color(0xFFB45309),
                              fontSize: 10,
                            ),
                          if (thread.isIncomingRequest &&
                              (thread.isBlocked || thread.isStopped))
                            const SizedBox(width: 6),
                          if (thread.isBlockedByMe)
                            _Pill(
                              label: 'Blocked',
                              background: const Color(0xFFFDECEC),
                              foreground: const Color(0xFFB42318),
                              fontSize: 10,
                            )
                          else if (thread.isBlockedByOther)
                            _Pill(
                              label: 'Blocked you',
                              background: const Color(0xFFFDECEC),
                              foreground: const Color(0xFFB42318),
                              fontSize: 10,
                            )
                          else if (thread.isStopped)
                            _Pill(
                              label: 'Messaging stopped',
                              background: const Color(0xFFFDECEC),
                              foreground: const Color(0xFFB42318),
                              fontSize: 10,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Framed avatar with a thin white gap before the photo.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.thread});

  final ChatThreadModel thread;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              padding: const EdgeInsets.all(2.4),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    Color(0xFFFF8A5B),
                    AppColors.accent,
                  ],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(1.6),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: ClipOval(
                  child: thread.user.imageUrl.trim().isNotEmpty
                      ? AppCachedImage(
                          imageUrl: thread.user.imageUrl,
                          width: 50,
                          height: 50,
                        )
                      : Container(
                          color: const Color(0xFFF1EBE8),
                          alignment: Alignment.center,
                          child: const AppHeroIconData(
                            Icons.person_rounded,
                            color: AppColors.hintText,
                            size: 22,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      constraints: const BoxConstraints(minWidth: 21),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFFFF8A5B)],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        textAlign: TextAlign.center,
        style: AppFonts.beVietnam(
          size: 11,
          weight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _ChatListShimmer extends StatelessWidget {
  const _ChatListShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List<Widget>.generate(
        6,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: _softCardDecoration(),
            child: Row(
              children: const [
                AppShimmerBox(
                  width: 56,
                  height: 56,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppShimmerBox(
                        width: 110,
                        height: 16,
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      SizedBox(height: 8),
                      AppShimmerBox(
                        height: 12,
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                AppShimmerBox(
                  width: 36,
                  height: 12,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
