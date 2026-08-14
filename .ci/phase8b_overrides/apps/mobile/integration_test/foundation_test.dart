import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nearby_contacts/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('application starts', (WidgetTester tester) async {
    await app.main();
    await tester.pumpAndSettle();
    expect(find.text('Nearby Contacts foundation ready'), findsOneWidget);
  });
}
