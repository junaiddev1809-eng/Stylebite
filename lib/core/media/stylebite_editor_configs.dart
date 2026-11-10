import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import '../theme/app_colors.dart';
import 'stylebite_editor_chrome.dart';
import 'stylebite_editor_looks.dart';
import 'stylebite_story_emojis.dart';
import 'stylebite_story_stickers.dart';

/// Shared Instagram-inspired editor chrome + tools for photo and video.
class StyleBiteEditorConfigs {
  StyleBiteEditorConfigs._();

  static const Color canvas = StyleBiteEditorChrome.canvas;
  static const Color bar = StyleBiteEditorChrome.bar;
  static const Color muted = StyleBiteEditorChrome.muted;

  static ProImageEditorConfigs build({
    bool forVideo = false,
    bool storyTools = false,
    bool hideFilters = false,
  }) {
    final lightOverlay = SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: bar,
    );

    List<SubEditorMode> tools;
    if (forVideo) {
      tools = [
        if (!hideFilters) SubEditorMode.filter,
        SubEditorMode.tune,
        SubEditorMode.cropRotate,
      ];
    } else if (storyTools) {
      tools = [
        if (!hideFilters) SubEditorMode.filter,
        SubEditorMode.tune,
        SubEditorMode.cropRotate,
        SubEditorMode.text,
        SubEditorMode.emoji,
        SubEditorMode.sticker,
        SubEditorMode.paint,
      ];
    } else {
      tools = [
        if (!hideFilters) SubEditorMode.filter,
        SubEditorMode.tune,
        SubEditorMode.cropRotate,
      ];
    }

