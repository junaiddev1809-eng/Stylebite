import 'package:flutter_test/flutter_test.dart';
import 'package:stylebite/modules/home/models/home_post_model.dart';

void main() {
  test('an empty tags list from the feed does not need a detail request', () {
    final post = HomePostModel.fromJson(
      {
        'id': 25,
        'post_type': 'outfit',
        'caption': 'outfit 0',
        'tags': <Map<String, dynamic>>[],
      },
      responseType: 'outfit',
    );

    expect(post.tags, isEmpty);
    expect(post.tagsIncluded, isTrue);
    expect(post.needsHashtagHydration, isFalse);
  });

  test('tags named by the feed are kept and do not need a detail request', () {
    final post = HomePostModel.fromJson(
      {
        'id': 26,
        'post_type': 'outfit',
        'caption': 'outfit 1',
        'tags': [
          {'id': 4, 'name': 'linen'},
        ],
      },
      responseType: 'outfit',
    );

    expect(post.tags, ['#linen']);
    expect(post.needsHashtagHydration, isFalse);
  });

  test('a payload that omits tags still needs hydration when none are in the caption', () {
    final post = HomePostModel.fromJson(
      {
        'id': 27,
        'post_type': 'outfit',
        'caption': 'outfit 2',
      },
      responseType: 'outfit',
    );

    expect(post.tagsIncluded, isFalse);
    expect(post.needsHashtagHydration, isTrue);
  });

  test('caption hashtags cover a payload that omits the tags key', () {
    final post = HomePostModel.fromJson(
      {
        'id': 28,
        'post_type': 'outfit',
        'caption': 'outfit 3 #summer',
      },
      responseType: 'outfit',
    );

    expect(post.tags, ['#summer']);
    expect(post.needsHashtagHydration, isFalse);
  });
}
