import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylebite/modules/messages/screen/messages_screen.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows a spinner while loading the next page', (tester) async {
    await tester.pumpWidget(
      wrap(const ChatListFooter(isLoadingMore: true, hasMore: true)),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No more data'), findsNothing);
  });

  testWidgets('shows nothing while more pages remain and none is loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const ChatListFooter(isLoadingMore: false, hasMore: true)),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('No more data'), findsNothing);
  });

  testWidgets('shows the end-of-list message once every page is loaded', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const ChatListFooter(isLoadingMore: false, hasMore: false)),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('No more data'), findsOneWidget);
  });
}
