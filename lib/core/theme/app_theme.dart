import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_fonts.dart';

class AppTheme {
  AppTheme._();

  static final ThemeData lightTheme = ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.light,
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.card,
        onSurface: AppColors.text,
        outline: AppColors.cardBorder,
        error: AppColors.error,
      ),
      textTheme: TextTheme(
        bodyMedium: AppFonts.beVietnam(
          size: 16,
          weight: FontWeight.w500,
          color: AppColors.text,
        ),
        bodySmall: AppFonts.beVietnam(
          size: 12,
          weight: FontWeight.w500,
          color: AppColors.hintText,
        ),
        titleMedium: AppFonts.plusJakarta(
          size: 22,
          weight: FontWeight.w800,
          height: 1.25,
          color: AppColors.text,
          letterSpacing: 0.2,
        ),
        labelLarge: AppFonts.beVietnam(
          size: 12,
          weight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: AppColors.primary,
          textStyle: AppFonts.beVietnam(size: 12, weight: FontWeight.w700),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        ),
      ),
    );
}
