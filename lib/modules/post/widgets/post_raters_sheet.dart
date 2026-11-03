import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/api_helper.dart';
import '../../../core/utils/verified_badge_hydrator.dart';
import '../../../core/utils/verified_flag.dart';
import '../../../core/widgets/app_user_avatar.dart';
import '../../../core/widgets/app_verified_badge.dart';
import '../../profile/models/profile_model.dart';
import '../../profile/utils/profile_open_helper.dart';

Future<void> showPostRatersSheet(
  BuildContext context, {
  required String postId,
  bool isReel = false,
  String? ratingCountLabel,
  double? ratingAvg,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PostRatersSheet(
      postId: postId,
      isReel: isReel,
      ratingCountLabel: ratingCountLabel,
      ratingAvg: ratingAvg,
    ),
  );
}

class PostRatersSheet extends StatefulWidget {
  const PostRatersSheet({
    super.key,
    required this.postId,
    this.isReel = false,
    this.ratingCountLabel,
    this.ratingAvg,
  });

  final String postId;
  final bool isReel;
  final String? ratingCountLabel;
  final double? ratingAvg;

  @override
  State<PostRatersSheet> createState() => _PostRatersSheetState();
}

class _PostRatersSheetState extends State<PostRatersSheet> {
  final ScrollController _scrollController = ScrollController();
  final List<_PostRater> _raters = <_PostRater>[];

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasError = false;
  bool _hasMore = true;
  String _errorMessage = '';
  int _page = 0;
  int _totalRatings = 0;
  double? _ratingAvg;

  @override
  void initState() {
    super.initState();
    _ratingAvg = widget.ratingAvg;
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
        _isLoading = _raters.isEmpty;
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
        '$base/${widget.postId}/ratings?page=$nextPage&per_page=20',
      );
      if (response == null) {
        throw Exception('Could not reach the ratings API.');
      }
      if (response.statusCode == 404 || response.statusCode == 500) {
        // Live servers that do not have this route yet return a generic 500
        // for unknown paths (same as a missing likes typo).
        throw Exception(
          'Ratings list is not on the live API yet. Deploy the backend ratings route, then hot-restart.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Could not load ratings (${response.statusCode}).',
        );
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        throw Exception('Could not load ratings.');
      }
      if (payload['status_code'] != 1 && payload['status_code'] != '1') {
        throw Exception(
          (payload['message'] ?? 'Could not load ratings.').toString(),
        );
      }

      final map = asStringKeyedMap(payload);
      final listRaw = map['ratings'] ?? map['raters'];
      final parsed = <_PostRater>[];
      if (listRaw is List) {
        for (final item in listRaw) {
          if (item is Map) {
            parsed.add(_PostRater.fromMap(asStringKeyedMap(item)));
          }
        }
      }

      final pagination = ProfilePaginationModel.fromMap(
        asStringKeyedMap(map['pagination']),
      );
      final ratingCount = (map['rating_count'] as num?)?.toInt();
      final ratingAvg = (map['rating_avg'] as num?)?.toDouble();

      if (!mounted) {
        return;
      }
      setState(() {
        if (reset) {
          _raters
            ..clear()
            ..addAll(parsed);
        } else {
          _raters.addAll(parsed);
        }
        _page = pagination.currentPage == 0 ? nextPage : pagination.currentPage;
        _hasMore = pagination.hasMorePages;
        _totalRatings = ratingCount ?? _totalRatings;
        if (ratingAvg != null) {
          _ratingAvg = ratingAvg;
        }
        _isLoading = false;
        _isLoadingMore = false;
        _hasError = false;
      });
      VerifiedBadgeHydrator.hydrate(parsed.map((user) => user.username));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        if (reset && _raters.isEmpty) {
          _hasError = true;
          _errorMessage = error.toString().replaceFirst('Exception: ', '');
        }
      });
    }
  }

  String get _title {
    final fromApi = _totalRatings > 0 ? _totalRatings.toString() : '';
    final label = (widget.ratingCountLabel ?? '').trim();
    final count = fromApi.isNotEmpty
        ? fromApi
        : (label.isNotEmpty && label != '0' ? label : '');
    if (count.isEmpty) {
      return 'Ratings';
    }
    return 'Ratings ($count)';
  }

  String? get _subtitle {
    final avg = _ratingAvg;
    if (avg == null || avg <= 0) {
      return null;
    }
    return 'Average ${avg.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _subtitle;
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.75,
      decoration: BoxDecoration(
        color: AppColors.surface,
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
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppFonts.beVietnam(
                size: 13,
                weight: FontWeight.w500,
                color: AppColors.hintText,
              ),
            ),
          ],
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
                _errorMessage.isEmpty
                    ? 'Could not load ratings.'
                    : _errorMessage,
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
    if (_raters.isEmpty) {
      return Center(
        child: Text(
          'No ratings yet',
          style: AppFonts.beVietnam(color: AppColors.hintText),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _raters.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (index >= _raters.length) {
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
        return _RaterTile(rater: _raters[index]);
      },
    );
  }
}

class _PostRater {
  const _PostRater({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.isVerified,
    required this.isSelf,
    required this.isFollowing,
    required this.ratingValue,
  });

  final int id;
  final String username;
  final String displayName;
  final String avatarUrl;
  final bool isVerified;
  final bool isSelf;
  final bool isFollowing;
  final int ratingValue;

  factory _PostRater.fromMap(Map<String, dynamic> map) {
    final username = (map['username'] ?? '')
        .toString()
        .trim()
        .replaceFirst('@', '');
    final relationship = asStringKeyedMap(map['relationship']);
    return _PostRater(
      id: (map['id'] as num?)?.toInt() ?? 0,
      username: username,
      displayName: (map['display_name'] ?? map['full_name'] ?? username)
          .toString(),
      avatarUrl: (map['avatar_url'] ?? '').toString(),
      isVerified: VerifiedBadgeCache.resolve(
        username,
        parseVerifiedFlag(map),
      ),
      isSelf: _asBool(map['is_self']),
      isFollowing: _asBool(
        relationship['is_following'] ?? map['is_following'],
      ),
      ratingValue: ((map['rating_value'] as num?)?.toInt() ?? 0).clamp(1, 5),
    );
  }

  static bool _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final raw = (value ?? '').toString().trim().toLowerCase();
    return raw == 'true' || raw == '1' || raw == 'yes';
  }
}

class _RaterTile extends StatelessWidget {
  const _RaterTile({required this.rater});

  final _PostRater rater;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).maybePop();
        ProfileOpenHelper.open(
          username: rater.username,
          initialIsFollowing: rater.isFollowing,
          avatarUrl: rater.avatarUrl,
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            AppUserAvatar(imageUrl: rater.avatarUrl, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppVerifiedName(
                    name: rater.displayName.isNotEmpty
                        ? rater.displayName
                        : rater.username,
                    username: rater.username,
                    isVerified: rater.isVerified,
                    badgeSize: 15,
                    style: AppFonts.beVietnam(
                      size: 14,
                      weight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    '@${rater.username}',
                    style: AppFonts.beVietnam(
                      size: 12,
                      weight: FontWeight.w500,
                      color: AppColors.hintText,
                    ),
                  ),
                ],
              ),
            ),
            if (rater.isSelf) ...[
              Text(
                'You',
                style: AppFonts.beVietnam(
                  size: 12,
                  weight: FontWeight.w700,
                  color: AppColors.hintText,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${rater.ratingValue}',
                    style: AppFonts.beVietnam(
                      size: 13,
                      weight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
