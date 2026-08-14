import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/firebase/firebase_bootstrap.dart';
import '../../domain/models/authenticated_identity.dart';
import '../../domain/models/live_share_session_ticket.dart';
import '../../domain/models/location_access.dart';
import '../../domain/models/location_observation.dart';
import '../../domain/models/sharing_dashboard.dart';
import '../../domain/models/visibility_mode.dart';
import '../../domain/policies/sharing_start_policy.dart';
import '../../domain/repositories/remote_sharing_service.dart';
import '../../domain/repositories/user_location_repository.dart';

final class SharingCenterScreen extends ConsumerStatefulWidget {
  const SharingCenterScreen({super.key});

  @override
  ConsumerState<SharingCenterScreen> createState() =>
      _SharingCenterScreenState();
}

final class _SharingCenterScreenState
    extends ConsumerState<SharingCenterScreen> {
  static const SharingStartPolicy _startPolicy = SharingStartPolicy();

  SharingDashboard? _dashboard;
  LiveShareSessionTicket? _localTicket;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    unawaited(Future<void>.microtask(_refreshDashboard));
  }

  AuthenticatedIdentity get _identity {
    return ref.read(authenticatedIdentityProvider).asData?.value ??
        const AuthenticatedIdentity.signedOut();
  }

  Future<void> _refreshDashboard() async {
    final RemoteSharingService? service = ref.read(remoteSharingServiceProvider);
    if (service == null || !_identity.isEligibleForRemoteSharing) return;
    try {
      final SharingDashboard dashboard = await service.getDashboard();
      if (!mounted) return;
      setState(() {
        _dashboard = dashboard;
        _message = null;
      });
    } catch (_) {
      _setMessage(
        'Secure sharing status is unavailable. No location was shared.',
      );
    }
  }

  Future<void> _setMode(VisibilityMode mode) async {
    final RemoteSharingService? service = ref.read(remoteSharingServiceProvider);
    if (service == null || !_identity.isEligibleForRemoteSharing) return;
    _setBusy(true);
    try {
      if (_dashboard?.liveSharingEnabled == true) {
        await service.stopLiveSharing();
        _localTicket = null;
      }
      await service.setPrivacyMode(mode);
      await _refreshDashboard();
    } catch (_) {
      _setMessage('Privacy mode could not be changed securely.');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _hideNow() async {
    final RemoteSharingService? service = ref.read(remoteSharingServiceProvider);
    if (service == null || !_identity.isEligibleForRemoteSharing) return;
    _setBusy(true);
    try {
      await service.setPrivacyMode(VisibilityMode.hidden);
      _localTicket = null;
      await _refreshDashboard();
      _setMessage('Hidden mode is active. Remote sharing is off.');
    } catch (_) {
      _setMessage('Could not confirm Hidden mode with the secure service.');
    } finally {
      _setBusy(false);
    }
  }

  Future<LocationObservation?> _obtainForegroundObservation() async {
    final UserLocationRepository location =
        ref.read(userLocationRepositoryProvider);
    LocationAccess access = await location.getAccess();
    if (!access.canUseForeground) {
      access = await location.requestWhenInUseAccess();
    }
    if (!access.canUseForeground) {
      _setMessage('Foreground location permission is required to share.');
      return null;
    }
    final LocationObservation observation =
        await location.refreshCurrentLocation();
    if (observation.accuracy == null) {
      _setMessage(
        'Location accuracy is unavailable, so nothing was shared.',
      );
      return null;
    }
    return observation;
  }

  Future<void> _startSharing() async {
    final RemoteSharingService? service = ref.read(remoteSharingServiceProvider);
    final SharingDashboard? dashboard = _dashboard;
    if (service == null || dashboard == null) return;
    if (!_startPolicy.canStart(identity: _identity, dashboard: dashboard)) return;

    _setBusy(true);
    try {
      final LocationObservation? observation =
          await _obtainForegroundObservation();
      if (observation == null) return;

      final LiveShareSessionTicket ticket = await service.startLiveSharing();
      try {
        await service.publishObservation(
          ticket: ticket,
          observation: observation,
        );
      } catch (_) {
        try {
          await service.stopLiveSharing();
        } catch (_) {
          // The server session expires and all reads remain authorization-gated.
        }
        rethrow;
      }

      if (!mounted) return;
      setState(() => _localTicket = ticket);
      await _refreshDashboard();
      _setMessage(
        'Your current foreground location was shared with the authorized audience.',
      );
    } catch (_) {
      _setMessage('Secure sharing failed. No new location was confirmed shared.');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _updateSharedLocation() async {
    final RemoteSharingService? service = ref.read(remoteSharingServiceProvider);
    final LiveShareSessionTicket? ticket = _localTicket;
    if (service == null || ticket == null) return;
    final int nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (ticket.isExpiredAt(nowMs)) {
      _localTicket = null;
      _setMessage('The sharing session expired. Start a new session explicitly.');
      return;
    }

    _setBusy(true);
    try {
      final LocationObservation? observation =
          await _obtainForegroundObservation();
      if (observation == null) return;
      await service.publishObservation(ticket: ticket, observation: observation);
      await _refreshDashboard();
      _setMessage('Shared location updated from the foreground.');
    } catch (_) {
      _setMessage('Location update was rejected or unavailable.');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _stopSharing() async {
    final RemoteSharingService? service = ref.read(remoteSharingServiceProvider);
    if (service == null || !_identity.isEligibleForRemoteSharing) return;
    _setBusy(true);
    try {
      await service.stopLiveSharing();
      _localTicket = null;
      await _refreshDashboard();
      _setMessage('Remote live sharing is stopped.');
    } catch (_) {
      _setMessage('Could not confirm stop with the secure service.');
    } finally {
      _setBusy(false);
    }
  }

  void _setBusy(bool value) {
    if (mounted) setState(() => _busy = value);
  }

  void _setMessage(String value) {
    if (!mounted) return;
    setState(() => _message = value);
  }

  @override
  Widget build(BuildContext context) {
    final FirebaseBootstrapState firebaseState =
        ref.watch(firebaseBootstrapStateProvider);
    final AsyncValue<AuthenticatedIdentity> identityAsync =
        ref.watch(authenticatedIdentityProvider);
    final AuthenticatedIdentity identity = identityAsync.asData?.value ??
        const AuthenticatedIdentity.signedOut();

    return Scaffold(
      appBar: AppBar(title: const Text('Sharing Center')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            _SecurityStatusCard(
              firebaseState: firebaseState,
              identity: identity,
              identityLoading: identityAsync.isLoading,
            ),
            const SizedBox(height: 12),
            if (firebaseState != FirebaseBootstrapState.initialized)
              const _UnavailableCard()
            else if (!identity.isEligibleForRemoteSharing)
              _IdentityRequiredCard(identity: identity)
            else ...<Widget>[
              _DashboardCard(
                dashboard: _dashboard,
                onRefresh: _busy ? null : _refreshDashboard,
              ),
              const SizedBox(height: 12),
              _PrivacyModeCard(
                dashboard: _dashboard,
                busy: _busy,
                onSetMode: _setMode,
                onHide: _hideNow,
              ),
              const SizedBox(height: 12),
              _ForegroundSharingCard(
                dashboard: _dashboard,
                identity: identity,
                localTicket: _localTicket,
                busy: _busy,
                canStart: _dashboard != null &&
                    _startPolicy.canStart(
                      identity: identity,
                      dashboard: _dashboard!,
                    ),
                onStart: _startSharing,
                onUpdate: _updateSharedLocation,
                onStop: _stopSharing,
              ),
            ],
            if (_message != null) ...<Widget>[
              const SizedBox(height: 12),
              MaterialBanner(
                content: Text(_message!),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => setState(() => _message = null),
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Privacy boundary: no address-book upload, no background location, '
              'and no automatic coordinate publishing in this phase.',
            ),
          ],
        ),
      ),
    );
  }
}

final class _SecurityStatusCard extends StatelessWidget {
  const _SecurityStatusCard({
    required this.firebaseState,
    required this.identity,
    required this.identityLoading,
  });

  final FirebaseBootstrapState firebaseState;
  final AuthenticatedIdentity identity;
  final bool identityLoading;

  @override
  Widget build(BuildContext context) {
    final String service = firebaseState == FirebaseBootstrapState.initialized
        ? 'Secure Firebase service configured'
        : 'Remote service disabled — local-only';
    final String identityLabel = identityLoading
        ? 'Checking identity…'
        : switch (identity.state) {
            AuthenticationState.signedOut => 'Signed out',
            AuthenticationState.authenticatedUnverified =>
              'Signed in — verification required',
            AuthenticationState.authenticatedVerified => 'Verified identity',
          };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Security status', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(service),
            Text(identityLabel),
          ],
        ),
      ),
    );
  }
}

