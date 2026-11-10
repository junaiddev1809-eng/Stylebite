import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import 'picked_media.dart';
import 'stylebite_editor_chrome.dart';
import 'stylebite_editor_looks.dart';
import 'stylebite_filter_baker.dart';
import 'stylebite_look_strip.dart';

/// Pick one StyleBite look + intensity, then bake it onto every carousel slide.
class StyleBiteCarouselLookScreen extends StatefulWidget {
  const StyleBiteCarouselLookScreen({super.key, required this.images});

  final List<PickedMedia> images;

  @override
  State<StyleBiteCarouselLookScreen> createState() =>
      _StyleBiteCarouselLookScreenState();
}

class _StyleBiteCarouselLookScreenState
    extends State<StyleBiteCarouselLookScreen> {
  static const _canvas = StyleBiteEditorChrome.canvas;

  late FilterModel _look = StyleBiteEditorLooks.all.first;
  double _intensity = 0.7;
  var _applying = false;
  var _comparing = false;

  File get _previewFile => widget.images.first.file;

  Future<void> _apply() async {
    if (_applying) return;
    setState(() => _applying = true);

    final out = <PickedMedia>[];
    for (final slide in widget.images) {
      final baked = await StyleBiteFilterBaker.bake(
        source: slide.file,
        look: _look,
        intensity: _intensity,
      );
      if (baked == null) {
        out.add(slide);
      } else {
        out.add(PickedMedia(file: baked, type: slide.type));
      }
    }

    if (!mounted) return;
    Get.back(result: out);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_applying,
      child: Scaffold(
        backgroundColor: _canvas,
        appBar: AppBar(
          backgroundColor: _canvas,
          foregroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: !_applying,
          title: Text(
            'Apply look to all',
            style: AppFonts.plusJakarta(
              size: 16,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          actions: [
            TextButton(
              onPressed: _applying ? null : _apply,
              child: Text(
                'Done',
                style: AppFonts.plusJakarta(
                  size: 15,
                  weight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ColoredBox(
                      color: StyleBiteEditorChrome.elevated,
                      child: GestureDetector(
                        onLongPressStart: _applying
                            ? null
                            : (_) => setState(() => _comparing = true),
                        onLongPressEnd: _applying
                            ? null
                            : (_) => setState(() => _comparing = false),
                        child: Center(
                          child: _comparing
                              ? Image.file(_previewFile, fit: BoxFit.contain)
                              : ColorFiltered(
                                  colorFilter: ColorFilter.matrix(
                                    StyleBiteFilterBaker.matrixFor(
                                      _look,
                                      _intensity,
                                    ),
                                  ),
                                  child: Image.file(
                                    _previewFile,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                _comparing
                    ? 'Original'
                    : 'Hold image to compare · long-press look to favorite',
                style: AppFonts.plusJakarta(
                  size: 11,
                  weight: FontWeight.w500,
                  color: Colors.white54,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Row(
                  children: [
                    Text(
                      'Intensity',
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
              ),
              IgnorePointer(
                ignoring: _applying,
                child: StyleBiteLookStrip(
                  selected: _look,
                  onSelected: (look) => setState(() => _look = look),
                ),
              ),
              if (_applying)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              else
                const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
