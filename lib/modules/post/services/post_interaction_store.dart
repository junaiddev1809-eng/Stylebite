import 'package:get/get.dart';

import '../../../core/media/media_type_resolver.dart';
import '../../../core/utils/app_helper.dart';
import '../../../core/utils/local_storage.dart';
import '../../home/models/home_post_model.dart';
import '../../reel/models/reel_item_model.dart';
import '../utils/like_toggle.dart';

/// Which field the latest shared update changed.
enum PostInteractionField { like, save }

/// Like and save state for one post, shared by feed, reels, profile, and detail.
class PostInteraction {
  const PostInteraction({
    required this.isLiked,
    required this.likeCount,
    required this.isSaved,
    required this.saveCount,
  });

  final bool isLiked;
  final int likeCount;
  final bool isSaved;
  final int saveCount;

  PostInteraction copyWith({
    bool? isLiked,
    int? likeCount,
    bool? isSaved,
    int? saveCount,
  }) {
    return PostInteraction(
      isLiked: isLiked ?? this.isLiked,
      likeCount: likeCount ?? this.likeCount,
      isSaved: isSaved ?? this.isSaved,
      saveCount: saveCount ?? this.saveCount,
    );
  }
}

/// Enough of a post to put it back on the saved grid after a failed unsave.
class SavedPostDraft {
  const SavedPostDraft({
    required this.id,
    required this.caption,
    required this.imageUrl,
    required this.postType,
    required this.isVideo,
    this.location = '',
  });

  final String id;
  final String caption;
  final String imageUrl;
  final String postType;
  final bool isVideo;
  final String location;

  factory SavedPostDraft.fromHome(HomePostModel post) {
    final isVideo = post.resolvedMediaType == AppMediaType.video ||
        post.mediaType == HomeMediaType.video;
    return SavedPostDraft(
      id: post.id,
      caption: post.caption,
      imageUrl: post.primaryMediaUrl,
      postType: post.feedType == HomeFeedType.bite ? 'food' : 'outfit',
      isVideo: isVideo,
      location: post.location,
    );
  }

  factory SavedPostDraft.fromReel(ReelItemModel reel) {
    return SavedPostDraft(
      id: reel.id,
      caption: reel.caption,
      imageUrl: reel.imageUrl,
      postType: reel.feedType == ReelFeedType.bite ? 'food' : 'outfit',
      isVideo: reel.videoUrl.trim().isNotEmpty,
      location: reel.locationName,
    );
  }
}

/// One session-wide record of like and save state.
///
/// Screens read this instead of keeping their own writable copies. A tap
/// changes the record once, then every listening screen applies that value.
class PostInteractionStore extends GetxController {
  PostInteractionStore({
    LikeToggleSync? likes,
    SaveToggleSync? saves,
  }) : _likes = likes ?? LikeToggleSync(),
       _saves = saves ?? SaveToggleSync();

  static PostInteractionStore ensure() {
    if (Get.isRegistered<PostInteractionStore>()) {
      return Get.find<PostInteractionStore>();
    }
    return Get.put(PostInteractionStore(), permanent: true);
  }

  final LikeToggleSync _likes;
  final SaveToggleSync _saves;
  final Map<String, PostInteraction> _states = {};
  final Map<String, (bool, int)> _likeBaseline = {};
  final Map<String, (bool, int)> _saveBaseline = {};
  final Set<String> _likeBusy = {};
  final Set<String> _saveBusy = {};
  final Set<String> _likeKnown = {};
  final Set<String> _saveKnown = {};
  final Map<String, SavedPostDraft> _drafts = {};
  final Map<String, int> _likeEpoch = {};
  final Map<String, int> _saveEpoch = {};
  int _clock = 0;

  final RxInt revision = 0.obs;
  String? lastChangedId;
  PostInteractionField? lastChange;
  String? _userId;

  /// Clock captured before a request. A response may update a post only when
  /// no newer like or save happened after this value.
  int get observedClock => _clock;

  PostInteraction? stateFor(String postId) => _states[postId];

  SavedPostDraft? draftFor(String postId) => _drafts[postId];

