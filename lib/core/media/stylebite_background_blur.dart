import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Soft-focus background blur — sharp center, blurred edges (food + portraits).
class StyleBiteBackgroundBlur {
  StyleBiteBackgroundBlur._();

  /// [intensity] 0–1. Returns PNG bytes, or null on failure / near-zero intensity.
  static Future<Uint8List?> bake({
    required Uint8List sourceBytes,
    required double intensity,
  }) async {
    final amount = intensity.clamp(0.0, 1.0);
    if (amount <= 0.02) return null;

    try {
      final codec = await ui.instantiateImageCodec(sourceBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final w = image.width.toDouble();
      final h = image.height.toDouble();

      // Sigma scales with size so look is consistent across resolutions.
      final sigma = (6.0 + amount * 22.0) * (w / 1080.0).clamp(0.65, 1.8);
      final focusRadius = 0.42 + (1.0 - amount) * 0.38;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // 1) Fully blurred base (background).
      final blurPaint = Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.clamp,
        );
      canvas.drawImage(image, Offset.zero, blurPaint);

      // 2) Sharp subject over the top, masked to a soft radial focus.
      canvas.saveLayer(Rect.fromLTWH(0, 0, w, h), Paint());
      canvas.drawImage(image, Offset.zero, Paint());
      final mask = Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: focusRadius,
          colors: const [
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: const [0.0, 0.38, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), mask);
      canvas.restore();

      final picture = recorder.endRecording();
      final out = await picture.toImage(image.width, image.height);
      final png = await out.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      out.dispose();
      if (png == null) return null;
      return png.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}