    return ProImageEditorConfigs(
      mainEditor: MainEditorConfigs(
        tools: tools,
        style: MainEditorStyle(
          background: canvas,
          bottomBarBackground: bar,
          bottomBarColor: Colors.white,
          appBarBackground: canvas,
          appBarColor: Colors.white,
          uiOverlayStyle: lightOverlay,
        ),
        widgets: StyleBiteEditorChrome.main(
          storyTools: storyTools,
          forVideo: forVideo,
          hideFilters: hideFilters,
        ),
      ),
      filterEditor: FilterEditorConfigs(
        enableMultiSelection: false,
        filterList: StyleBiteEditorLooks.all,
        style: FilterEditorStyle(
          background: canvas,
          appBarBackground: canvas,
          appBarColor: Colors.white,
          previewTextColor: muted,
          previewSelectedTextColor: AppColors.primary,
          filterListSpacing: 14,
          filterListMargin: const EdgeInsets.fromLTRB(14, 10, 14, 18),
          uiOverlayStyle: SystemUiOverlayStyle.light,
        ),
        widgets: FilterEditorWidgets(
          filterButton: (
            filter,
            isSelected,
            scaleFactor,
            onSelectFilter,
            editorImage,
            filterKey,
          ) {
            return StyleBiteEditorChrome.filterButton(
              filter: filter,
              isSelected: isSelected,
              scaleFactor: scaleFactor,
              onSelectFilter: onSelectFilter,
              editorImage: editorImage,
              filterKey: filterKey,
            );
          },
        ),
      ),
      tuneEditor: TuneEditorConfigs(
        tuneAdjustmentOptions: _instagramLikeTuneOptions(),
        style: const TuneEditorStyle(
          background: canvas,
          appBarBackground: canvas,
          appBarColor: Colors.white,
          bottomBarBackground: bar,
          bottomBarActiveItemColor: AppColors.primary,
          bottomBarInactiveItemColor: Colors.white70,
        ),
      ),
      cropRotateEditor: CropRotateEditorConfigs(
        // Keep package defaults: rotate / flip / tilt / aspect / reset.
        style: CropRotateEditorStyle(
          background: canvas,
          appBarBackground: canvas,
          appBarColor: Colors.white,
          bottomBarBackground: bar,
          bottomBarColor: Colors.white,
          cropCornerColor: AppColors.primary,
          uiOverlayStyle: lightOverlay,
        ),
      ),
      stickerEditor: storyTools
          ? StickerEditorConfigs(
              initWidth: 140,
              builder: StyleBiteStoryStickers.builder,
              style: const StickerEditorStyle(
                bottomSheetBackgroundColor: bar,
              ),
            )
          : const StickerEditorConfigs(),
      blurEditor: BlurEditorConfigs(
        style: BlurEditorStyle(
          background: canvas,
          appBarBackgroundColor: canvas,
          appBarForegroundColor: Colors.white,
          uiOverlayStyle: lightOverlay,
        ),
      ),
      textEditor: TextEditorConfigs(
        initFontSize: storyTools ? 42 : 28,
        initialPrimaryColor: storyTools ? Colors.white : Colors.white,
        style: const TextEditorStyle(
          background: Color(0xCC1A1517),
          appBarBackground: canvas,
          appBarColor: Colors.white,
          bottomBarBackground: bar,
          inputHintColor: muted,
          inputCursorColor: AppColors.primary,
        ),
      ),
      paintEditor: PaintEditorConfigs(
        style: PaintEditorStyle(
          background: canvas,
          appBarBackground: canvas,
          appBarColor: Colors.white,
          bottomBarBackground: bar,
          bottomBarActiveItemColor: AppColors.primary,
          bottomBarInactiveItemColor: Colors.white70,
          initialColor: AppColors.primary,
          uiOverlayStyle: lightOverlay,
        ),
      ),
      emojiEditor: EmojiEditorConfigs(
        // Keep modern glyphs — Android compatibility checks strip engaging ones.
        checkPlatformCompatibility: false,
        initScale: 6.5,
        emojiSet: StyleBiteStoryEmojis.set,
        style: EmojiEditorStyle(
          backgroundColor: bar,
          bottomActionBarConfig: BottomActionBarConfig(
            buttonIconColor: Colors.white70,
            backgroundColor: bar,
            buttonColor: bar,
            showBackspaceButton: false,
          ),
        ),
      ),
      videoEditor: forVideo
          ? const VideoEditorConfigs(
              initialMuted: false,
              initialPlay: false,
              isAudioSupported: true,
              minTrimDuration: Duration(milliseconds: 500),
              playTimeSmoothingDuration: Duration(milliseconds: 400),
            )
          : const VideoEditorConfigs(),
    );
  }

  /// IG Edit-tray inspired order: Lux≈exposure, warmth≈temperature, structure.
  static List<TuneAdjustmentItem> _instagramLikeTuneOptions() {
    const icons = TuneEditorIcons();
    return [
      TuneAdjustmentItem(
        id: 'lux',
        icon: Icons.wb_sunny_outlined,
        label: 'Lux',
        min: -1,
        max: 1,
        divisions: 200,
        toMatrix: ColorFilterAddons.exposure,
      ),
      TuneAdjustmentItem(
        id: 'brightness',
        icon: icons.brightness,
        label: 'Brightness',
        min: -0.5,
        max: 0.5,
        divisions: 200,
        labelMultiplier: 200,
        toMatrix: ColorFilterAddons.brightness,
      ),
      TuneAdjustmentItem(
        id: 'contrast',
        icon: icons.contrast,
        label: 'Contrast',
        min: -0.5,
        max: 0.5,
        divisions: 200,
        labelMultiplier: 200,
        toMatrix: ColorFilterAddons.contrast,
      ),
      TuneAdjustmentItem(
        id: 'structure',
        icon: Icons.auto_awesome_mosaic_outlined,
        label: 'Structure',
        min: -0.4,
        max: 0.4,
        divisions: 200,
        labelMultiplier: 250,
        toMatrix: (value) {
          // Structure ≈ mid contrast + light saturation (IG clarity feel).
          final contrast = ColorFilterAddons.contrast(value * 0.85);
          final sat = ColorFilterAddons.saturation(value * 0.35);
          return _multiply(contrast, sat);
        },
      ),
      TuneAdjustmentItem(
        id: 'warmth',
        icon: icons.temperature,
        label: 'Warmth',
        min: -0.5,
        max: 0.5,
        divisions: 200,
        labelMultiplier: 200,
        toMatrix: ColorFilterAddons.temperature,
      ),
      TuneAdjustmentItem(
        id: 'saturation',
        icon: icons.saturation,
        label: 'Saturation',
        min: -0.5,
        max: 0.5,
        divisions: 200,
        labelMultiplier: 200,
        toMatrix: ColorFilterAddons.saturation,
      ),
      TuneAdjustmentItem(
        id: 'color',
        icon: icons.hue,
        label: 'Color',
        min: -0.25,
        max: 0.25,
        divisions: 400,
        labelMultiplier: 400,
        toMatrix: ColorFilterAddons.hue,
      ),
      TuneAdjustmentItem(
        id: 'fade',
        icon: icons.fade,
        label: 'Fade',
        min: -1,
        max: 1,
        divisions: 200,
        toMatrix: ColorFilterAddons.fade,
      ),
      TuneAdjustmentItem(
        id: 'tint',
        icon: icons.tint,
        label: 'Tint',
        min: -0.5,
        max: 0.5,
        divisions: 200,
        labelMultiplier: 200,
        toMatrix: ColorFilterAddons.tint,
      ),
      TuneAdjustmentItem(
        id: 'highlights',
        icon: Icons.highlight_outlined,
        label: 'Highlights',
        min: -0.5,
        max: 0.5,
        divisions: 200,
        labelMultiplier: 200,
        toMatrix: (value) {
          // Lift/crush lighter tones via brightness + soft contrast.
          return ColorFilterAddons.brightness(value * 0.55);
        },
      ),
      TuneAdjustmentItem(
        id: 'shadows',
        icon: Icons.tonality,
        label: 'Shadows',
        min: -0.5,
        max: 0.5,
        divisions: 200,
        labelMultiplier: 200,
        toMatrix: (value) {
          // Open/crush shadows via exposure + fade blend.
          final exposure = ColorFilterAddons.exposure(value * 0.45);
          final fade = ColorFilterAddons.fade(value < 0 ? -value * 0.25 : 0);
          return _multiply(exposure, fade);
        },
      ),
      TuneAdjustmentItem(
        id: 'sharpen',
        icon: Icons.details_outlined,
        label: 'Sharpen',
        min: 0,
        max: 0.45,
        divisions: 180,
        labelMultiplier: 220,
        toMatrix: (value) {
          // Matrix approx of IG Sharpen: local contrast punch.
          return ColorFilterAddons.contrast(value);
        },
      ),
      TuneAdjustmentItem(
        id: 'vignette',
        icon: Icons.vignette_outlined,
        label: 'Vignette',
        min: 0,
        max: 0.7,
        divisions: 140,
        labelMultiplier: 140,
        toMatrix: (value) {
          // Soft edge falloff stand-in (true radial vignette needs a shader).
          final exposure = ColorFilterAddons.exposure(-value * 0.28);
          final fade = ColorFilterAddons.fade(value * 0.55);
          return _multiply(exposure, fade);
        },
      ),
    ];
  }

  static List<double> _multiply(List<double> a, List<double> b) {
    const size = 4;
    final result = List<double>.filled(20, 0);
    for (var row = 0; row < size; row++) {
      for (var col = 0; col < 5; col++) {
        var sum = col == 4 ? a[row * 5 + 4] : 0.0;
        for (var k = 0; k < size; k++) {
          sum += a[row * 5 + k] * b[k * 5 + col];
        }
        result[row * 5 + col] = sum;
      }
    }
    return result;
  }
}