  bool hasLike(String postId) => _likeKnown.contains(postId);

  bool hasSave(String postId) => _saveKnown.contains(postId);

  bool isLikeBusy(String postId) => _likeBusy.contains(postId);

  bool isSaveBusy(String postId) => _saveBusy.contains(postId);

  int saveEpochFor(String postId) => _saveEpoch[postId] ?? 0;

  void forEachState(void Function(String postId, PostInteraction state) visit) {
    _states.forEach(visit);
  }

  void rememberDraft(SavedPostDraft draft) {
    if (_skip(draft.id)) {
      return;
    }
    _drafts[draft.id] = draft;
  }

  void clear() {
    _states.clear();
    _likeBaseline.clear();
    _saveBaseline.clear();
    _likeBusy.clear();
    _saveBusy.clear();
    _likeKnown.clear();
    _saveKnown.clear();
    _drafts.clear();
    _likeEpoch.clear();
    _saveEpoch.clear();
    lastChangedId = null;
    lastChange = null;
    _userId = null;
    revision.value++;
  }

  void bindCurrentUser() {
    final next = LocalStorage.getUserId()?.toString();
    if (next == _userId) {
      return;
    }
    final switching = _userId != null;
    _userId = next;
    if (!switching) {
      return;
    }
    _states.clear();
    _likeBaseline.clear();
    _saveBaseline.clear();
    _likeBusy.clear();
    _saveBusy.clear();
    _likeKnown.clear();
    _saveKnown.clear();
    _drafts.clear();
    _likeEpoch.clear();
    _saveEpoch.clear();
    lastChangedId = null;
    lastChange = null;
    revision.value++;
  }

  void toggleLike({
    required String postId,
    required bool isLiked,
    required int likeCount,
    bool? isSaved,
    int? saveCount,
  }) {
    if (_skip(postId)) {
      return;
    }
    bindCurrentUser();
    optimisticLike(
      postId: postId,
      isLiked: isLiked,
      likeCount: likeCount,
      isSaved: isSaved,
      saveCount: saveCount,
    );
    _likes.run(
      id: postId,
      endpoint: 'feed/posts/$postId/like',
      desiredLiked: () => _states[postId]?.isLiked ?? !isLiked,
      onConfirmed: (result) => confirmLike(
        postId,
        isLiked: result.isLiked,
        likeCount: result.likeCount,
      ),
      onError: (error) {
        rollbackLike(postId);
        errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
      },
    );
  }

  void toggleSave({
    required String postId,
    required bool isSaved,
    required int saveCount,
    SavedPostDraft? draft,
    bool? isLiked,
    int? likeCount,
  }) {
    if (_skip(postId)) {
      return;
    }
    bindCurrentUser();
    if (draft != null) {
      rememberDraft(draft);
    }
    optimisticSave(
      postId: postId,
      isSaved: isSaved,
      saveCount: saveCount,
      isLiked: isLiked,
      likeCount: likeCount,
    );
    _saves.run(
      id: postId,
      endpoint: 'feed/posts/$postId/save',
      desiredSaved: () => _states[postId]?.isSaved ?? !isSaved,
      onConfirmed: (isSaved, saveCount) => confirmSave(
        postId,
        isSaved: isSaved,
        saveCount: saveCount,
      ),
      onError: (error) {
        rollbackSave(postId);
        errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
      },
    );
  }

  /// Applies one like tap. The count moves by one from the shared value.
  void optimisticLike({
    required String postId,
    required bool isLiked,
    required int likeCount,
    bool? isSaved,
    int? saveCount,
  }) {
    if (_skip(postId)) {
      return;
    }
    final existing = _states[postId];
    final currentLiked = _likeKnown.contains(postId)
        ? (existing?.isLiked ?? isLiked)
        : isLiked;
    final currentCount = _likeKnown.contains(postId)
        ? (existing?.likeCount ?? likeCount)
        : likeCount;
    if (!_likeBusy.contains(postId)) {
      _likeBaseline[postId] = (currentLiked, currentCount);
      _likeBusy.add(postId);
    }
    _likeEpoch[postId] = ++_clock;
    final nextLiked = !currentLiked;
    final nextCount = nextLiked
        ? currentCount + 1
        : (currentCount > 0 ? currentCount - 1 : 0);
    var next = _ensure(
      postId,
      isLiked: isLiked,
      likeCount: likeCount,
      isSaved: isSaved ?? existing?.isSaved ?? false,
      saveCount: saveCount ?? existing?.saveCount ?? 0,
    ).copyWith(isLiked: nextLiked, likeCount: nextCount);
    if (!_saveKnown.contains(postId) && isSaved != null && saveCount != null) {
      next = next.copyWith(isSaved: isSaved, saveCount: saveCount);
      _saveKnown.add(postId);
    }
    _likeKnown.add(postId);
    _states[postId] = next;
    _emit(postId, PostInteractionField.like);
  }

