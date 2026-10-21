import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppFonts {
  AppFonts._();

  static TextStyle beVietnam({
    double? size,
    FontWeight? weight,
    double? height,
    Color? color,
    double? letterSpacing,
  }) {
    return GoogleFonts.beVietnamPro(
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle plusJakarta({
    double? size,
    FontWeight? weight,
    double? height,
    Color? color,
    double? letterSpacing,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color,
      letterSpacing: letterSpacing,
    );
  }
}
