import 'package:get/get.dart';

import '../../post/services/post_interaction_store.dart';
import '../models/profile_model.dart';

SavedProfilePostModel savedPostFromDraft(
  SavedPostDraft draft,
  PostInteraction state,
) {
  final id = int.tryParse(draft.id) ?? 0;
  return SavedProfilePostModel(
    savedPostId: 0,
    savedAt: 'Just now',
    post: ProfilePostModel(
      id: id,
      postType: draft.postType,
      caption: draft.caption,
      mediaKind: draft.isVideo ? 'video' : 'image',
      location: draft.location,
      likeCount: state.likeCount,
      commentCount: 0,
      shareCount: 0,
      saveCount: state.saveCount,
      ratingAvg: null,
      media: <ProfileMediaModel>[
        ProfileMediaModel(
          id: 0,
          mediaType: draft.isVideo ? 'video' : 'image',
          fileUrl: draft.imageUrl,
          thumbnailUrl: draft.imageUrl,
        ),
      ],
      createdAt: '',
      isSaved: true,
    ),
  );
}

/// Drops posts the shared store has unsaved, and keeps a save that this
/// response is too old to know about.
List<SavedProfilePostModel> savedPostsForResponse(
  List<SavedProfilePostModel> server, {
  required int observedAt,
}) {
  final store = PostInteractionStore.ensure();
  final next = server.where((item) {
    final state = store.stateFor(item.post.id.toString());
    return state == null || state.isSaved;
  }).toList();

  store.forEachState((id, state) {
    if (!state.isSaved) {
      return;
    }
    final newerThanResponse =
        store.isSaveBusy(id) || store.saveEpochFor(id) > observedAt;
    if (!newerThanResponse) {
      return;
    }
    if (next.any((item) => item.post.id.toString() == id)) {
      return;
    }
    final draft = store.draftFor(id);
    if (draft == null) {
      return;
    }
    next.insert(0, savedPostFromDraft(draft, state));
  });

  for (final item in next) {
    final post = item.post;
    store.rememberDraft(
      SavedPostDraft(
        id: post.id.toString(),
        caption: post.caption,
        imageUrl: post.gridImageUrl,
        postType: post.postType,
        isVideo: post.mediaKind == 'video',
        location: post.location,
      ),
    );
  }
  return next;
}

/// One like/save change. Unsave removes the tile. Save puts it back.
void applySavedChange(RxList<SavedProfilePostModel> savedPosts) {
  final store = PostInteractionStore.ensure();
  final id = store.lastChangedId;
  if (id == null) {
    savedPosts.clear();
    return;
  }
  if (store.lastChange != PostInteractionField.save) {
    return;
  }
  final state = store.stateFor(id);
  final numeric = int.tryParse(id);
  if (state == null || numeric == null) {
    return;
  }
  if (!state.isSaved) {
    savedPosts.removeWhere((item) => item.post.id == numeric);
    return;
  }
  if (savedPosts.any((item) => item.post.id == numeric)) {
    return;
  }
  final draft = store.draftFor(id);
  if (draft == null) {
    return;
  }
  savedPosts.insert(0, savedPostFromDraft(draft, state));
}
