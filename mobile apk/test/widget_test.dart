import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_apk/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const WeHelpAgentApp(isLoggedIn: false));

    // Verify login screen elements exist
    expect(find.text('We Help'), findsOneWidget);
    expect(find.text('Charity Society and Education'), findsOneWidget);
  });
}
