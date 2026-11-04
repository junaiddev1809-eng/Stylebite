import 'dart:io';

import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/app_helper.dart';

class MediaGallerySaver {
  MediaGallerySaver._();

  static Future<bool> saveFromUrl({
    required String url,
    required bool isVideo,
  }) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      errorSnackBar(message: 'Nothing to save.');
      return false;
    }

    try {
      final granted = await Gal.requestAccess();
      if (!granted) {
        errorSnackBar(message: 'Allow photo library access to save media.');
        return false;
      }

      final localPath = await _resolveLocalPath(trimmed, isVideo: isVideo);
      if (localPath == null || localPath.isEmpty) {
        errorSnackBar(message: 'Unable to download this media.');
        return false;
      }

      if (isVideo) {
        await Gal.putVideo(localPath);
      } else {
        await Gal.putImage(localPath);
      }

      successSnackBar(message: isVideo ? 'Video saved to gallery.' : 'Photo saved to gallery.');
      return true;
    } on GalException catch (error) {
      errorSnackBar(message: error.type.message);
      return false;
    } catch (_) {
      errorSnackBar(message: 'Unable to save to gallery right now.');
      return false;
    }
  }

  static Future<String?> _resolveLocalPath(
    String url, {
    required bool isVideo,
  }) async {
    if (_looksLikeLocalPath(url)) {
      final file = File(url.startsWith('file://') ? Uri.parse(url).toFilePath() : url);
      if (await file.exists()) {
        return file.path;
      }
    }

    if (!(url.startsWith('http://') || url.startsWith('https://'))) {
      return null;
    }

    final tempDir = await getTemporaryDirectory();
    final extension = _extensionFor(url, isVideo: isVideo);
    final target = File(
      '${tempDir.path}/stylebite_chat_${DateTime.now().millisecondsSinceEpoch}$extension',
    );
    await Dio().download(url, target.path);
    return target.path;
  }

  static bool _looksLikeLocalPath(String value) {
    return value.startsWith('/') ||
        value.contains(r':\') ||
        value.startsWith('file://');
  }

  static String _extensionFor(String url, {required bool isVideo}) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    for (final ext in <String>[
      '.mp4',
      '.mov',
      '.webm',
      '.mkv',
      '.m4v',
      '.jpg',
      '.jpeg',
      '.png',
      '.webp',
      '.gif',
    ]) {
      if (path.endsWith(ext)) {
        return ext;
      }
    }
    return isVideo ? '.mp4' : '.jpg';
  }
}
