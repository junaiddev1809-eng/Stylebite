import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Parses and applies Adobe `.cube` 3D LUTs (DAEDAL CC0 packs).
class StyleBiteCubeLut {
  StyleBiteCubeLut._({
    required this.size,
    required this.data,
  });

  final int size;
  final Float32List data; // RGB triplets, size^3

  static final Map<String, Future<StyleBiteCubeLut>> _cache = {};

  static Future<StyleBiteCubeLut> loadAsset(String assetPath) {
    return _cache.putIfAbsent(assetPath, () async {
      final raw = await rootBundle.loadString(assetPath);
      return StyleBiteCubeLut.parse(raw);
    });
  }

  static StyleBiteCubeLut parse(String cubeText) {
    var size = 0;
    final values = <double>[];
    for (final line in cubeText.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final upper = trimmed.toUpperCase();
      if (upper.startsWith('TITLE') ||
          upper.startsWith('DOMAIN_MIN') ||
          upper.startsWith('DOMAIN_MAX')) {
        continue;
      }
      if (upper.startsWith('LUT_3D_SIZE')) {
        size = int.parse(trimmed.split(RegExp(r'\s+')).last);
        continue;
      }
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length >= 3) {
        values.add(double.parse(parts[0]));
        values.add(double.parse(parts[1]));
        values.add(double.parse(parts[2]));
      }
    }
    if (size <= 1) {
      throw StateError('Invalid LUT_3D_SIZE in .cube file');
    }
    final expected = size * size * size * 3;
    if (values.length < expected) {
      throw StateError('Incomplete .cube data');
    }
    return StyleBiteCubeLut._(
      size: size,
      data: Float32List.fromList(values.sublist(0, expected)),
    );
  }

  /// Applies this LUT onto RGBA8888 bytes (in-place). [intensity] 0–1 blends with original.
  void applyRgba(Uint8List rgba, {double intensity = 1}) {
    final amount = intensity.clamp(0.0, 1.0);
    if (amount <= 0.001) return;
    final n = size;
    final maxIndex = n - 1;
    for (var i = 0; i + 3 < rgba.length; i += 4) {
      final r0 = rgba[i] / 255.0;
      final g0 = rgba[i + 1] / 255.0;
      final b0 = rgba[i + 2] / 255.0;
      final mapped = _sample(r0, g0, b0, n, maxIndex);
      if (amount >= 0.999) {
        rgba[i] = _toByte(mapped[0]);
        rgba[i + 1] = _toByte(mapped[1]);
        rgba[i + 2] = _toByte(mapped[2]);
      } else {
        rgba[i] = _toByte(r0 + (mapped[0] - r0) * amount);
        rgba[i + 1] = _toByte(g0 + (mapped[1] - g0) * amount);
        rgba[i + 2] = _toByte(b0 + (mapped[2] - b0) * amount);
      }
    }
  }

  List<double> _sample(double r, double g, double b, int n, int maxIndex) {
    final rf = r.clamp(0.0, 1.0) * maxIndex;
    final gf = g.clamp(0.0, 1.0) * maxIndex;
    final bf = b.clamp(0.0, 1.0) * maxIndex;
    final r0 = rf.floor().clamp(0, maxIndex - 1);
    final g0 = gf.floor().clamp(0, maxIndex - 1);
    final b0 = bf.floor().clamp(0, maxIndex - 1);
    final r1 = r0 + 1;
    final g1 = g0 + 1;
    final b1 = b0 + 1;
    final tr = rf - r0;
    final tg = gf - g0;
    final tb = bf - b0;

    final c000 = _rgbAt(r0, g0, b0, n);
    final c100 = _rgbAt(r1, g0, b0, n);
    final c010 = _rgbAt(r0, g1, b0, n);
    final c110 = _rgbAt(r1, g1, b0, n);
    final c001 = _rgbAt(r0, g0, b1, n);
    final c101 = _rgbAt(r1, g0, b1, n);
    final c011 = _rgbAt(r0, g1, b1, n);
    final c111 = _rgbAt(r1, g1, b1, n);

    final c00 = _lerp3(c000, c100, tr);
    final c01 = _lerp3(c001, c101, tr);
    final c10 = _lerp3(c010, c110, tr);
    final c11 = _lerp3(c011, c111, tr);
    final c0 = _lerp3(c00, c10, tg);
    final c1 = _lerp3(c01, c11, tg);
    return _lerp3(c0, c1, tb);
  }

  List<double> _rgbAt(int r, int g, int b, int n) {
    // .cube order is blue-major (B changes fastest), then green, then red.
    final index = ((r * n * n) + (g * n) + b) * 3;
    return [data[index], data[index + 1], data[index + 2]];
  }

  static List<double> _lerp3(List<double> a, List<double> b, double t) {
    return [
      a[0] + (b[0] - a[0]) * t,
      a[1] + (b[1] - a[1]) * t,
      a[2] + (b[2] - a[2]) * t,
    ];
  }

  static int _toByte(double v) => (v.clamp(0.0, 1.0) * 255.0).round();
}
