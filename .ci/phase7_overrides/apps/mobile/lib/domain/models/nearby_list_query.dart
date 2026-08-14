enum NearbySortOrder {
  nearestFirst,
  farthestFirst,
  nameAscending,
}

enum NearbyDistanceFilter {
  all,
  within1Km,
  within5Km,
  within20Km,
}

final class NearbyListQuery {
  const NearbyListQuery({
    this.searchText = '',
    this.sortOrder = NearbySortOrder.nearestFirst,
    this.distanceFilter = NearbyDistanceFilter.all,
  });

  final String searchText;
  final NearbySortOrder sortOrder;
  final NearbyDistanceFilter distanceFilter;
}
