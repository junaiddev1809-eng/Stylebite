import 'package:flutter_test/flutter_test.dart';
import 'package:stylebite/modules/profile/models/profile_model.dart';
import 'package:stylebite/modules/profile/utils/profile_overview_query.dart';

void main() {
  test('a section request names only that page', () {
    expect(
      profileOverviewQuery(outfitPage: 1),
      {'per_page': '10', 'outfit_page': '1'},
    );
    expect(
      profileSectionPages(ProfileContentTab.food, 1).foodPage,
      1,
    );
    expect(
      profileSectionPages(ProfileContentTab.food, 1).outfitPage,
      isNull,
    );
    expect(
      profileOverviewQuery(foodPage: 1),
      {'per_page': '10', 'food_page': '1'},
    );
    expect(
      profileOverviewQuery(savedPage: 2, perPage: 10),
      {'per_page': '10', 'saved_page': '2'},
    );
  });

  test('the profile grid prefers a thumbnail and falls back to the full image', () {
    const withThumb = ProfilePostModel(
      id: 1,
      postType: 'outfit',
      caption: 'Coat',
      mediaKind: 'image',
      location: '',
      likeCount: 1,
      commentCount: 0,
      shareCount: 0,
      saveCount: 0,
      ratingAvg: null,
      media: [
        ProfileMediaModel(
          id: 1,
          mediaType: 'image',
          fileUrl: 'https://example.com/full.jpg',
          thumbnailUrl: 'https://example.com/thumb.jpg',
        ),
      ],
      createdAt: '',
    );
    expect(withThumb.gridImageUrl, 'https://example.com/thumb.jpg');
    expect(withThumb.primaryImageUrl, 'https://example.com/full.jpg');

    const fullOnly = ProfilePostModel(
      id: 2,
      postType: 'outfit',
      caption: 'Shirt',
      mediaKind: 'image',
      location: '',
      likeCount: 1,
      commentCount: 0,
      shareCount: 0,
      saveCount: 0,
      ratingAvg: null,
      media: [
        ProfileMediaModel(
          id: 2,
          mediaType: 'image',
          fileUrl: 'https://example.com/shirt.jpg',
          thumbnailUrl: '',
        ),
      ],
      createdAt: '',
    );
    expect(fullOnly.gridImageUrl, 'https://example.com/shirt.jpg');
  });
}
