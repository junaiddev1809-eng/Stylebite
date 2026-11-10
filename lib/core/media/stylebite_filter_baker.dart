import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import 'stylebite_cube_lut.dart';
import 'stylebite_editor_looks.dart';

/// Bakes StyleBite looks onto stills — real `.cube` LUT when available.
class StyleBiteFilterBaker {
  StyleBiteFilterBaker._();

  static const List<double> _identity = <double>[
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ];

  /// Color matrix for live preview (camera / chips). Final bake prefers real LUT.
  static List<double> matrixFor(FilterModel look, [double intensity = 1]) {
    final amount = intensity.clamp(0.0, 1.0);
    if (look.filters.isEmpty || amount <= 0.001) {
      return List<double>.of(_identity);
    }
    final merged = _merge(look.filters);
    return _lerp(_identity, merged, amount);
  }

  /// Returns a new temp file, or [source] when look is Original / intensity 0.
  /// On failure returns null so callers can keep the original slide.
  static Future<File?> bake({
    required File source,
    required FilterModel look,
    double intensity = 1,
  }) async {
    final amount = intensity.clamp(0.0, 1.0);
    final cubePath = StyleBiteEditorLooks.cubeAssetFor(look.name);
    if ((look.filters.isEmpty && cubePath == null) || amount <= 0.001) {
      return source;
    }

    try {
      final bytes = await source.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      if (cubePath != null) {
        final baked = await _bakeWithCube(image, cubePath, amount);
        image.dispose();
        return baked;
      }

      final matrix = matrixFor(look, amount);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..colorFilter = ColorFilter.matrix(matrix);
      canvas.drawImage(image, Offset.zero, paint);
      final picture = recorder.endRecording();
      final out = await picture.toImage(image.width, image.height);
      final data = await out.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      out.dispose();
      if (data == null) return null;
      return await _writeTempPng(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  static Future<File?> _bakeWithCube(
    ui.Image image,
    String assetPath,
    double intensity,
  ) async {
    final lut = await StyleBiteCubeLut.loadAsset(assetPath);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return null;
    final rgba = Uint8List.fromList(byteData.buffer.asUint8List());
    lut.applyRgba(rgba, intensity: intensity);

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      image.width,
      image.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final out = await completer.future;
    final png = await out.toByteData(format: ui.ImageByteFormat.png);
    out.dispose();
    if (png == null) return null;
    return _writeTempPng(png.buffer.asUint8List());
  }

  static Future<File> _writeTempPng(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/stylebite_lut_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static List<double> _merge(List<List<double>> filters) {
    var combined = List<double>.of(_identity);
    for (final filter in filters) {
      combined = _multiply(filter, combined);
    }
    return combined;
  }

  static List<double> _lerp(List<double> a, List<double> b, double t) {
    return List<double>.generate(20, (i) => a[i] + (b[i] - a[i]) * t);
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
