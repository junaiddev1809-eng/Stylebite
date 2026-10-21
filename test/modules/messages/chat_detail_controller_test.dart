import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stylebite/core/utils/local_storage.dart';
import 'package:stylebite/modules/messages/controllers/chat_detail_controller.dart';
import 'package:stylebite/modules/messages/controllers/chat_unread_controller.dart';
import 'package:stylebite/modules/messages/models/chat_models.dart';
import 'package:stylebite/modules/messages/services/chat_api_service.dart';

class MockChatApiService extends Mock implements ChatApiService {}

ChatUserModel _fakeUser() => const ChatUserModel(
  id: 1,
  username: 'other',
  name: 'Other User',
  imageUrl: '',
  isOnline: false,
  isVerifiedBadge: false,
);

ChatPaginationModel _fakePagination({int total = 1}) => ChatPaginationModel(
  currentPage: 1,
  perPage: 20,
  total: total,
  lastPage: 1,
  hasMorePages: false,
);

ChatMessageModel _fakeMessage({int id = 1, bool isMine = false}) =>
    ChatMessageModel(
      id: id,
      body: 'hi',
      senderUsername: isMine ? 'me' : 'other',
      isMine: isMine,
      createdAt: DateTime.now().toIso8601String(),
      timeLabel: 'Now',
      status: 'sent',
      isSeen: false,
    );

ChatMessagesResponseModel _fakeMessagesResponse({
  List<ChatMessageModel> messages = const [],
  int total = 0,
  bool isPendingRequest = false,
  bool isIncomingRequest = false,
  bool isAccepted = false,
}) {
  return ChatMessagesResponseModel(
    statusCode: 1,
    message: '',
    conversationId: 5,
    user: _fakeUser(),
    messages: messages,
    pagination: _fakePagination(total: total),
    isStopped: false,
    isBlockedByMe: false,
    isBlockedByOther: false,
    isPendingRequest: isPendingRequest,
    isIncomingRequest: isIncomingRequest,
    isAccepted: isAccepted,
  );
}

