import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/api_helper.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../models/profile_model.dart';
import '../utils/profile_page_transition.dart';
import 'user_profile_screen.dart';

class UserProfileCoverScreen extends StatefulWidget {
  const UserProfileCoverScreen({
    super.key,
    required this.username,
    this.initialIsFollowing = false,
  });

  final String username;
  final bool initialIsFollowing;

  @override
  State<UserProfileCoverScreen> createState() => _UserProfileCoverScreenState();
}

class _UserProfileCoverScreenState extends State<UserProfileCoverScreen> {
  double? _startY;
  bool _opened = false;
  double _swipeProgress = 0;

  /// Never seed wallpaper from avatar — that causes a brief wrong/old flash
  /// before the overview cover URL arrives.
  String _coverUrl = '';
  bool _loadingCover = true;

  @override
  void initState() {
    super.initState();
    _loadCover();
  }

  Future<void> _loadCover() async {
    try {
      final uri = Uri(
        path: 'profiles/${Uri.encodeComponent(widget.username)}/overview',
        queryParameters: const {'per_page': '1'},
      );
      final response = await ApiHelper.fetchDataWithAuthorization(
        uri.toString(),
      );
      if (!mounted) {
        return;
      }
      if (response == null) {
        setState(() => _loadingCover = false);
        return;
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        setState(() => _loadingCover = false);
        return;
      }
      if (payload['status_code'] != 1 && payload['status_code'] != '1') {
        setState(() => _loadingCover = false);
        return;
      }
      final user = ProfileOverviewResponseModel.fromMap(payload).overview.user;
      final next = user.coverUrl.trim();
      setState(() {
        _coverUrl = next;
        _loadingCover = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingCover = false);
      }
    }
  }

  void _openDetails() {
    if (_opened) {
      return;
    }
    _opened = true;
    Navigator.of(context, rootNavigator: true)
        .push<void>(
          ProfilePageTransition.to(
            UserProfileScreen(
              username: widget.username,
              initialIsFollowing: widget.initialIsFollowing,
            ),
          ),
        )
        .whenComplete(() {
          FocusManager.instance.primaryFocus?.unfocus();
          if (mounted) {
            setState(() {
              _opened = false;
              _swipeProgress = 0;
            });
          } else {
            _opened = false;
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent && event.scrollDelta.dy > 40) {
            _openDetails();
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (details) => _startY = details.globalPosition.dy,
          onVerticalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity < -450) {
              _openDetails();
            }
            if (mounted) {
              setState(() => _swipeProgress = 0);
            }
            _startY = null;
          },
          onVerticalDragUpdate: (details) {
            if (_startY == null) {
              return;
            }
            final deltaY = _startY! - details.globalPosition.dy;
            if (mounted) {
              setState(() => _swipeProgress = (deltaY / 100).clamp(0, 1));
            }
            if (deltaY > 65) {
              _startY = null;
              _openDetails();
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                curve: Curves.easeOutCubic,
                child: Transform.translate(
                  offset: Offset(0, -22 * _swipeProgress),
                  child: Transform.scale(
                    scale: 1 + (0.03 * _swipeProgress),
                    child: _buildCoverLayer(),
                  ),
                ),
              ),
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Color.fromRGBO(0, 0, 0, 0.62),
                        Color.fromRGBO(0, 0, 0, 0.12),
                        Color.fromRGBO(0, 0, 0, 0.2),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                top: topInset + 4,
                child: IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const AppHeroIconData(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: bottomInset + 36,
                child: Center(child: _buildSwipeIndicator()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverLayer() {
    if (_loadingCover) {
      return _placeholder(
        child: const CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      );
    }
    if (_coverUrl.isEmpty) {
      return _placeholder();
    }
    return KeyedSubtree(
      key: ValueKey<String>(_coverUrl),
      child: AppCachedImage(
        imageUrl: _coverUrl,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }

  Widget _placeholder({Widget? child}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            const Color(0xFF0D0D0D),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: child ??
          const AppHeroIconData(
            Icons.person_rounded,
            color: Colors.white70,
            size: 64,
          ),
    );
  }

  Widget _buildSwipeIndicator() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.96, end: 1.04),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value + (_swipeProgress * 0.08),
          child: Opacity(
            opacity: 0.72 + (_swipeProgress * 0.28),
            child: child,
          ),
        );
      },
      child: SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: Colors.white.withValues(alpha: 0.15),
          shape: const CircleBorder(
            side: BorderSide(color: Color.fromRGBO(255, 255, 255, 0.4)),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _openDetails,
            child: const AppHeroIconData(
              HeroIcons.arrowUp,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
