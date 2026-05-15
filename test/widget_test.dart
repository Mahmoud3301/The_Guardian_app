import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('Guardian app launches', (WidgetTester tester) async {
    await tester.pumpWidget(const GuardianApp());
    expect(find.text('Welcome to the Guardian'), findsOneWidget);
  });
}
