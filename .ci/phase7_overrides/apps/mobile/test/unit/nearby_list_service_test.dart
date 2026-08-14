import 'package:flutter_test/flutter_test.dart';
import 'package:nearby_contacts/domain/models/local_contact.dart';
import 'package:nearby_contacts/domain/models/local_nearby_contact.dart';
import 'package:nearby_contacts/domain/models/nearby_list_query.dart';
import 'package:nearby_contacts/domain/policies/nearby_list_service.dart';
import 'package:nearby_contacts/domain/value_objects/distance.dart';

void main() {
  const NearbyListService service = NearbyListService();

  LocalNearbyContact row(String id, String name, double? meters) {
    return LocalNearbyContact(
      contact: LocalContact(
        id: id,
        displayName: name,
        phoneNumbers: <String>['555$id'],
      ),
      distance: meters == null ? null : Distance.meters(meters),
    );
  }

  final List<LocalNearbyContact> rows = <LocalNearbyContact>[
    row('a', 'Asha', 199),
    row('b', 'Bina', 1000),
    row('c', 'Chandra', 1001),
    row('d', 'Deepa', 5000),
    row('e', 'Esha', 5001),
    row('f', 'Farah', 20000),
    row('g', 'Gita', 20001),
    row('z', 'Zoya', null),
  ];

  test('search matches name and phone case-insensitively', () {
    final byName = service.apply(
      rows: rows,
      query: const NearbyListQuery(searchText: 'ASHA'),
    );
    expect(byName.map((row) => row.contact.id), <String>['a']);

    final byPhone = service.apply(
      rows: rows,
      query: const NearbyListQuery(searchText: '555d'),
    );
    expect(byPhone.map((row) => row.contact.id), <String>['d']);
  });

  test('1 km filter includes exactly 1000m and excludes 1001m/unknown', () {
    final result = service.apply(
      rows: rows,
      query: const NearbyListQuery(
        distanceFilter: NearbyDistanceFilter.within1Km,
      ),
    );
    expect(result.map((row) => row.contact.id), <String>['a', 'b']);
  });

  test('5 km filter includes exactly 5000m and excludes 5001m', () {
    final result = service.apply(
      rows: rows,
      query: const NearbyListQuery(
        distanceFilter: NearbyDistanceFilter.within5Km,
      ),
    );
    expect(result.map((row) => row.contact.id), <String>['a', 'b', 'c', 'd']);
  });

  test('20 km filter includes exactly 20000m and excludes 20001m', () {
    final result = service.apply(
      rows: rows,
      query: const NearbyListQuery(
        distanceFilter: NearbyDistanceFilter.within20Km,
      ),
    );
    expect(
      result.map((row) => row.contact.id),
      <String>['a', 'b', 'c', 'd', 'e', 'f'],
    );
  });

  test('farthest sort keeps unknown locations after known distances', () {
    final result = service.apply(
      rows: rows,
      query: const NearbyListQuery(sortOrder: NearbySortOrder.farthestFirst),
    );
    expect(result.first.contact.id, 'g');
    expect(result.last.contact.id, 'z');
  });

  test('name sort is alphabetical independent of distance', () {
    final result = service.apply(
      rows: rows.reversed.toList(),
      query: const NearbyListQuery(sortOrder: NearbySortOrder.nameAscending),
    );
    expect(result.first.contact.displayName, 'Asha');
    expect(result.last.contact.displayName, 'Zoya');
  });
}
