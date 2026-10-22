import 'package:flutter_test/flutter_test.dart';
import 'package:stylebite/modules/profile/utils/profile_pagination.dart';

void main() {
  group('isNearProfilePaginationEdge', () {
    test('a list parked at the top does not request the next page', () {
      expect(
        isNearProfilePaginationEdge(pixels: 0, maxScrollExtent: 1800),
        isFalse,
      );
      expect(
        isNearProfilePaginationEdge(pixels: 200, maxScrollExtent: 1800),
        isFalse,
      );
    });

    test('scrolling near the bottom requests the next page', () {
      expect(
        isNearProfilePaginationEdge(pixels: 1600, maxScrollExtent: 1800),
        isTrue,
      );
      expect(
        isNearProfilePaginationEdge(pixels: 1800, maxScrollExtent: 1800),
        isTrue,
      );
    });

    test('repeated checks at the top stay false', () {
      for (var i = 0; i < 5; i++) {
        expect(
          isNearProfilePaginationEdge(pixels: 40, maxScrollExtent: 2400),
          isFalse,
        );
      }
    });

    test('the last page is not forced by the edge check alone', () {
      // When has_more_pages is false the controllers skip the request.
      // The edge helper only answers "are we near the bottom?"
      expect(
        isNearProfilePaginationEdge(pixels: 2400, maxScrollExtent: 2400),
        isTrue,
      );
    });

    test('pull-to-refresh starts from the top, so the edge is not near', () {
      expect(
        isNearProfilePaginationEdge(pixels: 0, maxScrollExtent: 2400),
        isFalse,
      );
    });

    test('short or empty lists still allow intended fill pagination', () {
      expect(
        isNearProfilePaginationEdge(pixels: 0, maxScrollExtent: 0),
        isTrue,
      );
      expect(
        isNearProfilePaginationEdge(pixels: 0, maxScrollExtent: 100),
        isTrue,
      );
    });
  });
}
