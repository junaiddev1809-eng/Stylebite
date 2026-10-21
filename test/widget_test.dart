import 'package:flutter_test/flutter_test.dart';

import 'package:stylebite/main.dart';

void main() {
  testWidgets('App shows splash then navigates to intro', (tester) async {
    await tester.pumpWidget(const StyleBiteApp());

    expect(find.text('Your Daily Style Bite'), findsOneWidget);
    expect(find.text('Enter App'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Discover Fresh Looks'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });
}