ChatListResponseModel _fakeChatList({required int totalUnreadCount}) {
  return ChatListResponseModel(
    statusCode: 1,
    message: '',
    chats: const [],
    pagination: _fakePagination(),
    totalUnreadCount: totalUnreadCount,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.initStorage();
    Get.testMode = true;
    // fluttertoast has no plugin implementation in the test binding —
    // stub the channel so success/error snackbars don't blow up tests
    // that exercise code paths which happen to show one.
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('PonnamKarthik/fluttertoast'),
          (call) async => true,
        );
  });

  tearDown(() {
    Get.reset();
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('PonnamKarthik/fluttertoast'),
          null,
        );
  });

  group('fetchMessages 403 handling', () {
    test('applies the block banner instead of the generic error state', () async {
      final api = MockChatApiService();
      when(
        () => api.getMessages(any(), page: any(named: 'page')),
      ).thenThrow(
        const ChatApiException(
          message: 'This user has blocked you.',
          httpStatusCode: 403,
          isBlockedByOther: true,
        ),
      );

      final controller = ChatDetailController(
        username: 'other',
        conversationId: 5,
        initialIsMessagingStopped: false,
        apiService: api,
      );

      await controller.fetchMessages(reset: true);

      expect(controller.hasError.value, isFalse);
      expect(controller.isBlocked.value, isTrue);
      expect(controller.isBlockedByMe.value, isFalse);
      expect(controller.isMessagingStopped.value, isTrue);
      expect(
        controller.stoppedBannerText.value,
        'This user has blocked you.',
      );
    });

    test(
      'still shows the generic error state for a non-block failure',
      () async {
        final api = MockChatApiService();
        when(
          () => api.getMessages(any(), page: any(named: 'page')),
        ).thenThrow(
          const ChatApiException(
            message: 'Server error.',
            httpStatusCode: 500,
          ),
        );

        final controller = ChatDetailController(
          username: 'other',
          conversationId: 5,
          initialIsMessagingStopped: false,
          apiService: api,
        );

        await controller.fetchMessages(reset: true);

        expect(controller.hasError.value, isTrue);
        expect(controller.errorMessage.value, 'Server error.');
        expect(controller.isBlocked.value, isFalse);
      },
    );
  });

  group('unread badge refresh', () {
    test('refreshes ChatUnreadController after marking read on open', () async {
      final unreadApi = MockChatApiService();
      when(
        () => unreadApi.getChats(
          search: any(named: 'search'),
          page: any(named: 'page'),
          offset: any(named: 'offset'),
          skip: any(named: 'skip'),
        ),
      ).thenAnswer((_) async => _fakeChatList(totalUnreadCount: 3));

      final unreadController = Get.put(
        ChatUnreadController(apiService: unreadApi),
      );
      await unreadController.refreshUnreadCount();
      expect(unreadController.unreadCount.value, 3);

      // The badge should drop to 0 once the conversation is marked read —
      // simulate the backend now reporting nothing unread.
      when(
        () => unreadApi.getChats(
          search: any(named: 'search'),
          page: any(named: 'page'),
          offset: any(named: 'offset'),
          skip: any(named: 'skip'),
        ),
      ).thenAnswer((_) async => _fakeChatList(totalUnreadCount: 0));

      final chatApi = MockChatApiService();
      when(
        () => chatApi.getMessages(any(), page: any(named: 'page')),
      ).thenAnswer(
        (_) async => _fakeMessagesResponse(
          messages: [_fakeMessage(id: 10)],
          total: 1,
        ),
      );
      when(
        () => chatApi.markRead(
          any(),
          upToMessageId: any(named: 'upToMessageId'),
        ),
      ).thenAnswer((_) async {});

      final controller = ChatDetailController(
        username: 'other',
        conversationId: 5,
        initialIsMessagingStopped: false,
        apiService: chatApi,
      );

      await controller.fetchMessages(reset: true);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      verify(
        () => chatApi.markRead(5, upToMessageId: 10),
      ).called(1);
      expect(unreadController.unreadCount.value, 0);
    });

    test(
      'does nothing (and does not throw) when ChatUnreadController is not registered',
      () async {
        final chatApi = MockChatApiService();
        when(
          () => chatApi.getMessages(any(), page: any(named: 'page')),
        ).thenAnswer(
          (_) async => _fakeMessagesResponse(
            messages: [_fakeMessage(id: 10)],
            total: 1,
          ),
        );
        when(
          () => chatApi.markRead(
            any(),
            upToMessageId: any(named: 'upToMessageId'),
          ),
        ).thenAnswer((_) async {});

        final controller = ChatDetailController(
          username: 'other',
          conversationId: 5,
          initialIsMessagingStopped: false,
          apiService: chatApi,
        );

        expect(
          () async => controller.fetchMessages(reset: true),
          returnsNormally,
        );
      },
    );
  });

  group('socket subscription idempotency', () {
    test(
      're-subscribing (e.g. on unblock) does not leak duplicate listeners',
      () async {
        final api = MockChatApiService();
        when(
          () => api.getMessages(any(), page: any(named: 'page')),
        ).thenAnswer((_) async => _fakeMessagesResponse());
        when(() => api.unblockUser(any())).thenAnswer((_) async {});

        final controller = ChatDetailController(
          username: 'other',
          conversationId: 5,
          initialIsMessagingStopped: false,
          apiService: api,
        );

        expect(controller.debugSocketSubscriptionCount, 0);

        controller.onInit();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(controller.debugSocketSubscriptionCount, 6);

        await controller.unblockUser();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(
          controller.debugSocketSubscriptionCount,
          6,
          reason:
              'unblockUser() re-running _initSocket() must not leave the '
              'original 6 listeners orphaned alongside a fresh 6',
        );
      },
    );
  });

  group('chat request flow', () {
    ChatDetailController controllerFor(MockChatApiService api) {
      return ChatDetailController(
        username: 'other',
        conversationId: 5,
        initialIsMessagingStopped: false,
        apiService: api,
      );
    }

    test('receiver sees an incoming request and cannot reply yet', () async {
      final api = MockChatApiService();
      when(
        () => api.getMessages(any(), page: any(named: 'page')),
      ).thenAnswer(
        (_) async => _fakeMessagesResponse(
          messages: [_fakeMessage(id: 1, isMine: false)],
          total: 1,
          isPendingRequest: true,
          isIncomingRequest: true,
        ),
      );

      final controller = controllerFor(api);
      await controller.fetchMessages(reset: true);

      expect(controller.isIncomingChatRequest.value, isTrue);
      expect(controller.isWaitingForReply.value, isFalse);
      expect(controller.isComposerDisabled, isTrue);
    });

    test('receiver can infer a request from unread inbound messages', () async {
      final api = MockChatApiService();
      when(
        () => api.getMessages(any(), page: any(named: 'page')),
      ).thenAnswer(
        (_) async => _fakeMessagesResponse(
          messages: [
            _fakeMessage(id: 2, isMine: false),
            _fakeMessage(id: 1, isMine: false),
          ],
          total: 2,
        ),
      );

      final controller = controllerFor(api);
      await controller.fetchMessages(reset: true);

      expect(controller.isIncomingChatRequest.value, isTrue);
      expect(controller.isComposerDisabled, isTrue);
    });

    test('accepting a request unlocks the composer', () async {
      final api = MockChatApiService();
      when(
        () => api.getMessages(any(), page: any(named: 'page')),
      ).thenAnswer(
        (_) async => _fakeMessagesResponse(
          messages: [_fakeMessage(id: 1, isMine: false)],
          total: 1,
          isIncomingRequest: true,
          isPendingRequest: true,
        ),
      );
      when(() => api.acceptChatRequest(any())).thenAnswer((_) async {});

      final controller = controllerFor(api);
      await controller.fetchMessages(reset: true);
      await controller.acceptChatRequest();

      expect(controller.isIncomingChatRequest.value, isFalse);
      expect(controller.isWaitingForReply.value, isFalse);
      expect(controller.isComposerDisabled, isFalse);
      verify(() => api.acceptChatRequest(5)).called(1);
    });

    test(
      'sender can send up to 3 messages before the request is accepted',
      () async {
        final api = MockChatApiService();
        when(
          () => api.getMessages(any(), page: any(named: 'page')),
        ).thenAnswer(
          (_) async => _fakeMessagesResponse(
            messages: [
              _fakeMessage(id: 2, isMine: true),
              _fakeMessage(id: 1, isMine: true),
            ],
            total: 2,
            isPendingRequest: true,
          ),
        );

        final controller = controllerFor(api);
        await controller.fetchMessages(reset: true);

        expect(controller.isIncomingChatRequest.value, isFalse);
        expect(controller.isWaitingForReply.value, isFalse);
        expect(controller.isComposerDisabled, isFalse);
      },
    );

    test(
      'sender is locked after 3 messages until the request is accepted',
      () async {
        final api = MockChatApiService();
        when(
          () => api.getMessages(any(), page: any(named: 'page')),
        ).thenAnswer(
          (_) async => _fakeMessagesResponse(
            messages: [
              _fakeMessage(id: 3, isMine: true),
              _fakeMessage(id: 2, isMine: true),
              _fakeMessage(id: 1, isMine: true),
            ],
            total: 3,
            isPendingRequest: true,
          ),
        );

        final controller = controllerFor(api);
        await controller.fetchMessages(reset: true);

        expect(controller.isIncomingChatRequest.value, isFalse);
        expect(controller.isWaitingForReply.value, isTrue);
        expect(controller.isComposerDisabled, isTrue);
      },
    );

    test('a reply from the other person accepts the chat', () async {
      final api = MockChatApiService();
      when(
        () => api.getMessages(any(), page: any(named: 'page')),
      ).thenAnswer(
        (_) async => _fakeMessagesResponse(
          messages: [
            _fakeMessage(id: 2, isMine: false),
            _fakeMessage(id: 1, isMine: true),
          ],
          total: 2,
        ),
      );

      final controller = controllerFor(api);
      await controller.fetchMessages(reset: true);

      expect(controller.isIncomingChatRequest.value, isFalse);
      expect(controller.isWaitingForReply.value, isFalse);
      expect(controller.isComposerDisabled, isFalse);
    });
  });
}
