import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stylebite/core/utils/local_storage.dart';
import 'package:stylebite/modules/messages/services/chat_socket_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.initStorage();
  });

  group('ChatSocketService.disconnect', () {
    test('clears confirmed conversation subscriptions', () async {
      final service = ChatSocketService.instance;
      service.debugMarkConversationConfirmed(101);
      service.debugMarkConversationConfirmed(202);
      expect(service.debugIsConversationConfirmed(101), isTrue);
      expect(service.debugIsConversationConfirmed(202), isTrue);

      await service.disconnect();

      expect(service.debugIsConversationConfirmed(101), isFalse);
      expect(service.debugIsConversationConfirmed(202), isFalse);
    });

    test('is safe to call when nothing was ever confirmed', () async {
      final service = ChatSocketService.instance;

      await service.disconnect();

      expect(service.debugIsConversationConfirmed(1), isFalse);
    });
  });
}
