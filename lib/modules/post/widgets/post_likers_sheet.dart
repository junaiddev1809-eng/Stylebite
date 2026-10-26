import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/api_helper.dart';
import '../../../core/utils/verified_badge_hydrator.dart';
import '../../../core/utils/verified_flag.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/app_verified_badge.dart';
import '../../profile/models/follower_model.dart';
import '../../profile/models/profile_model.dart';
import '../../profile/utils/profile_open_helper.dart';

Future<void> showPostLikersSheet(
  BuildContext context, {
  required String postId,
  bool isReel = false,
  String? likeCountLabel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PostLikersSheet(
      postId: postId,
      isReel: isReel,
      likeCountLabel: likeCountLabel,
    ),
  );
}

class PostLikersSheet extends StatefulWidget {
  const PostLikersSheet({
    super.key,
    required this.postId,
    this.isReel = false,
    this.likeCountLabel,
  });

  final String postId;
  final bool isReel;
  final String? likeCountLabel;

  @override
  State<PostLikersSheet> createState() => _PostLikersSheetState();
}

class _PostLikersSheetState extends State<PostLikersSheet> {
  final ScrollController _scrollController = ScrollController();
  final List<FollowerModel> _users = <FollowerModel>[];

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasError = false;
  bool _hasMore = true;
  String _errorMessage = '';
  int _page = 0;
  int _totalLikes = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetch(reset: true);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore) {
      return;
    }
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _fetch();
    }
  }

  Future<void> _fetch({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = _users.isEmpty;
        _hasError = false;
        _errorMessage = '';
        _page = 0;
        _hasMore = true;
      });
    } else {
      if (_isLoadingMore || !_hasMore) {
        return;
      }
      setState(() => _isLoadingMore = true);
    }

    try {
      final nextPage = _page + 1;
      final base = widget.isReel ? 'reels' : 'feed/posts';
      final response = await ApiHelper.fetchDataWithAuthorization(
        '$base/${widget.postId}/likes?page=$nextPage&per_page=20',
      );
      if (response == null ||
          response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception('Could not load likes.');
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        throw Exception('Could not load likes.');
      }
      if (payload['status_code'] != 1 && payload['status_code'] != '1') {
        throw Exception(
          (payload['message'] ?? 'Could not load likes.').toString(),
        );
      }

      final parsed = FollowerListResponseModel.fromJson(payload);
      final likeCount = (payload['like_count'] as num?)?.toInt();
      final pagination = parsed.pagination.currentPage > 0
          ? parsed.pagination
          : ProfilePaginationModel.fromMap(
              asStringKeyedMap(payload['pagination']),
            );

      if (!mounted) {
        return;
      }
      setState(() {
        if (reset) {
          _users
            ..clear()
            ..addAll(parsed.data);
        } else {
          _users.addAll(parsed.data);
        }
        _page = pagination.currentPage == 0 ? nextPage : pagination.currentPage;
        _hasMore = pagination.hasMorePages;
        _totalLikes = likeCount ?? _totalLikes;
        _isLoading = false;
        _isLoadingMore = false;
        _hasError = false;
      });
      VerifiedBadgeHydrator.hydrate(parsed.data.map((user) => user.username));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        if (reset && _users.isEmpty) {
          _hasError = true;
          _errorMessage = error.toString().replaceFirst('Exception: ', '');
        }
      });
    }
  }

  String get _title {
    final fromApi = _totalLikes > 0 ? _totalLikes.toString() : '';
    final label = (widget.likeCountLabel ?? '').trim();
    final count = fromApi.isNotEmpty
        ? fromApi
        : (label.isNotEmpty && label != '0' ? label : '');
    if (count.isEmpty) {
      return 'Likes';
    }
    return 'Likes ($count)';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.hintText.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _title,
            style: AppFonts.plusJakarta(
              size: 18,
              weight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage.isEmpty ? 'Could not load likes.' : _errorMessage,
                textAlign: TextAlign.center,
                style: AppFonts.beVietnam(color: AppColors.hintText),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _fetch(reset: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_users.isEmpty) {
      return Center(
        child: Text(
          'No likes yet',
          style: AppFonts.beVietnam(color: AppColors.hintText),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _users.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (index >= _users.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          );
        }
        final user = _users[index];
        return _LikerTile(user: user);
      },
    );
  }
}

class _LikerTile extends StatelessWidget {
  const _LikerTile({required this.user});

  final FollowerModel user;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).maybePop();
        ProfileOpenHelper.open(
          username: user.username,
          initialIsFollowing: user.isFollowing,
          avatarUrl: user.avatarUrl,
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            AppCachedImage(
              imageUrl: user.avatarUrl,
              width: 48,
              height: 48,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppVerifiedName(
                    name: user.displayName.isNotEmpty
                        ? user.displayName
                        : user.username,
                    username: user.username,
                    isVerified: user.isVerified,
                    badgeSize: 15,
                    style: AppFonts.beVietnam(
                      size: 14,
                      weight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    '@${user.username}',
                    style: AppFonts.beVietnam(
                      size: 12,
                      weight: FontWeight.w500,
                      color: AppColors.hintText,
                    ),
                  ),
                ],
              ),
            ),
            if (user.isSelf)
              Text(
                'You',
                style: AppFonts.beVietnam(
                  size: 12,
                  weight: FontWeight.w700,
                  color: AppColors.hintText,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