final class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Secure remote sharing is unavailable because Firebase runtime '
          'configuration is not present. Nearby remains private and local.',
        ),
      ),
    );
  }
}

final class _IdentityRequiredCard extends StatelessWidget {
  const _IdentityRequiredCard({required this.identity});

  final AuthenticatedIdentity identity;

  @override
  Widget build(BuildContext context) {
    final String text = identity.state == AuthenticationState.signedOut
        ? 'Sign-in is required before remote sharing can be enabled. '
            'This phase does not invent or auto-create an account.'
        : 'Your authenticated identity must be verified before remote sharing. '
            'The server independently enforces the same requirement.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text),
      ),
    );
  }
}

final class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.dashboard, required this.onRefresh});

  final SharingDashboard? dashboard;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final SharingDashboard? value = dashboard;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Authorized audience',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh sharing status',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (value == null)
              const Text('Status not loaded.')
            else ...<Widget>[
              Text('Authorized: ${value.authorizedViewerCount}'),
              Text('Selected: ${value.selectedAuthorizedViewerCount}'),
              Text('Pending: ${value.pendingViewerCount}'),
              Text('Blocked: ${value.blockedViewerCount}'),
            ],
            const SizedBox(height: 8),
            const Text(
              'Only aggregate counts are shown here. This slice does not upload '
              'your phone contacts or expose raw contact identifiers.',
            ),
          ],
        ),
      ),
    );
  }
}

