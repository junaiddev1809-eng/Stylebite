import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stylebite/core/utils/local_storage.dart';
import 'package:stylebite/modules/post/services/post_interaction_store.dart';
import 'package:stylebite/modules/profile/controllers/saved_post_sync.dart';
import 'package:stylebite/modules/profile/models/profile_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    LocalStorage.prefs = await SharedPreferences.getInstance();
    Get.reset();
  });

  tearDown(Get.reset);

  PostInteractionStore openStore() => PostInteractionStore.ensure();

  test('feed and reels read the same like state', () {
    final store = openStore();
    store.optimisticLike(postId: '42', isLiked: false, likeCount: 3);
    store.confirmLike('42', isLiked: true, likeCount: 4);

    final feed = store.stateFor('42');
    final reels = store.stateFor('42');
    expect(feed, isNotNull);
    expect(reels!.isLiked, feed!.isLiked);
    expect(reels.likeCount, 4);

    store.optimisticLike(postId: '42', isLiked: true, likeCount: 4);
    store.confirmLike('42', isLiked: false, likeCount: 3);
    expect(store.stateFor('42')!.isLiked, isFalse);
    expect(store.stateFor('42')!.likeCount, 3);
  });

  test('failed like and save roll back to the first tap', () {
    final store = openStore();
    store.optimisticLike(postId: '7', isLiked: false, likeCount: 2);
    store.optimisticLike(postId: '7', isLiked: true, likeCount: 3);
    store.rollbackLike('7');
    expect(store.stateFor('7')!.isLiked, isFalse);
    expect(store.stateFor('7')!.likeCount, 2);
    expect(store.isLikeBusy('7'), isFalse);

    store.optimisticSave(postId: '7', isSaved: true, saveCount: 5);
    store.rollbackSave('7');
    expect(store.stateFor('7')!.isSaved, isTrue);
    expect(store.stateFor('7')!.saveCount, 5);
  });

  test('rapid taps move the count by one and never below zero', () {
    final store = openStore();
    store.optimisticLike(postId: '1', isLiked: false, likeCount: 0);
    store.optimisticLike(postId: '1', isLiked: true, likeCount: 1);
    store.optimisticLike(postId: '1', isLiked: false, likeCount: 0);
    store.optimisticLike(postId: '1', isLiked: true, likeCount: 1);
    expect(store.stateFor('1')!.likeCount, 0);
    expect(store.stateFor('1')!.isLiked, isFalse);

    store.optimisticSave(postId: '1', isSaved: false, saveCount: 0);
    store.optimisticSave(postId: '1', isSaved: true, saveCount: 1);
    expect(store.stateFor('1')!.saveCount, 0);
  });

  test('an older response cannot overwrite a newer like or save', () {
    final store = openStore();
    final before = store.observedClock;
    store.optimisticLike(postId: '9', isLiked: false, likeCount: 1);
    store.confirmLike('9', isLiked: true, likeCount: 2);

    store.adoptServer(
      postId: '9',
      isLiked: false,
      likeCount: 1,
      isSaved: false,
      saveCount: 0,
      observedAt: before,
    );
    expect(store.stateFor('9')!.isLiked, isTrue);
    expect(store.stateFor('9')!.likeCount, 2);

    store.optimisticSave(postId: '9', isSaved: false, saveCount: 0);
    final duringSave = store.observedClock;
    store.adoptServer(
      postId: '9',
      isLiked: true,
      likeCount: 2,
      isSaved: false,
      saveCount: 0,
      observedAt: duringSave,
    );
    expect(store.stateFor('9')!.isSaved, isTrue);

    store.confirmSave('9', isSaved: true, saveCount: 1);
    final after = store.observedClock;
    store.adoptServer(
      postId: '9',
      isLiked: true,
      likeCount: 8,
      isSaved: true,
      saveCount: 4,
      observedAt: after,
    );
    expect(store.stateFor('9')!.likeCount, 8);
    expect(store.stateFor('9')!.saveCount, 4);
  });

  test('a stale confirm is ignored while the latest tap still stands', () {
    final store = openStore();
    store.optimisticLike(postId: '3', isLiked: false, likeCount: 1);
    store.optimisticLike(postId: '3', isLiked: true, likeCount: 2);
    store.confirmLike('3', isLiked: true, likeCount: 99);
    expect(store.stateFor('3')!.isLiked, isFalse);
    expect(store.stateFor('3')!.likeCount, 1);
    expect(store.isLikeBusy('3'), isTrue);
  });

  test('interaction state does not leak across accounts', () {
    final store = openStore();
    LocalStorage.setUserId(userId: 11);
    store.bindCurrentUser();
    store.optimisticLike(postId: '5', isLiked: false, likeCount: 1);
    expect(store.stateFor('5'), isNotNull);

    LocalStorage.setUserId(userId: 22);
    store.bindCurrentUser();
    expect(store.stateFor('5'), isNull);

    store.clear();
    store.optimisticSave(postId: '5', isSaved: false, saveCount: 0);
    store.clear();
    expect(store.stateFor('5'), isNull);
  });

  test('unsave drops the saved tile and a failed unsave puts it back', () {
    final store = openStore();
    final saved = <SavedProfilePostModel>[savedItem(8), savedItem(9)].obs;
    store.rememberDraft(
      const SavedPostDraft(
        id: '8',
        caption: 'Coat',
        imageUrl: 'https://example.com/coat.jpg',
        postType: 'outfit',
        isVideo: false,
      ),
    );
    store.optimisticSave(postId: '8', isSaved: true, saveCount: 1);
    applySavedChange(saved);
    expect(saved.map((item) => item.post.id), [9]);

    store.rollbackSave('8');
    applySavedChange(saved);
    expect(saved.first.post.id, 8);
    expect(saved.map((item) => item.post.id), contains(9));
  });

  test('a like does not add the post to saved posts', () {
    final store = openStore();
    final saved = <SavedProfilePostModel>[savedItem(4)].obs;
    store.optimisticLike(postId: '4', isLiked: false, likeCount: 1);
    applySavedChange(saved);
    expect(saved, hasLength(1));
    expect(saved.first.post.id, 4);
  });

  test('an older saved-list response cannot bring back an unsaved post', () {
    final store = openStore();
    final before = store.observedClock;
    store.optimisticSave(postId: '8', isSaved: true, saveCount: 2);
    store.confirmSave('8', isSaved: false, saveCount: 1);

    final next = savedPostsForResponse(
      [savedItem(8), savedItem(2)],
      observedAt: before,
    );
    expect(next.map((item) => item.post.id), [2]);
  });

  test('a save still in flight stays on the saved list', () {
    final store = openStore();
    final before = store.observedClock;
    store.rememberDraft(
      const SavedPostDraft(
        id: '15',
        caption: 'Bite',
        imageUrl: 'https://example.com/bite.jpg',
        postType: 'food',
        isVideo: true,
      ),
    );
    store.optimisticSave(postId: '15', isSaved: false, saveCount: 0);

    final next = savedPostsForResponse(
      [savedItem(2)],
      observedAt: before,
    );
    expect(next.first.post.id, 15);
    expect(next.first.post.isSaved, isTrue);
  });

  test('pending local posts are not stored', () {
    final store = openStore();
    store.optimisticLike(postId: 'local-1', isLiked: false, likeCount: 0);
    store.optimisticLike(postId: '-4', isLiked: false, likeCount: 0);
    expect(store.stateFor('local-1'), isNull);
    expect(store.stateFor('-4'), isNull);
  });
}

SavedProfilePostModel savedItem(int id) {
  return SavedProfilePostModel(
    savedPostId: id,
    savedAt: '',
    post: ProfilePostModel(
      id: id,
      postType: 'outfit',
      caption: 'Look $id',
      mediaKind: 'image',
      location: '',
      likeCount: 1,
      commentCount: 0,
      shareCount: 0,
      saveCount: 1,
      ratingAvg: null,
      media: const <ProfileMediaModel>[],
      createdAt: '',
      isSaved: true,
    ),
  );
}
