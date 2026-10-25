import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/media/media_picker_service.dart';
import '../../../core/media/picked_media.dart';
import '../../../core/utils/app_helper.dart';
import '../../../core/utils/local_storage.dart';
import '../models/flash_model.dart';
import '../screens/create_flash_screen.dart';
import '../screens/flash_viewer_screen.dart';
import '../services/flash_sync_service.dart';

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

  /// Peers only appear while they still have unseen flashes (Instants once-view).
  /// Your own ring stays so you can add more.
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
            items: items,
            isMine: true,
            kind: kind,
          ),
        );
        continue;
      }
      if (items.isEmpty) {
        continue;
      }
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

  Future<void> addFlash({
    required PickedMedia media,
    String caption = '',
    FlashKind kind = FlashKind.outfit,
  }) async {
    final username = _me;
    if (username.isEmpty) {
      errorSnackBar(message: 'Please sign in to share a flash.');
      return;
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
        successSnackBar(message: '$label shared.');
        return;
      }
      successSnackBar(
        message: '$label saved. Friends will see it once it finishes sharing.',
      );
    } catch (_) {
      successSnackBar(
        message: '$label saved. Friends will see it once it finishes sharing.',
      );
    }
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
    final media = await MediaPickerService.pickInstantPhoto();
    if (media == null) {
      return;
    }

    final published = await Get.to<bool>(
      () => CreateFlashScreen(media: media, kind: kind),
    );
    if (published == true) {
      await load();
    }
  }

  void openBucket(FlashBucket bucket, {int startIndex = 0}) {
    if (bucket.items.isEmpty) {
      startCreate(kind: bucket.kind);
      return;
    }
    Get.to<void>(
      () => FlashViewerScreen(
        bucket: bucket,
        startIndex: startIndex,
      ),
    );
  }

  List<FlashItem> _readLocal() {
    final raw = LocalStorage.prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      final items = <FlashItem>[];
      for (final entry in decoded.whereType<Map>()) {
        final item = FlashItem.fromJson(
          entry.map((key, value) => MapEntry(key.toString(), value)),
        );
        if (item.isExpired) {
          continue;
        }
        final hasLocal =
            item.mediaPath.isNotEmpty && File(item.mediaPath).existsSync();
        final hasRemote = item.mediaUrl.trim().isNotEmpty || item.isPublished;
        if (hasLocal || hasRemote) {
          items.add(item);
        }
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
      if (item.isExpired) {
        return;
      }
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
      if (item.username.toLowerCase() != me || item.isPublished) {
        continue;
      }
      if (item.mediaPath.isEmpty || !File(item.mediaPath).existsSync()) {
        continue;
      }
      if (!_publishing.add(item.id)) {
        continue;
      }
      try {
        final published = await FlashSyncService.republishFile(
          local: item,
          filePath: item.mediaPath,
        );
        if (published == null) {
          continue;
        }
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
        // Keep local; next refresh retries.
      } finally {
        _publishing.remove(item.id);
      }
    }
  }

  List<FlashBucket> _group(List<FlashItem> items) {
    final mineName = _me.toLowerCase();
    final byUser = <String, List<FlashItem>>{};
    for (final item in items) {
      if (item.isExpired) {
        continue;
      }
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
        if (aUnseen != bUnseen) {
          return aUnseen ? -1 : 1;
        }
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
