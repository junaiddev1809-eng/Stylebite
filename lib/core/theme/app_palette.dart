import 'package:flutter/material.dart';

/// Semantic StyleBite colors for one appearance (light or dark).
/// Brand coral/orange stay shared; surfaces and text flip per mode.
@immutable
class StyleBitePalette {
  const StyleBitePalette({
    required this.background,
    required this.surface,
    required this.card,
    required this.cardBorder,
    required this.text,
    required this.hintText,
    required this.divider,
    required this.navBar,
    required this.chip,
    required this.inputFill,
    required this.statusBarIconBrightness,
    required this.systemNavIconBrightness,
  });

  final Color background;
  final Color surface;
  final Color card;
  final Color cardBorder;
  final Color text;
  final Color hintText;
  final Color divider;
  final Color navBar;
  final Color chip;
  final Color inputFill;
  final Brightness statusBarIconBrightness;
  final Brightness systemNavIconBrightness;

  /// Exact current production light look — do not drift these values.
  static const light = StyleBitePalette(
    background: Color(0xFFF9F6F5),
    surface: Color(0xFFFFFFFF),
    card: Color.fromRGBO(255, 255, 255, 0.92),
    cardBorder: Color.fromRGBO(47, 47, 46, 0.12),
    text: Color(0xFF2F2F2E),
    hintText: Color(0xFF5C5B5B),
    divider: Color.fromRGBO(47, 47, 46, 0.08),
    navBar: Color.fromRGBO(255, 255, 255, 0.98),
    chip: Color(0xFFE7E7E7),
    inputFill: Color(0xFFFFFFFF),
    statusBarIconBrightness: Brightness.dark,
    systemNavIconBrightness: Brightness.dark,
  );

  /// Warm espresso dark — same family as cream light, never pure black/white slabs.
  /// Borders are a bit stronger than light so chips/buttons stay readable.
  static const dark = StyleBitePalette(
    background: Color(0xFF1A1715),
    surface: Color(0xFF25211E),
    card: Color(0xFF2F2A26),
    cardBorder: Color.fromRGBO(255, 244, 236, 0.22),
    text: Color(0xFFF6F1EC),
    hintText: Color(0xFFB0A8A1),
    divider: Color.fromRGBO(246, 241, 236, 0.16),
    navBar: Color(0xFF25211E),
    chip: Color(0xFF3A342F),
    inputFill: Color(0xFF2F2A26),
    statusBarIconBrightness: Brightness.light,
    systemNavIconBrightness: Brightness.light,
  );
}
