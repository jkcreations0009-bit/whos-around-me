import 'dart:async';

import 'package:nearby_contacts/domain/models/saved_contact_location.dart';
import 'package:nearby_contacts/domain/repositories/contact_location_repository.dart';

final class FakeContactLocationRepository implements ContactLocationRepository {
  FakeContactLocationRepository({
    List<SavedContactLocation> locations = const <SavedContactLocation>[],
  }) : _locations = List<SavedContactLocation>.of(locations);

  final StreamController<List<SavedContactLocation>> _controller =
      StreamController<List<SavedContactLocation>>.broadcast();
  List<SavedContactLocation> _locations;

  @override
  Future<SavedContactLocation?> findByContactId(String contactId) async {
    for (final SavedContactLocation location in _locations) {
      if (location.contactId == contactId) return location;
    }
    return null;
  }

  @override
  Future<List<SavedContactLocation>> getAll() async =>
      List<SavedContactLocation>.unmodifiable(_locations);

  @override
  Future<void> remove(String contactId) async {
    _locations = _locations
        .where((SavedContactLocation item) => item.contactId != contactId)
        .toList(growable: false);
    _controller.add(List<SavedContactLocation>.unmodifiable(_locations));
  }

  @override
  Future<void> save(SavedContactLocation location) async {
    final List<SavedContactLocation> next = _locations
        .where((SavedContactLocation item) => item.contactId != location.contactId)
        .toList(growable: true)
      ..add(location);
    _locations = next;
    _controller.add(List<SavedContactLocation>.unmodifiable(_locations));
  }

  @override
  Stream<List<SavedContactLocation>> watchSavedLocations() async* {
    yield List<SavedContactLocation>.unmodifiable(_locations);
    yield* _controller.stream;
  }

  Future<void> dispose() => _controller.close();
}
