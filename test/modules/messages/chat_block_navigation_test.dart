import 'package:flutter_test/flutter_test.dart';
import 'package:stylebite/modules/messages/models/chat_models.dart';
import 'package:stylebite/modules/messages/utils/chat_block_navigation.dart';

void main() {
  group('resolveBlockedChatNavigation', () {
    test('routes to the block banner when the current user blocked them', () {
      const error = ChatApiException(
        message: 'You have blocked this user.',
        httpStatusCode: 403,
        isBlockedByMe: true,
      );

      final result = resolveBlockedChatNavigation(error, username: 'alex');

      expect(result, isNotNull);
      expect(result!.username, 'alex');
      expect(result.conversationId, 0);
      expect(result.isBlockedByMe, isTrue);
      expect(result.isBlockedByOther, isFalse);
    });

    test('routes to the block banner when the other user blocked them', () {
      const error = ChatApiException(
        message: 'This user has blocked you.',
        httpStatusCode: 403,
        isBlockedByOther: true,
      );

      final result = resolveBlockedChatNavigation(error, username: 'alex');

      expect(result, isNotNull);
      expect(result!.isBlockedByOther, isTrue);
      expect(result.isBlockedByMe, isFalse);
    });

    test('carries a known conversationId through when one is available', () {
      const error = ChatApiException(
        message: 'You have blocked this user.',
        httpStatusCode: 403,
        isBlockedByMe: true,
      );

      final result = resolveBlockedChatNavigation(
        error,
        username: 'alex',
        knownConversationId: 42,
      );

      expect(result!.conversationId, 42);
    });

    test('returns null for a 403 that is not actually a block', () {
      const error = ChatApiException(
        message: 'Forbidden.',
        httpStatusCode: 403,
      );

      expect(resolveBlockedChatNavigation(error, username: 'alex'), isNull);
    });

    test('returns null for a non-403 failure even if block flags are set', () {
      const error = ChatApiException(
        message: 'Validation failed.',
        httpStatusCode: 422,
        isBlockedByMe: true,
      );

      expect(resolveBlockedChatNavigation(error, username: 'alex'), isNull);
    });

    test('returns null for an unrelated 404', () {
      const error = ChatApiException(
        message: 'User not found.',
        httpStatusCode: 404,
      );

      expect(resolveBlockedChatNavigation(error, username: 'alex'), isNull);
    });
  });
}
