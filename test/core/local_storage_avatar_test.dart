import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stylebite/core/utils/local_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LocalStorage.initStorage();
  });

  test('setAvatarUrl updates the reactive home avatar listenable', () {
    expect(LocalStorage.avatarUrlListenable.value, isEmpty);

    LocalStorage.setAvatarUrl(avatarUrl: 'http://10.0.2.2:8000/avatar.jpg');

    expect(LocalStorage.getAvatarUrl(), 'http://10.0.2.2:8000/avatar.jpg');
    expect(
      LocalStorage.avatarUrlListenable.value,
      'http://10.0.2.2:8000/avatar.jpg',
    );
  });

  test('removeAvatarUrl clears the previous account avatar', () async {
    LocalStorage.setAvatarUrl(avatarUrl: 'http://example.test/old.jpg');
    await LocalStorage.removeAvatarUrl();

    expect(LocalStorage.getAvatarUrl(), isNull);
    expect(LocalStorage.avatarUrlListenable.value, isEmpty);
  });

  test('account switch can replace the avatar without keeping the old url', () async {
    LocalStorage.setAvatarUrl(avatarUrl: 'http://example.test/owner.jpg');
    await LocalStorage.removeAvatarUrl();
    LocalStorage.setAvatarUrl(avatarUrl: 'http://example.test/public.jpg');

    expect(LocalStorage.getAvatarUrl(), 'http://example.test/public.jpg');
    expect(
      LocalStorage.avatarUrlListenable.value,
      'http://example.test/public.jpg',
    );
  });
}
