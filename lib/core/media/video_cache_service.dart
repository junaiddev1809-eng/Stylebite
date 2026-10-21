import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'app_cache_manager.dart';

class VideoCacheService {
  VideoCacheService._();

  static final Map<String, Future<File?>> _inflight = {};
  static final _DownloadGate _gate = _DownloadGate(2);

  static Future<File?> getCachedFile(String url) async {
    try {
      final cached = await AppVideoCacheManager.instance.getFileFromCache(url);
      if (cached != null && cached.file.existsSync()) {
        return cached.file;
      }
    } catch (_) {}
    return null;
  }

  static Future<File?> getFile(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty || trimmed.startsWith('/')) {
      return null;
    }

    final existing = _inflight[trimmed];
    if (existing != null) {
      return existing;
    }

    final download = _download(trimmed);
    _inflight[trimmed] = download;
    try {
      return await download;
    } finally {
      if (identical(_inflight[trimmed], download)) {
        _inflight.remove(trimmed);
      }
    }
  }

  static Future<File?> _download(String url) async {
    final cached = await getCachedFile(url);
    if (cached != null) {
      return cached;
    }

    await _gate.acquire();
    try {
      final again = await getCachedFile(url);
      if (again != null) {
        return again;
      }
      final downloaded = await AppVideoCacheManager.instance.downloadFile(url);
      return downloaded.file;
    } catch (_) {
      return null;
    } finally {
      _gate.release();
    }
  }

  static bool isInFlight(String url) {
    return _inflight.containsKey(url.trim());
  }

  static void prefetch(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty || trimmed.startsWith('/')) {
      return;
    }
    unawaited(getFile(trimmed));
  }

  static Future<void> evict(String url) {
    return AppVideoCacheManager.instance.removeFile(url);
  }

  static Future<void> clear() {
    return AppVideoCacheManager.instance.emptyCache();
  }

  static Stream<FileResponse> stream(String url) {
    return AppVideoCacheManager.instance.getFileStream(url, withProgress: true);
  }
}

class _DownloadGate {
  _DownloadGate(this.max);

  final int max;
  int _used = 0;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  Future<void> acquire() async {
    if (_used < max) {
      _used++;
      return;
    }
    final waiter = Completer<void>();
    _waiters.add(waiter);
    await waiter.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
      return;
    }
    if (_used > 0) {
      _used--;
    }
  }
}
