import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearby_contacts/app/app.dart';
import 'package:nearby_contacts/app/providers.dart';
import 'package:nearby_contacts/domain/models/local_contact.dart';
import 'package:nearby_contacts/domain/models/location_source.dart';
import 'package:nearby_contacts/domain/models/saved_contact_location.dart';
import 'package:nearby_contacts/domain/repositories/contact_location_repository.dart';
import 'package:nearby_contacts/domain/value_objects/geo_coordinate.dart';

import '../fakes/fake_contact_location_repository.dart';
import '../fakes/fake_platform_contacts_service.dart';
import '../fakes/fake_platform_location_service.dart';

void main() {
  testWidgets("Who's Around Me renders local distance and proximity controls", (
    WidgetTester tester,
  ) async {
    final FakePlatformContactsService contacts = FakePlatformContactsService(
      contacts: const <LocalContact>[
        LocalContact(
          id: 'asha',
          displayName: 'Asha Rao',
          phoneNumbers: <String>['9999999999'],
        ),
        LocalContact(id: 'ravi', displayName: 'Ravi Kumar'),
      ],
    );
    final FakePlatformLocationService location = FakePlatformLocationService();
    final ContactLocationRepository savedLocations =
        FakeContactLocationRepository(
      locations: <SavedContactLocation>[
        SavedContactLocation(
          contactId: 'asha',
          label: 'Home',
          coordinate: GeoCoordinate(latitude: 17.4490, longitude: 78.3917),
          source: LocationSource.home,
          updatedAtUtc: DateTime.utc(2026, 8, 14, 8),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          platformContactsServiceProvider.overrideWithValue(contacts),
          platformLocationServiceProvider.overrideWithValue(location),
          contactLocationRepositoryProvider.overrideWithValue(savedLocations),
        ],
        child: const WhosAroundMeApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Who's Around Me"), findsOneWidget);
    expect(find.text('Private Local Mode'), findsOneWidget);
    expect(find.text('Asha Rao'), findsOneWidget);
    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(find.text('≤ 1 km'), findsOneWidget);
    expect(find.text('≤ 5 km'), findsOneWidget);
    expect(find.text('≤ 20 km'), findsOneWidget);
    expect(find.text('Very close'), findsOneWidget);
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.textContaining('m'), findsWidgets);
  });

  testWidgets('distance filter excludes contacts with unknown location', (
    WidgetTester tester,
  ) async {
    final FakePlatformContactsService contacts = FakePlatformContactsService(
      contacts: const <LocalContact>[
        LocalContact(id: 'near', displayName: 'Near Person'),
        LocalContact(id: 'unknown', displayName: 'Unknown Person'),
      ],
    );
    final ContactLocationRepository savedLocations =
        FakeContactLocationRepository(
      locations: <SavedContactLocation>[
        SavedContactLocation(
          contactId: 'near',
          label: 'Saved',
          coordinate: GeoCoordinate(latitude: 17.4490, longitude: 78.3917),
          source: LocationSource.manual,
          updatedAtUtc: DateTime.utc(2026, 8, 14, 8),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          platformContactsServiceProvider.overrideWithValue(contacts),
          platformLocationServiceProvider.overrideWithValue(
            FakePlatformLocationService(),
          ),
          contactLocationRepositoryProvider.overrideWithValue(savedLocations),
        ],
        child: const WhosAroundMeApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unknown Person'), findsOneWidget);
    await tester.tap(find.text('≤ 1 km'));
    await tester.pumpAndSettle();

    expect(find.text('Near Person'), findsOneWidget);
    expect(find.text('Unknown Person'), findsNothing);
  });
}
