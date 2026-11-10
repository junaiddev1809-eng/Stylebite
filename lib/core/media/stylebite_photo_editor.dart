import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import 'stylebite_editor_configs.dart';
import 'stylebite_editor_looks.dart';

/// Instagram-inspired photo editor: filter-first, Lux/Structure tune tray.
///
/// Cancel/back returns null; Done returns edited JPEG bytes.
class StyleBitePhotoEditor extends StatelessWidget {
  const StyleBitePhotoEditor({
    super.key,
    required this.file,
    this.storyTools = false,
    this.hideFilters = false,
  });

  final File file;

  /// When true, unlocks Stories-style text / emoji / draw tools.
  final bool storyTools;

  /// When true (e.g. Flash already baked a look), hide the filter tool.
  final bool hideFilters;

  /// Shared curated looks (also used by video + carousel apply-all).
  static List<FilterModel> get curatedFilters => StyleBiteEditorLooks.all;

  @override
  Widget build(BuildContext context) {
    return ProImageEditor.file(
      file,
      configs: StyleBiteEditorConfigs.build(
        storyTools: storyTools,
        hideFilters: hideFilters,
      ),
      callbacks: ProImageEditorCallbacks(
        onImageEditingComplete: (bytes) async {
          Get.back(result: bytes);
        },
      ),
    );
  }
}
