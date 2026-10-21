import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../home/models/home_post_model.dart';
import '../utils/hashtag_open_helper.dart';

class PostHashtagChips extends StatelessWidget {
  const PostHashtagChips({super.key, required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final visible = tags
        .map(normalizeHashtag)
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
    if (visible.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: visible
          .map(
            (tag) => Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => HashtagOpenHelper.open(tag),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: AppColors.primary.withValues(alpha: 0.12),
                  ),
                  child: Text(
                    tag,
                    style: AppFonts.beVietnam(
                      size: 12,
                      weight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class HashtagCaptionText extends StatefulWidget {
  const HashtagCaptionText({
    super.key,
    required this.text,
    required this.style,
    this.maxLines,
    this.overflow,
    this.enableTaps = true,
    this.onTapHashtag,
    this.onTapText,
  });

  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool enableTaps;
  final ValueChanged<String>? onTapHashtag;
  final VoidCallback? onTapText;

  static final RegExp hashtagPattern = RegExp(r'#[^\s#.,;:!?]+');

  @override
  State<HashtagCaptionText> createState() => _HashtagCaptionTextState();

  static List<InlineSpan> spansFor(String text, TextStyle style) {
    return _hashtagSpans(text, style);
  }

  static bool exceedsMaxLines({
    required String text,
    required TextStyle style,
    required int maxLines,
    required double maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(children: spansFor(text, style)),
      maxLines: maxLines,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }
}

class _HashtagCaptionTextState extends State<HashtagCaptionText> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];
  List<InlineSpan>? _spans;
  String? _builtText;
  TextStyle? _builtStyle;
  bool? _builtEnableTaps;
  ValueChanged<String>? _builtOnTapHashtag;
  VoidCallback? _builtOnTapText;

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_spans == null ||
        _builtText != widget.text ||
        _builtStyle != widget.style ||
        _builtEnableTaps != widget.enableTaps ||
        _builtOnTapHashtag != widget.onTapHashtag ||
        _builtOnTapText != widget.onTapText) {
      _disposeRecognizers();
      _builtText = widget.text;
      _builtStyle = widget.style;
      _builtEnableTaps = widget.enableTaps;
      _builtOnTapHashtag = widget.onTapHashtag;
      _builtOnTapText = widget.onTapText;
      _spans = _hashtagSpans(
        widget.text,
        widget.style,
        onTapHashtag: widget.enableTaps
            ? (widget.onTapHashtag ?? (tag) { HashtagOpenHelper.open(tag); })
            : null,
        onTapText: widget.onTapText,
        recognizers: widget.enableTaps || widget.onTapText != null
            ? _recognizers
            : null,
      );
    }
    return Text.rich(
      TextSpan(children: _spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow ?? TextOverflow.clip,
    );
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
    _spans = null;
  }
}

List<InlineSpan> _hashtagSpans(
  String text,
  TextStyle style, {
  ValueChanged<String>? onTapHashtag,
  VoidCallback? onTapText,
  List<TapGestureRecognizer>? recognizers,
}) {
  final hashtagStyle = style.copyWith(
    color: AppColors.primary,
    fontWeight: FontWeight.w700,
  );
  final spans = <InlineSpan>[];
  var start = 0;
  final tappable = <String>{};

  void addPlain(String value) {
    if (value.isEmpty) {
      return;
    }
    TapGestureRecognizer? recognizer;
    if (onTapText != null) {
      recognizer = TapGestureRecognizer()..onTap = onTapText;
      recognizers?.add(recognizer);
    }
    spans.add(TextSpan(text: value, style: style, recognizer: recognizer));
  }

  for (final match in HashtagCaptionText.hashtagPattern.allMatches(text)) {
    if (match.start > start) {
      addPlain(text.substring(start, match.start));
    }
    final tag = match.group(0) ?? '';
    final key = normalizeHashtag(tag).toLowerCase();
    final withinLimit =
        key.isNotEmpty &&
        (tappable.contains(key) || tappable.length < 5);
    if (withinLimit) {
      tappable.add(key);
    }
    TapGestureRecognizer? recognizer;
    if (withinLimit && onTapHashtag != null && tag.isNotEmpty) {
      recognizer = TapGestureRecognizer()..onTap = () => onTapHashtag(tag);
      recognizers?.add(recognizer);
    } else if (onTapText != null) {
      recognizer = TapGestureRecognizer()..onTap = onTapText;
      recognizers?.add(recognizer);
    }
    spans.add(
      TextSpan(
        text: tag,
        style: withinLimit ? hashtagStyle : style,
        recognizer: recognizer,
      ),
    );
    start = match.end;
  }
  if (start < text.length) {
    addPlain(text.substring(start));
  }
  if (spans.isEmpty) {
    addPlain(text);
  }
  return spans;
}