final class _PrivacyModeCard extends StatelessWidget {
  const _PrivacyModeCard({
    required this.dashboard,
    required this.busy,
    required this.onSetMode,
    required this.onHide,
  });

  final SharingDashboard? dashboard;
  final bool busy;
  final ValueChanged<VisibilityMode> onSetMode;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final VisibilityMode? selected = dashboard?.visibilityMode;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Privacy mode', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _modeChip('Private local', VisibilityMode.privateLocal, selected),
                _modeChip(
                  'Approved audience',
                  VisibilityMode.visibleApproved,
                  selected,
                ),
                _modeChip(
                  'Selected audience',
                  VisibilityMode.visibleSelected,
                  selected,
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy ? null : onHide,
              icon: const Icon(Icons.visibility_off_outlined),
              label: const Text('Hide now'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Changing audience mode stops any active session first. Hidden '
              'invalidates the session and removes retained live-location data.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeChip(
    String label,
    VisibilityMode mode,
    VisibilityMode? selected,
  ) {
    return ChoiceChip(
      label: Text(label),
      selected: selected == mode,
      onSelected: busy ? null : (_) => onSetMode(mode),
    );
  }
}

final class _ForegroundSharingCard extends StatelessWidget {
  const _ForegroundSharingCard({
    required this.dashboard,
    required this.identity,
    required this.localTicket,
    required this.busy,
    required this.canStart,
    required this.onStart,
    required this.onUpdate,
    required this.onStop,
  });

  final SharingDashboard? dashboard;
  final AuthenticatedIdentity identity;
  final LiveShareSessionTicket? localTicket;
  final bool busy;
  final bool canStart;
  final VoidCallback onStart;
  final VoidCallback onUpdate;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final bool serverActive = dashboard?.liveSharingEnabled == true;
    final bool canUpdate = serverActive && localTicket != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Foreground sharing',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(serverActive ? 'Session: active' : 'Session: stopped'),
            const SizedBox(height: 8),
            if (!serverActive)
              FilledButton.icon(
                onPressed: busy || !canStart ? null : onStart,
                icon: const Icon(Icons.my_location),
                label: const Text('Share my current location'),
              )
            else ...<Widget>[
              OutlinedButton.icon(
                onPressed: busy || !canUpdate ? null : onUpdate,
                icon: const Icon(Icons.refresh),
                label: const Text('Update shared location'),
              ),
              FilledButton.icon(
                onPressed: busy ? null : onStop,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Stop sharing'),
              ),
            ],
            const SizedBox(height: 8),
            if (!canStart && !serverActive)
              Text(_disabledReason(dashboard, identity)),
            const Text(
              'There is no background timer in this phase. A coordinate is sent '
              'only after an explicit Share or Update action.',
            ),
          ],
        ),
      ),
    );
  }

  String _disabledReason(
    SharingDashboard? dashboard,
    AuthenticatedIdentity identity,
  ) {
    if (!identity.isEligibleForRemoteSharing) return 'Verified identity required.';
    if (dashboard == null) return 'Refresh secure sharing status first.';
    return switch (dashboard.visibilityMode) {
      VisibilityMode.privateLocal => 'Choose an audience mode before sharing.',
      VisibilityMode.hidden => 'Hidden mode does not permit sharing.',
      VisibilityMode.visibleApproved when dashboard.authorizedViewerCount == 0 =>
        'No authorized audience is available yet.',
      VisibilityMode.visibleSelected
          when dashboard.selectedAuthorizedViewerCount == 0 =>
        'No selected authorized audience is available yet.',
      _ => 'Sharing is not currently eligible.',
    };
  }
}
