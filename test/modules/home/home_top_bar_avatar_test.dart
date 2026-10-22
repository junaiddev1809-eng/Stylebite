import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stylebite/core/utils/local_storage.dart';
import 'package:stylebite/modules/profile/controllers/profile_controller.dart';

/// Mirrors the HomeTopBar avatar binding without starting feed, notifications,
/// or ProfileController.
class _SessionAvatarProbe extends StatelessWidget {
  const _SessionAvatarProbe();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocalStorage.avatarUrlListenable,
      builder: (context, avatarUrl, _) {
        return Text(avatarUrl.trim().isEmpty ? 'empty' : avatarUrl);
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LocalStorage.initStorage();
    Get.testMode = true;
    Get.reset();
  });

  tearDown(Get.reset);

  testWidgets('home avatar binding uses session storage without ProfileController', (
    tester,
  ) async {
    LocalStorage.setAvatarUrl(avatarUrl: 'http://10.0.2.2:8000/avatar.jpg');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: _SessionAvatarProbe(),
        ),
      ),
    );

    expect(find.text('http://10.0.2.2:8000/avatar.jpg'), findsOneWidget);
    expect(Get.isRegistered<ProfileController>(), isFalse);
  });

  testWidgets('session avatar updates rebuild the home avatar binding', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: _SessionAvatarProbe(),
        ),
      ),
    );
    expect(find.text('empty'), findsOneWidget);

    LocalStorage.setAvatarUrl(avatarUrl: 'http://10.0.2.2:8000/new.jpg');
    await tester.pump();

    expect(find.text('http://10.0.2.2:8000/new.jpg'), findsOneWidget);
    expect(Get.isRegistered<ProfileController>(), isFalse);
  });
}
