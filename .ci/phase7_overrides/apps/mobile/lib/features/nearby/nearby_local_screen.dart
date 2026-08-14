import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/contact_access.dart';
import '../../domain/models/local_contact.dart';
import '../../domain/models/local_nearby_contact.dart';
import '../../domain/models/location_access.dart';
import '../../domain/models/location_observation.dart';
import '../../domain/models/nearby_list_query.dart';
import '../../domain/models/proximity_category.dart';
import '../../domain/models/proximity_preferences.dart';
import '../../domain/models/saved_contact_location.dart';
import '../../domain/policies/local_nearby_service.dart';
import '../../domain/policies/nearby_list_service.dart';
import '../../domain/repositories/contact_location_repository.dart';
import '../../domain/repositories/contacts_repository.dart';
import '../../domain/repositories/user_location_repository.dart';

final class NearbyLocalScreen extends ConsumerStatefulWidget {
  const NearbyLocalScreen({super.key});

  @override
  ConsumerState<NearbyLocalScreen> createState() => _NearbyLocalScreenState();
}

final class _NearbyLocalScreenState extends ConsumerState<NearbyLocalScreen> {
  static const LocalNearbyService _nearbyService = LocalNearbyService();
  static const NearbyListService _listService = NearbyListService();

  ContactAccess _contactAccess = const ContactAccess.notDetermined();
  LocationAccess _locationAccess = const LocationAccess.notDetermined();
  List<LocalContact> _contacts = const <LocalContact>[];
  Map<String, SavedContactLocation> _savedLocations =
      const <String, SavedContactLocation>{};
  LocationObservation? _location;
  String _query = '';
  NearbySortOrder _sortOrder = NearbySortOrder.nearestFirst;
  NearbyDistanceFilter _distanceFilter = NearbyDistanceFilter.all;
  bool _busy = true;
  String? _message;
  StreamSubscription<List<LocalContact>>? _contactsSubscription;
  StreamSubscription<List<SavedContactLocation>>? _savedLocationsSubscription;

  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(_initialize));
  }

  @override
  void dispose() {
    if (_contactsSubscription != null) {
      unawaited(_contactsSubscription!.cancel());
    }
    if (_savedLocationsSubscription != null) {
      unawaited(_savedLocationsSubscription!.cancel());
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    final ContactsRepository contacts = ref.read(contactsRepositoryProvider);
    final ContactLocationRepository savedLocations =
        ref.read(contactLocationRepositoryProvider);
    final UserLocationRepository userLocation =
        ref.read(userLocationRepositoryProvider);

    _contactsSubscription = contacts.watchContacts().listen((value) {
      if (mounted) setState(() => _contacts = value);
    });
    _savedLocationsSubscription = savedLocations.watchSavedLocations().listen(
      (List<SavedContactLocation> value) {
        if (!mounted) return;
        setState(() {
          _savedLocations = <String, SavedContactLocation>{
            for (final SavedContactLocation location in value)
              location.contactId: location,
          };
        });
      },
      onError: (Object error) {
        if (mounted) _setMessage('Saved contact locations are unavailable.');
      },
    );

    try {
      final ContactAccess contactAccess = await contacts.getAccess();
      final LocationAccess locationAccess = await userLocation.getAccess();
      if (contactAccess.canReadContacts) await contacts.refreshContacts();

      LocationObservation? observation;
      if (locationAccess.canUseForeground) {
        observation = await userLocation.refreshCurrentLocation();
      }

      if (!mounted) return;
      setState(() {
        _contactAccess = contactAccess;
        _locationAccess = locationAccess;
        _location = observation;
        _busy = false;
      });
    } on MissingPluginException {
      _setPlatformNotReady();
    } on PlatformException catch (error) {
      _setMessage(error.message ?? 'Platform access is unavailable.');
    }
  }

  Future<void> _enableContacts() async {
    setState(() => _busy = true);
    try {
      final ContactsRepository repository = ref.read(contactsRepositoryProvider);
      final ContactAccess access = await repository.requestAccess();
      if (access.canReadContacts) await repository.refreshContacts();
      if (!mounted) return;
      setState(() {
        _contactAccess = access;
        _busy = false;
      });
    } on MissingPluginException {
      _setPlatformNotReady();
    } on PlatformException catch (error) {
      _setMessage(error.message ?? 'Could not access contacts.');
    }
  }

  Future<void> _useMyLocationPrivately() async {
    setState(() => _busy = true);
    try {
      final UserLocationRepository repository =
          ref.read(userLocationRepositoryProvider);
      LocationAccess access = await repository.getAccess();
      if (!access.canUseForeground) {
        access = await repository.requestWhenInUseAccess();
      }
      LocationObservation? observation;
      if (access.canUseForeground) {
        observation = await repository.refreshCurrentLocation();
      }
      if (!mounted) return;
      setState(() {
        _locationAccess = access;
        _location = observation;
        _busy = false;
      });
    } on MissingPluginException {
      _setPlatformNotReady();
    } on PlatformException catch (error) {
      _setMessage(error.message ?? 'Could not obtain your location.');
    }
  }

  void _setPlatformNotReady() {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = 'Native Android/iOS bridge has not been installed on this build.';
    });
  }

  void _setMessage(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = message;
    });
  }

  List<LocalNearbyContact> get _visibleRows {
    final List<LocalNearbyContact> rows = _nearbyService.build(
      contacts: _contacts,
      savedLocationsByContactId: _savedLocations,
      userLocation: _location,
      preferences: ProximityPreferences.defaults(),
    );
    return _listService.apply(
      rows: rows,
      query: NearbyListQuery(
        searchText: _query,
        sortOrder: _sortOrder,
        distanceFilter: _distanceFilter,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<LocalNearbyContact> rows = _visibleRows;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Who's Around Me"),
        actions: const <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Chip(
                avatar: Icon(Icons.visibility_off_outlined, size: 18),
                label: Text('Private'),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _PrivateLocationCard(
                locationAccess: _locationAccess,
                location: _location,
                onUseLocation: _useMyLocationPrivately,
              ),
            ),
            if (!_contactAccess.canReadContacts)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _ContactPermissionCard(
                  access: _contactAccess,
                  onEnable: _enableContacts,
                ),
              ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: MaterialBanner(
                  content: Text(_message!),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => setState(() => _message = null),
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SearchBar(
                hintText: 'Search contacts',
                leading: const Icon(Icons.search),
                onChanged: (String value) => setState(() => _query = value),
              ),
            ),
            _NearbyControls(
              distanceFilter: _distanceFilter,
              sortOrder: _sortOrder,
              onDistanceFilterChanged: (NearbyDistanceFilter value) {
                setState(() => _distanceFilter = value);
              },
              onSortChanged: (NearbySortOrder value) {
                setState(() => _sortOrder = value);
              },
            ),
            Expanded(
              child: rows.isEmpty
                  ? _EmptyNearbyResults(
                      access: _contactAccess,
                      hasContacts: _contacts.isNotEmpty,
                      hasLocation: _location != null,
                      hasActiveFilter:
                          _distanceFilter != NearbyDistanceFilter.all ||
                              _query.trim().isNotEmpty,
                    )
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (BuildContext context, int index) {
                        return _NearbyContactTile(row: rows[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _NearbyControls extends StatelessWidget {
  const _NearbyControls({
    required this.distanceFilter,
    required this.sortOrder,
    required this.onDistanceFilterChanged,
    required this.onSortChanged,
  });

  final NearbyDistanceFilter distanceFilter;
  final NearbySortOrder sortOrder;
  final ValueChanged<NearbyDistanceFilter> onDistanceFilterChanged;
  final ValueChanged<NearbySortOrder> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _filterChip('All', NearbyDistanceFilter.all),
                const SizedBox(width: 8),
                _filterChip('≤ 1 km', NearbyDistanceFilter.within1Km),
                const SizedBox(width: 8),
                _filterChip('≤ 5 km', NearbyDistanceFilter.within5Km),
                const SizedBox(width: 8),
                _filterChip('≤ 20 km', NearbyDistanceFilter.within20Km),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: PopupMenuButton<NearbySortOrder>(
              initialValue: sortOrder,
              onSelected: onSortChanged,
              itemBuilder: (BuildContext context) => const <
                  PopupMenuEntry<NearbySortOrder>>[
                PopupMenuItem<NearbySortOrder>(
                  value: NearbySortOrder.nearestFirst,
                  child: Text('Nearest first'),
                ),
                PopupMenuItem<NearbySortOrder>(
                  value: NearbySortOrder.farthestFirst,
                  child: Text('Farthest first'),
                ),
                PopupMenuItem<NearbySortOrder>(
                  value: NearbySortOrder.nameAscending,
                  child: Text('Name A–Z'),
                ),
              ],
              child: Chip(
                avatar: const Icon(Icons.sort, size: 18),
                label: Text(_sortLabel(sortOrder)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, NearbyDistanceFilter value) {
    return ChoiceChip(
      label: Text(label),
      selected: distanceFilter == value,
      onSelected: (_) => onDistanceFilterChanged(value),
    );
  }

  String _sortLabel(NearbySortOrder value) {
    return switch (value) {
      NearbySortOrder.nearestFirst => 'Nearest first',
      NearbySortOrder.farthestFirst => 'Farthest first',
      NearbySortOrder.nameAscending => 'Name A–Z',
    };
  }
}

final class _NearbyContactTile extends StatelessWidget {
  const _NearbyContactTile({required this.row});

  final LocalNearbyContact row;

  @override
  Widget build(BuildContext context) {
    final SavedContactLocation? saved = row.savedLocation;
    return ListTile(
      leading: CircleAvatar(child: Text(_initials(row.contact.displayName))),
      title: Text(row.contact.displayName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            row.contact.phoneNumbers.isEmpty
                ? 'No phone number'
                : row.contact.phoneNumbers.first,
          ),
          const SizedBox(height: 2),
          Text(
            saved == null
                ? 'No authorized/saved location available'
                : '${saved.label} · ${_locationSourceLabel(saved)}',
          ),
        ],
      ),
      trailing: SizedBox(
        width: 126,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              _distanceLabel(row),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            _ProximityPill(category: row.category),
          ],
        ),
      ),
    );
  }

  String _distanceLabel(LocalNearbyContact row) {
    final double? meters = row.distance?.meters;
    if (meters == null) return 'Unknown';
    if (meters < 1000) return '${meters.round()} m';
    final double kilometers = meters / 1000;
    return kilometers < 10
        ? '${kilometers.toStringAsFixed(1)} km'
        : '${kilometers.round()} km';
  }

  String _locationSourceLabel(SavedContactLocation saved) {
    return switch (saved.source.name) {
      'home' => 'Home location',
      'work' => 'Work location',
      'manual' => 'Saved location',
      'geocoded' => 'Saved place',
      'liveShared' => 'Authorized live location',
      'recentShared' => 'Recent shared location',
      'lastKnown' => 'Last known location',
      'approximate' => 'Approximate location',
      _ => 'Saved location',
    };
  }

  String _initials(String name) {
    final List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

final class _ProximityPill extends StatelessWidget {
  const _ProximityPill({required this.category});

  final ProximityCategory category;

  @override
  Widget build(BuildContext context) {
    final Color color = _color(context);
    return Semantics(
      label: 'Proximity: ${_label()}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(_icon(), size: 13, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                _label(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _label() {
    return switch (category) {
      ProximityCategory.veryClose => 'Very close',
      ProximityCategory.veryNear => 'Very near',
      ProximityCategory.nearby => 'Nearby',
      ProximityCategory.moderate => 'Moderate',
      ProximityCategory.far => 'Far',
      ProximityCategory.unknown => 'Unavailable',
    };
  }

  IconData _icon() {
    return switch (category) {
      ProximityCategory.veryClose => Icons.notifications_active_outlined,
      ProximityCategory.veryNear => Icons.near_me_outlined,
      ProximityCategory.nearby => Icons.location_on_outlined,
      ProximityCategory.moderate => Icons.route_outlined,
      ProximityCategory.far => Icons.public_outlined,
      ProximityCategory.unknown => Icons.location_off_outlined,
    };
  }

  Color _color(BuildContext context) {
    return switch (category) {
      ProximityCategory.veryClose || ProximityCategory.veryNear =>
        Colors.green.shade700,
      ProximityCategory.nearby => Colors.amber.shade900,
      ProximityCategory.moderate => Colors.deepOrange.shade600,
      ProximityCategory.far => Colors.red.shade700,
      ProximityCategory.unknown => Theme.of(context).colorScheme.outline,
    };
  }
}

final class _PrivateLocationCard extends StatelessWidget {
  const _PrivateLocationCard({
    required this.locationAccess,
    required this.location,
    required this.onUseLocation,
  });

  final LocationAccess locationAccess;
  final LocationObservation? location;
  final VoidCallback onUseLocation;

  @override
  Widget build(BuildContext context) {
    final String status = location == null
        ? 'Current location is not available yet.'
        : locationAccess.precision == LocationPrecision.approximate
            ? 'Approximate current location is active on this device.'
            : 'Current location is active on this device.';
    final String accuracy = location?.accuracy == null
        ? ''
        : ' Accuracy ±${location!.accuracy!.meters.round()} m.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(Icons.shield_outlined),
                SizedBox(width: 8),
                Text(
                  'Private Local Mode',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('$status$accuracy'),
            const SizedBox(height: 4),
            const Text(
              'Your GPS is used locally for distance calculations and is not published by this phase.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onUseLocation,
              icon: const Icon(Icons.my_location),
              label: Text(
                location == null ? 'Use my location privately' : 'Refresh location',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ContactPermissionCard extends StatelessWidget {
  const _ContactPermissionCard({required this.access, required this.onEnable});

  final ContactAccess access;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final String detail = access.status == ContactAuthorizationStatus.denied
        ? 'Contact access is off. You can enable it when you are ready.'
        : 'Choose contact access so the app can show people you already know.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Contacts stay on this device',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(detail),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onEnable,
              icon: const Icon(Icons.contacts_outlined),
              label: const Text('Enable contact access'),
            ),
          ],
        ),
      ),
    );
  }
}

final class _EmptyNearbyResults extends StatelessWidget {
  const _EmptyNearbyResults({
    required this.access,
    required this.hasContacts,
    required this.hasLocation,
    required this.hasActiveFilter,
  });

  final ContactAccess access;
  final bool hasContacts;
  final bool hasLocation;
  final bool hasActiveFilter;

  @override
  Widget build(BuildContext context) {
    String text;
    if (!access.canReadContacts) {
      text = 'Enable contact access to begin.';
    } else if (!hasContacts) {
      text = 'No contacts are available to this app yet.';
    } else if (!hasLocation) {
      text = 'Use your location privately to calculate nearby distances.';
    } else if (hasActiveFilter) {
      text = 'No contacts match the current search or distance filter.';
    } else {
      text = 'Contacts without an authorized or saved location remain unavailable for distance calculation.';
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}
