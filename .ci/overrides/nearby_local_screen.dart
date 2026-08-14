import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/contact_access.dart';
import '../../domain/models/local_contact.dart';
import '../../domain/models/location_access.dart';
import '../../domain/models/location_observation.dart';
import '../../domain/repositories/contacts_repository.dart';
import '../../domain/repositories/user_location_repository.dart';

final class NearbyLocalScreen extends ConsumerStatefulWidget {
  const NearbyLocalScreen({super.key});

  @override
  ConsumerState<NearbyLocalScreen> createState() => _NearbyLocalScreenState();
}

final class _NearbyLocalScreenState extends ConsumerState<NearbyLocalScreen> {
  ContactAccess _contactAccess = const ContactAccess.notDetermined();
  LocationAccess _locationAccess = const LocationAccess.notDetermined();
  List<LocalContact> _contacts = const <LocalContact>[];
  LocationObservation? _location;
  String _query = '';
  bool _busy = true;
  String? _message;
  StreamSubscription<List<LocalContact>>? _contactsSubscription;

  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(_initialize));
  }

  @override
  void dispose() {
    final StreamSubscription<List<LocalContact>>? subscription =
        _contactsSubscription;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    final ContactsRepository contacts = ref.read(contactsRepositoryProvider);
    _contactsSubscription = contacts.watchContacts().listen((value) {
      if (mounted) setState(() => _contacts = value);
    });
    try {
      final ContactAccess contactAccess = await contacts.getAccess();
      final LocationAccess locationAccess =
          await ref.read(userLocationRepositoryProvider).getAccess();
      if (contactAccess.canReadContacts) await contacts.refreshContacts();
      if (!mounted) return;
      setState(() {
        _contactAccess = contactAccess;
        _locationAccess = locationAccess;
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

  List<LocalContact> get _visibleContacts {
    final String query = _query.trim().toLowerCase();
    if (query.isEmpty) return _contacts;
    return _contacts.where((LocalContact contact) {
      return contact.displayName.toLowerCase().contains(query) ||
          contact.phoneNumbers.any((String value) => value.contains(query));
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final List<LocalContact> contacts = _visibleContacts;
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
            Expanded(
              child: contacts.isEmpty
                  ? _EmptyContacts(access: _contactAccess)
                  : ListView.separated(
                      itemCount: contacts.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (BuildContext context, int index) {
                        final LocalContact contact = contacts[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(_initials(contact.displayName)),
                          ),
                          title: Text(contact.displayName),
                          subtitle: Text(
                            contact.phoneNumbers.isEmpty
                                ? 'No phone number'
                                : contact.phoneNumbers.first,
                          ),
                          trailing: const Text('Local only'),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
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
        ? 'Your location is not being used yet.'
        : locationAccess.precision == LocationPrecision.approximate
            ? 'Approximate location is being used only on this device.'
            : 'Your location is being used only on this device.';
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
            Text(status),
            const SizedBox(height: 4),
            const Text('Phase 6 does not publish your GPS location to the cloud.'),
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

final class _EmptyContacts extends StatelessWidget {
  const _EmptyContacts({required this.access});

  final ContactAccess access;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          access.canReadContacts
              ? 'No contacts are available to this app yet.'
              : 'Enable contact access to begin.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
