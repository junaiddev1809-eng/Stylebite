import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_theme_controller.dart';

class AppColors {
  AppColors._();

  // Brand — identical in light and dark; safe for `const` widgets.
  static const Color primary = Color(0xFFFF4D6D);
  static const Color secondary = Color(0xFFFF8A5B);
  static const Color accent = Color(0xFFFFD166);
  static const Color success = Colors.green;
  static const Color error = Colors.red;

  /// Frozen light anchors for rare true-const / launch parity needs.
  static const Color backgroundLight = Color(0xFFF9F6F5);
  static const Color textLight = Color(0xFF2F2F2E);
  static const Color hintTextLight = Color(0xFF5C5B5B);

  static StyleBitePalette get themed => AppThemeController.paletteOrLight;

  /// Active surfaces — follow Settings appearance (default light = old look).
  static Color get background => themed.background;
  static Color get surface => themed.surface;
  static Color get card => themed.card;
  static Color get cardBorder => themed.cardBorder;
  static Color get text => themed.text;
  static Color get hintText => themed.hintText;
  static Color get divider => themed.divider;
  static Color get navBar => themed.navBar;
  static Color get chip => themed.chip;
  static Color get inputFill => themed.inputFill;

  // Backward-compatible aliases used during the first migration pass.
  static Color get backgroundThemed => background;
  static Color get textThemed => text;
  static Color get hintTextThemed => hintText;
  static Color get cardThemed => card;
  static Color get cardBorderThemed => cardBorder;
}
