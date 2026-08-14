import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearby_contacts/app/providers.dart';
import 'package:nearby_contacts/core/firebase/firebase_bootstrap.dart';
import 'package:nearby_contacts/domain/models/authenticated_identity.dart';
import 'package:nearby_contacts/domain/models/live_share_session_ticket.dart';
import 'package:nearby_contacts/domain/models/location_access.dart';
import 'package:nearby_contacts/domain/models/location_observation.dart';
import 'package:nearby_contacts/domain/models/location_source.dart';
import 'package:nearby_contacts/domain/models/sharing_dashboard.dart';
import 'package:nearby_contacts/domain/models/visibility_mode.dart';
import 'package:nearby_contacts/domain/repositories/authentication_repository.dart';
import 'package:nearby_contacts/domain/repositories/remote_sharing_service.dart';
import 'package:nearby_contacts/domain/repositories/user_location_repository.dart';
import 'package:nearby_contacts/domain/value_objects/geo_coordinate.dart';
import 'package:nearby_contacts/domain/value_objects/location_accuracy.dart';
import 'package:nearby_contacts/features/sharing/sharing_center_screen.dart';

void main() {
  testWidgets('missing Firebase config is visibly local-only and fail closed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SharingCenterScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sharing Center'), findsOneWidget);
    expect(find.text('Remote service disabled — local-only'), findsOneWidget);
    expect(
      find.textContaining('Secure remote sharing is unavailable'),
      findsOneWidget,
    );
    expect(find.text('Share my current location'), findsNothing);
  });

  testWidgets('explicit Share publishes once and no hidden timer republishes', (
    WidgetTester tester,
  ) async {
    final FakeRemoteSharingService sharing = FakeRemoteSharingService();
    final FakeAuthenticationRepository authentication =
        FakeAuthenticationRepository();
    final FakeUserLocationRepository location = FakeUserLocationRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseBootstrapStateProvider.overrideWithValue(
            FirebaseBootstrapState.initialized,
          ),
          authenticationRepositoryProvider.overrideWithValue(authentication),
          remoteSharingServiceProvider.overrideWithValue(sharing),
          userLocationRepositoryProvider.overrideWithValue(location),
        ],
        child: const MaterialApp(home: SharingCenterScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Refresh sharing status'));
    await tester.pumpAndSettle();
    expect(find.text('Selected: 1'), findsOneWidget);

    await tester.tap(find.text('Share my current location'));
    await tester.pumpAndSettle();
    expect(sharing.startCalls, 1);
    expect(sharing.publishCalls, 1);
    expect(location.refreshCalls, 1);
    expect(find.text('Session: active'), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    expect(
      sharing.publishCalls,
      1,
      reason: 'Phase 8D must not contain a hidden periodic publisher.',
    );

    await tester.tap(find.text('Update shared location'));
    await tester.pumpAndSettle();
    expect(sharing.publishCalls, 2);
    expect(location.refreshCalls, 2);

    await tester.tap(find.text('Stop sharing'));
    await tester.pumpAndSettle();
    expect(sharing.stopCalls, 1);
    expect(find.text('Session: stopped'), findsOneWidget);
  });
}

final class FakeAuthenticationRepository implements AuthenticationRepository {
  static const AuthenticatedIdentity identity = AuthenticatedIdentity(
    state: AuthenticationState.authenticatedVerified,
    userId: 'owner-user',
  );

  @override
  Future<AuthenticatedIdentity> refreshIdentity() async => identity;

  @override
  Future<void> signOut() async {}

  @override
  Stream<AuthenticatedIdentity> watchIdentity() =>
      Stream<AuthenticatedIdentity>.value(identity);
}

final class FakeRemoteSharingService implements RemoteSharingService {
  int startCalls = 0;
  int stopCalls = 0;
  int publishCalls = 0;

  VisibilityMode _mode = VisibilityMode.visibleSelected;
  bool _active = false;

  SharingDashboard get _dashboard => SharingDashboard(
        visibilityMode: _mode,
        liveSharingEnabled: _active,
        authorizedViewerCount: 2,
        selectedAuthorizedViewerCount: 1,
        pendingViewerCount: 0,
        blockedViewerCount: 0,
        sessionExpiresAtMs: _active ? 1_900_000_000_000 : null,
      );

  @override
  Future<SharingDashboard> getDashboard() async => _dashboard;

  @override
  Future<void> publishObservation({
    required LiveShareSessionTicket ticket,
    required LocationObservation observation,
  }) async {
    publishCalls += 1;
  }

  @override
  Future<void> setPrivacyMode(VisibilityMode mode) async {
    _mode = mode;
    _active = false;
  }

  @override
  Future<LiveShareSessionTicket> startLiveSharing() async {
    startCalls += 1;
    _active = true;
    return const LiveShareSessionTicket(
      sessionId: 'session-abcdefghijklmnopqrstuvwxyz',
      privacyEpoch: 8,
      expiresAtMs: 1_900_000_000_000,
    );
  }

  @override
  Future<void> stopLiveSharing() async {
    stopCalls += 1;
    _active = false;
  }
}

final class FakeUserLocationRepository implements UserLocationRepository {
  int refreshCalls = 0;

  static const LocationAccess access = LocationAccess(
    authorization: LocationAuthorizationStatus.whenInUse,
    precision: LocationPrecision.precise,
    servicesEnabled: true,
  );

  @override
  Future<LocationAccess> getAccess() async => access;

  @override
  Future<LocationAccess> requestWhenInUseAccess() async => access;

  @override
  Future<LocationObservation> refreshCurrentLocation() async {
    refreshCalls += 1;
    return LocationObservation(
      coordinate: GeoCoordinate(latitude: 17.4065, longitude: 78.4772),
      source: LocationSource.deviceCurrent,
      observedAtUtc: DateTime.now().toUtc(),
      accuracy: LocationAccuracy.meters(12),
    );
  }

  @override
  Future<void> stopUpdates() async {}

  @override
  Stream<LocationObservation> watchCurrentLocation() =>
      const Stream<LocationObservation>.empty();
}
