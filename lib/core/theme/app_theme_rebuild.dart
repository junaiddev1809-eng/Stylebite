import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_theme_controller.dart';

/// Rebuilds [builder] whenever appearance mode changes.
///
/// Needed because most StyleBite widgets paint via [AppColors] getters rather
/// than [Theme.of], so a MaterialApp theme swap alone will not repaint them.
class AppThemeRebuild extends StatelessWidget {
  const AppThemeRebuild({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      AppThemeController.watchRevision;
      return builder(context);
    });
  }
}
