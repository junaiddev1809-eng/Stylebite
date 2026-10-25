import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/media/picked_media.dart';
import '../../../core/utils/app_helper.dart';
import '../../../core/utils/local_storage.dart';
import '../models/flash_model.dart';
import '../screens/flash_camera_screen.dart';
import '../screens/flash_viewer_screen.dart';
import '../services/flash_sync_service.dart';
import '../widgets/flash_archive_sheet.dart';

class FlashController extends GetxController {
  static const _storageKey = 'styleFlashes';

  static FlashController ensure() {
    if (Get.isRegistered<FlashController>()) {
      return Get.find<FlashController>();
    }
    return Get.put(FlashController(), permanent: true);
  }

  final RxList<FlashBucket> buckets = <FlashBucket>[].obs;
  final RxBool isLoading = false.obs;
  final _publishing = <String>{};

  String get _me =>
      (LocalStorage.getUsername() ?? '').trim().replaceFirst('@', '');

  String get _avatar => (LocalStorage.getAvatarUrl() ?? '').trim();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = buckets.isEmpty;
    try {
      final local = _readLocal();
      buckets.assignAll(_group(local));
      await _persist(local);

      final remote = await FlashSyncService.fetchFlashes();
      final merged = _merge(local, remote);
      buckets.assignAll(_group(merged));
      await _persist(merged);
      unawaited(_republishUnsynced(merged));
    } finally {
      isLoading.value = false;
    }
  }

  /// Peers only while they still have unseen flashes (Instants once-view).
  List<FlashBucket> bucketsFor(FlashKind kind) {
    final result = <FlashBucket>[];
    var hasMine = false;
    for (final bucket in buckets) {
      final items = [
        for (final item in bucket.items)
          if (item.kind == kind && (bucket.isMine || !item.seen)) item,
      ];
      if (bucket.isMine) {
        hasMine = true;
        result.add(
          FlashBucket(
            username: bucket.username,
            avatarUrl: bucket.avatarUrl,
            items: [
              for (final item in bucket.items)
                if (item.kind == kind) item,
            ],
            isMine: true,
            kind: kind,
          ),
        );
        continue;
      }
      if (items.isEmpty) continue;
      result.add(
        FlashBucket(
          username: bucket.username,
          avatarUrl: bucket.avatarUrl,
          items: items,
          isMine: false,
          kind: kind,
        ),
      );
    }
    if (!hasMine) {
      result.insert(
        0,
        FlashBucket(
          username: _me.isEmpty ? 'you' : _me,
          avatarUrl: _avatar,
          items: const [],
          isMine: true,
          kind: kind,
        ),
      );
    }
    return result;
  }

  /// Returns local id. When [quiet], skips success snackbars (camera undo flow).
  Future<String?> addFlash({
    required PickedMedia media,
    String caption = '',
    FlashKind kind = FlashKind.outfit,
    bool quiet = false,
  }) async {
    final username = _me;
    if (username.isEmpty) {
      errorSnackBar(message: 'Please sign in to share a flash.');
      return null;
    }

    final stored = await _persistMedia(media);
    final next = FlashItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      username: username,
      avatarUrl: _avatar,
      mediaPath: stored.path,
      createdAt: DateTime.now(),
      caption: caption.trim(),
      kind: kind,
    );
    final items = [
      for (final bucket in buckets) ...bucket.items,
      next,
    ];
    buckets.assignAll(_group(items));
    await _persist(items);

    final label = flashSingularLabel(kind);
    try {
      final published = await FlashSyncService.publish(
        local: next,
        media: media,
      );
      if (published != null) {
        final synced = [
          for (final item in items)
            item.id == next.id
                ? item.copyWith(
                    remoteId: published.remoteId,
                    mediaUrl: published.mediaUrl,
                  )
                : item,
        ];
        buckets.assignAll(_group(synced));
        await _persist(synced);
        if (!quiet) successSnackBar(message: '$label shared.');
        return next.id;
      }
      if (!quiet) {
        successSnackBar(
          message: '$label saved. Friends will see it once it finishes sharing.',
        );
      }
      return next.id;
    } catch (_) {
      if (!quiet) {
        successSnackBar(
          message: '$label saved. Friends will see it once it finishes sharing.',
        );
      }
      return next.id;
    }
  }

  Future<void> deleteFlash(String flashId) async {
    FlashItem? target;
    for (final bucket in buckets) {
      for (final item in bucket.items) {
        if (item.id == flashId || item.remoteId == flashId) {
          target = item;
          break;
        }
      }
    }
    if (target == null) return;

    if (target.remoteId.trim().isNotEmpty) {
      await FlashSyncService.deleteRemote(target.remoteId);
    }

    final next = [
      for (final bucket in buckets)
        for (final item in bucket.items)
          if (item.id != target.id && item.remoteId != target.id) item,
    ];
    buckets.assignAll(_group(next));
    await _persist(next);
  }

  Future<void> markSeen(String flashId) async {
    final items = [
      for (final bucket in buckets)
        for (final item in bucket.items)
          item.id == flashId || item.remoteId == flashId
              ? item.copyWith(seen: true)
              : item,
    ];
    buckets.assignAll(_group(items));
    await _persist(items);
  }

  Future<void> startCreate({FlashKind kind = FlashKind.outfit}) async {
    await Get.to<void>(() => FlashCameraScreen(kind: kind));
    await load();
  }

  void openMineArchive({FlashKind kind = FlashKind.outfit}) {
    Get.bottomSheet(
      FlashArchiveSheet(kind: kind),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  bool hasUnseenPeers(FlashKind kind) {
    final me = _me.toLowerCase();
    for (final bucket in buckets) {
      if (bucket.username.toLowerCase() == me) continue;
      for (final item in bucket.items) {
        if (item.kind == kind && !item.seen) return true;
      }
    }
    return false;
  }

  int mineCount(FlashKind kind) {
    for (final bucket in buckets) {
      if (!bucket.isMine) continue;
      return bucket.items.where((item) => item.kind == kind).length;
    }
    return 0;
  }

  /// Others only (Instants stack). Your flashes stay in Yours / archive.
  /// If nobody has unseen flashes → opens camera.
  Future<void> openCombined({FlashKind kind = FlashKind.outfit}) async {
    final playlist = peersPlaylist(kind);
    if (playlist.isEmpty) {
      await startCreate(kind: kind);
      return;
    }
    await Get.to<void>(
      () => FlashViewerScreen(
        items: playlist,
        kind: kind,
        openCameraWhenDone: true,
      ),
    );
    await load();
  }

  /// Your flashes only — same mid-screen viewer, with delete.
  Future<void> openMineViewer({FlashKind kind = FlashKind.outfit}) async {
    final playlist = minePlaylist(kind);
    if (playlist.isEmpty) {
      openMineArchive(kind: kind);
      return;
    }
    await Get.to<void>(
      () => FlashViewerScreen(
        items: playlist,
        kind: kind,
        openCameraWhenDone: false,
      ),
    );
    await load();
  }

  List<FlashItem> peersPlaylist(FlashKind kind) {
    final me = _me.toLowerCase();
    final peerGroups = <String, List<FlashItem>>{};
    final peerFirstAt = <String, DateTime>{};

    for (final bucket in buckets) {
      final isMine =
          bucket.isMine || bucket.username.toLowerCase() == me;
      if (isMine) continue;
      for (final item in bucket.items) {
        if (item.kind != kind || item.seen) continue;
        final key = item.username.toLowerCase();
        peerGroups.putIfAbsent(key, () => []).add(item);
        final first = peerFirstAt[key];
        if (first == null || item.createdAt.isBefore(first)) {
          peerFirstAt[key] = item.createdAt;
        }
      }
    }

    for (final list in peerGroups.values) {
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    final orderedPeers = peerGroups.keys.toList()
      ..sort((a, b) {
        final aAt = peerFirstAt[a] ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bAt = peerFirstAt[b] ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aAt.compareTo(bAt);
      });

    return [for (final key in orderedPeers) ...peerGroups[key]!];
  }

  List<FlashItem> minePlaylist(FlashKind kind) {
    final mine = <FlashItem>[];
    for (final bucket in buckets) {
      if (!bucket.isMine) continue;
      for (final item in bucket.items) {
        if (item.kind == kind) mine.add(item);
      }
    }
    mine.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return mine;
  }

  List<FlashItem> _readLocal() {
    final raw = LocalStorage.prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final items = <FlashItem>[];
      for (final entry in decoded.whereType<Map>()) {
        final item = FlashItem.fromJson(
          entry.map((key, value) => MapEntry(key.toString(), value)),
        );
        if (item.isExpired) continue;
        final hasLocal =
            item.mediaPath.isNotEmpty && File(item.mediaPath).existsSync();
        final hasRemote = item.mediaUrl.trim().isNotEmpty || item.isPublished;
        if (hasLocal || hasRemote) items.add(item);
      }
      return items;
    } catch (_) {
      return const [];
    }
  }

  List<FlashItem> _merge(List<FlashItem> local, List<FlashItem> remote) {
    final seenState = <String, bool>{
      for (final item in local)
        if (item.seen) ...{
          item.mergeKey: true,
          if (item.remoteId.isNotEmpty) 'r:${item.remoteId}': true,
          'l:${item.id}': true,
        },
    };
    final byKey = <String, FlashItem>{};
    void put(FlashItem item) {
      if (item.isExpired) return;
      final key = item.mergeKey;
      final existing = byKey[key];
      final seen = item.seen ||
          seenState[key] == true ||
          seenState['l:${item.id}'] == true ||
          (item.remoteId.isNotEmpty &&
              seenState['r:${item.remoteId}'] == true);
      if (existing == null) {
        byKey[key] = item.copyWith(seen: seen);
        return;
      }
      byKey[key] = existing.copyWith(
        mediaPath: existing.mediaPath.isNotEmpty
            ? existing.mediaPath
            : item.mediaPath,
        mediaUrl:
            existing.mediaUrl.isNotEmpty ? existing.mediaUrl : item.mediaUrl,
        remoteId:
            existing.remoteId.isNotEmpty ? existing.remoteId : item.remoteId,
        avatarUrl: existing.avatarUrl.isNotEmpty
            ? existing.avatarUrl
            : item.avatarUrl,
        seen: existing.seen || seen,
        kind: item.isPublished ? item.kind : existing.kind,
      );
    }

    for (final item in local) {
      put(item);
    }
    for (final item in remote) {
      put(item);
    }
    return byKey.values.toList(growable: false);
  }

  Future<void> _republishUnsynced(List<FlashItem> items) async {
    final me = _me.toLowerCase();
    for (final item in items) {
      if (item.username.toLowerCase() != me || item.isPublished) continue;
      if (item.mediaPath.isEmpty || !File(item.mediaPath).existsSync()) {
        continue;
      }
      if (!_publishing.add(item.id)) continue;
      try {
        final published = await FlashSyncService.republishFile(
          local: item,
          filePath: item.mediaPath,
        );
        if (published == null) continue;
        final next = [
          for (final current in [
            for (final bucket in buckets) ...bucket.items,
          ])
            current.id == item.id
                ? current.copyWith(
                    remoteId: published.remoteId,
                    mediaUrl: published.mediaUrl,
                  )
                : current,
        ];
        buckets.assignAll(_group(next));
        await _persist(next);
      } catch (_) {
      } finally {
        _publishing.remove(item.id);
      }
    }
  }

  List<FlashBucket> _group(List<FlashItem> items) {
    final mineName = _me.toLowerCase();
    final byUser = <String, List<FlashItem>>{};
    for (final item in items) {
      if (item.isExpired) continue;
      byUser.putIfAbsent(item.username.toLowerCase(), () => []).add(item);
    }
    for (final list in byUser.values) {
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    final result = <FlashBucket>[];
    final mineItems = byUser.remove(mineName) ?? const <FlashItem>[];
    result.add(
      FlashBucket(
        username: _me.isEmpty ? 'you' : _me,
        avatarUrl: _avatar,
        items: mineItems,
        isMine: true,
      ),
    );

    final others = byUser.entries.toList()
      ..sort((a, b) {
        final aUnseen = a.value.any((item) => !item.seen);
        final bUnseen = b.value.any((item) => !item.seen);
        if (aUnseen != bUnseen) return aUnseen ? -1 : 1;
        return b.value.last.createdAt.compareTo(a.value.last.createdAt);
      });
    for (final entry in others) {
      result.add(
        FlashBucket(
          username: entry.value.first.username,
          avatarUrl: entry.value.first.avatarUrl,
          items: entry.value,
          isMine: false,
        ),
      );
    }
    return result;
  }

  Future<void> _persist(List<FlashItem> items) async {
    await LocalStorage.prefs.setString(
      _storageKey,
      jsonEncode(
        items
            .where((item) => !item.isExpired)
            .map((item) => item.toJson())
            .toList(),
      ),
    );
  }

  Future<File> _persistMedia(PickedMedia media) async {
    final docs = await getApplicationDocumentsDirectory();
    final folder = Directory('${docs.path}/style_flashes');
    if (!folder.existsSync()) {
      await folder.create(recursive: true);
    }
    final ext = media.path.split('.').last;
    final target = File(
      '${folder.path}/${DateTime.now().microsecondsSinceEpoch}.$ext',
    );
    return media.file.copy(target.path);
  }
}
