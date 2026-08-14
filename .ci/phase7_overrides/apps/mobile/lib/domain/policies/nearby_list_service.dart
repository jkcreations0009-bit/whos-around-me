import '../models/local_nearby_contact.dart';
import '../models/nearby_list_query.dart';

final class NearbyListService {
  const NearbyListService();

  List<LocalNearbyContact> apply({
    required List<LocalNearbyContact> rows,
    required NearbyListQuery query,
  }) {
    final String search = query.searchText.trim().toLowerCase();
    final double? maximumMeters = _maximumMeters(query.distanceFilter);

    final List<LocalNearbyContact> result = rows.where((row) {
      if (search.isNotEmpty && !_matchesSearch(row, search)) return false;
      if (maximumMeters != null) {
        final double? meters = row.distance?.meters;
        if (meters == null || meters > maximumMeters) return false;
      }
      return true;
    }).toList(growable: true);

    result.sort((a, b) => _compare(a, b, query.sortOrder));
    return List<LocalNearbyContact>.unmodifiable(result);
  }

  bool _matchesSearch(LocalNearbyContact row, String search) {
    if (row.contact.displayName.toLowerCase().contains(search)) return true;
    return row.contact.phoneNumbers.any(
      (String value) => value.toLowerCase().contains(search),
    );
  }

  double? _maximumMeters(NearbyDistanceFilter filter) {
    return switch (filter) {
      NearbyDistanceFilter.all => null,
      NearbyDistanceFilter.within1Km => 1000,
      NearbyDistanceFilter.within5Km => 5000,
      NearbyDistanceFilter.within20Km => 20000,
    };
  }

  int _compare(
    LocalNearbyContact a,
    LocalNearbyContact b,
    NearbySortOrder sortOrder,
  ) {
    if (sortOrder == NearbySortOrder.nameAscending) {
      return _compareNames(a, b);
    }

    final double? aMeters = a.distance?.meters;
    final double? bMeters = b.distance?.meters;
    if (aMeters == null && bMeters == null) return _compareNames(a, b);
    if (aMeters == null) return 1;
    if (bMeters == null) return -1;

    final int distanceComparison = aMeters.compareTo(bMeters);
    if (distanceComparison != 0) {
      return sortOrder == NearbySortOrder.nearestFirst
          ? distanceComparison
          : -distanceComparison;
    }
    return _compareNames(a, b);
  }

  int _compareNames(LocalNearbyContact a, LocalNearbyContact b) {
    final int byName = a.contact.displayName
        .toLowerCase()
        .compareTo(b.contact.displayName.toLowerCase());
    if (byName != 0) return byName;
    return a.contact.id.compareTo(b.contact.id);
  }
}
