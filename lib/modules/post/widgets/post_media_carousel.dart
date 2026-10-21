import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/double_tap_zoom.dart';

class PostMediaCarousel extends StatefulWidget {
  const PostMediaCarousel({
    super.key,
    required this.imageUrls,
    this.memCacheWidth,
    this.dotsBottom = 12,
    this.counterOnLeft = false,
    this.onImageTap,
    this.onDoubleTapLike,
    this.initialPage = 0,
    this.onPageChanged,
  });

  final List<String> imageUrls;
  final int? memCacheWidth;
  final double dotsBottom;
  final bool counterOnLeft;
  final VoidCallback? onImageTap;
  final VoidCallback? onDoubleTapLike;
  final int initialPage;
  final ValueChanged<int>? onPageChanged;

  @override
  State<PostMediaCarousel> createState() => _PostMediaCarouselState();
}

class _CarouselSlide extends StatelessWidget {
  const _CarouselSlide({required this.url, this.memCacheWidth});

  final String url;
  final int? memCacheWidth;

  @override
  Widget build(BuildContext context) {
    final remote = url.startsWith('http://') || url.startsWith('https://');
    if (!remote) {
      final path = url.startsWith('file://') ? url.substring(7) : url;
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    return AppCachedImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: memCacheWidth,
    );
  }
}

class _PostMediaCarouselState extends State<PostMediaCarousel> {
  late final PageController _pageController;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage.clamp(0, widget.imageUrls.length - 1);
    _pageController = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.imageUrls.length;
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: count,
          onPageChanged: (index) {
            setState(() => _page = index);
            widget.onPageChanged?.call(index);
          },
          itemBuilder: (context, index) {
            return DoubleTapZoom(
              onTap: widget.onImageTap,
              onDoubleTapLike: widget.onDoubleTapLike,
              child: _CarouselSlide(
                url: widget.imageUrls[index],
                memCacheWidth: widget.memCacheWidth,
              ),
            );
          },
        ),
        Positioned(
          top: 12,
          left: widget.counterOnLeft ? 12 : null,
          right: widget.counterOnLeft ? null : 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${_page + 1}/$count',
              style: AppFonts.beVietnam(
                size: 11,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: widget.dotsBottom,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < count && i < 10; i++)
                Container(
                  width: i == _page ? 7 : 5,
                  height: i == _page ? 7 : 5,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _page
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.45),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
