import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearby_contacts/app/app.dart';
import 'package:nearby_contacts/app/providers.dart';

import 'fakes/fake_platform_contacts_service.dart';
import 'fakes/fake_platform_location_service.dart';

void main() {
  testWidgets("Who's Around Me root widget renders", (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          platformContactsServiceProvider.overrideWithValue(
            FakePlatformContactsService(),
          ),
          platformLocationServiceProvider.overrideWithValue(
            FakePlatformLocationService(),
          ),
        ],
        child: const WhosAroundMeApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Who's Around Me"), findsOneWidget);
    expect(find.text('Private Local Mode'), findsOneWidget);
  });
}
