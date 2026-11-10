import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import 'stylebite_background_blur.dart';
import 'stylebite_editor_chrome.dart';

/// Opens background-blur sheet and writes the result into the live editor.
Future<void> showStyleBiteBackgroundBlur(
  BuildContext context,
  ProImageEditorState editor,
) async {
  final bg = editor.editorImage;
  if (bg == null) return;

  final source = await bg.safeByteArray(context);
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BackgroundBlurSheet(
      sourceBytes: source,
      onApply: (bytes) async {
        await editor.updateBackgroundImage(
          EditorImage(byteArray: bytes),
        );
      },
    ),
  );
}

class _BackgroundBlurSheet extends StatefulWidget {
  const _BackgroundBlurSheet({
    required this.sourceBytes,
    required this.onApply,
  });

  final Uint8List sourceBytes;
  final Future<void> Function(Uint8List bytes) onApply;

  @override
  State<_BackgroundBlurSheet> createState() => _BackgroundBlurSheetState();
}

class _BackgroundBlurSheetState extends State<_BackgroundBlurSheet> {
  double _intensity = 0.65;
  var _applying = false;

  Future<void> _apply() async {
    if (_applying) return;
    setState(() => _applying = true);
    try {
      final baked = await StyleBiteBackgroundBlur.bake(
        sourceBytes: widget.sourceBytes,
        intensity: _intensity,
      );
      if (!mounted) return;
      if (baked != null) {
        await widget.onApply(baked);
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final sigma = 4.0 + _intensity * 16.0;
    final focusRadius = 0.42 + (1.0 - _intensity) * 0.38;

    return Container(
      decoration: const BoxDecoration(
        color: StyleBiteEditorChrome.bar,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Background blur',
            style: AppFonts.plusJakarta(
              size: 16,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Keeps the subject sharp · softens the rest',
            style: AppFonts.plusJakarta(
              size: 12,
              weight: FontWeight.w500,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 1,
              child: ColoredBox(
                color: StyleBiteEditorChrome.elevated,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(
                        sigmaX: sigma,
                        sigmaY: sigma,
                        tileMode: TileMode.clamp,
                      ),
                      child: Image.memory(
                        widget.sourceBytes,
                        fit: BoxFit.contain,
                      ),
                    ),
                    ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (rect) => RadialGradient(
                        center: Alignment.center,
                        radius: focusRadius,
                        colors: const [
                          Color(0xFFFFFFFF),
                          Color(0xFFFFFFFF),
                          Color(0x00FFFFFF),
                        ],
                        stops: const [0.0, 0.38, 1.0],
                      ).createShader(rect),
                      child: Image.memory(
                        widget.sourceBytes,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Amount',
                style: AppFonts.plusJakarta(
                  size: 13,
                  weight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              Expanded(
                child: Slider(
                  value: _intensity,
                  onChanged: _applying
                      ? null
                      : (v) => setState(() => _intensity = v),
                  activeColor: AppColors.primary,
                  inactiveColor: Colors.white24,
                ),
              ),
              Text(
                '${(_intensity * 100).round()}%',
                style: AppFonts.plusJakarta(
                  size: 12,
                  weight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _applying ? null : _apply,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _applying
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Apply blur',
                      style: AppFonts.plusJakarta(
                        size: 15,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