  void confirmLike(
    String postId, {
    required bool isLiked,
    int? likeCount,
  }) {
    final current = _states[postId];
    if (current == null || current.isLiked != isLiked) {
      return;
    }
    _likeBusy.remove(postId);
    _likeBaseline.remove(postId);
    _likeEpoch[postId] = ++_clock;
    if (likeCount == null || likeCount == current.likeCount) {
      return;
    }
    _states[postId] = current.copyWith(likeCount: likeCount < 0 ? 0 : likeCount);
    _emit(postId, PostInteractionField.like);
  }

  void rollbackLike(String postId) {
    final baseline = _likeBaseline.remove(postId);
    _likeBusy.remove(postId);
    _likeEpoch[postId] = ++_clock;
    if (baseline == null) {
      return;
    }
    _states[postId] = _ensure(postId, isLiked: baseline.$1, likeCount: baseline.$2)
        .copyWith(isLiked: baseline.$1, likeCount: baseline.$2);
    _emit(postId, PostInteractionField.like);
  }

  void optimisticSave({
    required String postId,
    required bool isSaved,
    required int saveCount,
    bool? isLiked,
    int? likeCount,
  }) {
    if (_skip(postId)) {
      return;
    }
    final existing = _states[postId];
    final currentSaved = _saveKnown.contains(postId)
        ? (existing?.isSaved ?? isSaved)
        : isSaved;
    final currentCount = _saveKnown.contains(postId)
        ? (existing?.saveCount ?? saveCount)
        : saveCount;
    if (!_saveBusy.contains(postId)) {
      _saveBaseline[postId] = (currentSaved, currentCount);
      _saveBusy.add(postId);
    }
    _saveEpoch[postId] = ++_clock;
    final nextSaved = !currentSaved;
    final nextCount = nextSaved
        ? currentCount + 1
        : (currentCount > 0 ? currentCount - 1 : 0);
    var next = _ensure(
      postId,
      isLiked: isLiked ?? existing?.isLiked ?? false,
      likeCount: likeCount ?? existing?.likeCount ?? 0,
      isSaved: isSaved,
      saveCount: saveCount,
    ).copyWith(isSaved: nextSaved, saveCount: nextCount);
    if (!_likeKnown.contains(postId) && isLiked != null && likeCount != null) {
      next = next.copyWith(isLiked: isLiked, likeCount: likeCount);
      _likeKnown.add(postId);
    }
    _saveKnown.add(postId);
    _states[postId] = next;
    _emit(postId, PostInteractionField.save);
  }

  void confirmSave(
    String postId, {
    required bool isSaved,
    int? saveCount,
  }) {
    final current = _states[postId];
    if (current == null || current.isSaved != isSaved) {
      return;
    }
    _saveBusy.remove(postId);
    _saveBaseline.remove(postId);
    _saveEpoch[postId] = ++_clock;
    if (saveCount == null || saveCount == current.saveCount) {
      return;
    }
    _states[postId] = current.copyWith(saveCount: saveCount < 0 ? 0 : saveCount);
    _emit(postId, PostInteractionField.save);
  }

  void rollbackSave(String postId) {
    final baseline = _saveBaseline.remove(postId);
    _saveBusy.remove(postId);
    _saveEpoch[postId] = ++_clock;
    if (baseline == null) {
      return;
    }
    _states[postId] = _ensure(
      postId,
      isSaved: baseline.$1,
      saveCount: baseline.$2,
    ).copyWith(isSaved: baseline.$1, saveCount: baseline.$2);
    _emit(postId, PostInteractionField.save);
  }

  /// Server payload may update a post only when that field is not mid-tap.
  void adoptServer({
    required String postId,
    required bool isLiked,
    required int likeCount,
    required bool isSaved,
    required int saveCount,
    required int observedAt,
  }) {
    if (_skip(postId)) {
      return;
    }
    final existing = _states[postId];
    final likeFresh =
        !_likeBusy.contains(postId) && observedAt >= (_likeEpoch[postId] ?? 0);
    final saveFresh =
        !_saveBusy.contains(postId) && observedAt >= (_saveEpoch[postId] ?? 0);
    if (likeFresh) {
      _likeKnown.add(postId);
    }
    if (saveFresh) {
      _saveKnown.add(postId);
    }
    _states[postId] = PostInteraction(
      isLiked: likeFresh ? isLiked : (existing?.isLiked ?? isLiked),
      likeCount: likeFresh ? likeCount : (existing?.likeCount ?? likeCount),
      isSaved: saveFresh ? isSaved : (existing?.isSaved ?? isSaved),
      saveCount: saveFresh ? saveCount : (existing?.saveCount ?? saveCount),
    );
  }

  HomePostModel ingestHome(HomePostModel post, {required int observedAt}) {
    if (_skip(post.id)) {
      return post;
    }
    adoptServer(
      postId: post.id,
      isLiked: post.isLiked,
      likeCount: parseLikeCount(post.likes),
      isSaved: post.isSaved,
      saveCount: post.saveCount,
      observedAt: observedAt,
    );
    rememberDraft(SavedPostDraft.fromHome(post));
    return presentHome(post);
  }

  HomePostModel presentHome(HomePostModel post) {
    final state = _states[post.id];
    if (state == null || _skip(post.id)) {
      return post;
    }
    return post.copyWith(
      isLiked: _likeKnown.contains(post.id) ? state.isLiked : null,
      likes: _likeKnown.contains(post.id) ? formatLikeCount(state.likeCount) : null,
      isSaved: _saveKnown.contains(post.id) ? state.isSaved : null,
      saveCount: _saveKnown.contains(post.id) ? state.saveCount : null,
    );
  }

  ReelItemModel ingestReel(ReelItemModel reel, {required int observedAt}) {
    if (_skip(reel.id)) {
      return reel;
    }
    adoptServer(
      postId: reel.id,
      isLiked: reel.isLiked,
      likeCount: reel.likeCount,
      isSaved: reel.isSaved,
      saveCount: reel.saveCount,
      observedAt: observedAt,
    );
    rememberDraft(SavedPostDraft.fromReel(reel));
    return presentReel(reel);
  }

  ReelItemModel presentReel(ReelItemModel reel) {
    final state = _states[reel.id];
    if (state == null || _skip(reel.id)) {
      return reel;
    }
    return reel.copyWith(
      isLiked: _likeKnown.contains(reel.id) ? state.isLiked : null,
      likeCount: _likeKnown.contains(reel.id) ? state.likeCount : null,
      likes: _likeKnown.contains(reel.id) ? formatLikeCount(state.likeCount) : null,
      isSaved: _saveKnown.contains(reel.id) ? state.isSaved : null,
      saveCount: _saveKnown.contains(reel.id) ? state.saveCount : null,
    );
  }

  PostInteraction _ensure(
    String postId, {
    bool isLiked = false,
    int likeCount = 0,
    bool isSaved = false,
    int saveCount = 0,
  }) {
    return _states[postId] ??
        PostInteraction(
          isLiked: isLiked,
          likeCount: likeCount,
          isSaved: isSaved,
          saveCount: saveCount,
        );
  }

  void _emit(String postId, PostInteractionField field) {
    lastChangedId = postId;
    lastChange = field;
    revision.value++;
  }

  bool _skip(String postId) {
    final id = postId.trim();
    return id.isEmpty || id.startsWith('local-') || id.startsWith('-');
  }
}
