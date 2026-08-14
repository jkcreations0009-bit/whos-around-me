import 'package:flutter_test/flutter_test.dart';
import 'package:nearby_contacts/domain/models/authenticated_identity.dart';
import 'package:nearby_contacts/domain/models/privacy_state.dart';
import 'package:nearby_contacts/domain/models/relationship_state.dart';
import 'package:nearby_contacts/domain/models/sharing_consent.dart';
import 'package:nearby_contacts/domain/models/visibility_mode.dart';
import 'package:nearby_contacts/domain/policies/sharing_authorization_policy.dart';

void main() {
  const SharingAuthorizationPolicy policy = SharingAuthorizationPolicy();
  final DateTime now = DateTime.utc(2026, 8, 14, 12);

  AuthenticatedIdentity verified(String uid) => AuthenticatedIdentity(
        state: AuthenticationState.authenticatedVerified,
        userId: uid,
      );

  SharingConsent consent({
    RelationshipState relationship = RelationshipState.authorized,
    bool ownerApproved = true,
    bool viewerApproved = true,
    bool selected = true,
    DateTime? expiresAt,
  }) => SharingConsent(
        ownerUserId: 'owner',
        viewerUserId: 'viewer',
        relationship: relationship,
        ownerApproved: ownerApproved,
        viewerApproved: viewerApproved,
        selectedByOwner: selected,
        ownerApprovedAtUtc: now.subtract(const Duration(minutes: 2)),
        viewerApprovedAtUtc: now.subtract(const Duration(minutes: 1)),
        expiresAtUtc: expiresAt,
      );

  PrivacyState visible({
    VisibilityMode mode = VisibilityMode.visibleSelected,
    bool enabled = true,
    String? session = 'abcdefghijklmnop',
  }) => PrivacyState(
        visibilityMode: mode,
        privacyEpoch: 4,
        liveSharingEnabled: enabled,
        activeShareSessionId: session,
      );

  test('private-by-default state cannot open a share session', () {
    expect(
      policy.canOpenShareSession(
        ownerIdentity: verified('owner'),
        privacyState: const PrivacyState.privateByDefault(),
        consent: consent(),
        nowUtc: now,
      ),
      SharingAuthorizationDecision.deny,
    );
  });

  test('unverified or anonymous identities cannot remotely share', () {
    const AuthenticatedIdentity unverified = AuthenticatedIdentity(
      state: AuthenticationState.authenticatedUnverified,
      userId: 'owner',
    );
    const AuthenticatedIdentity anonymous = AuthenticatedIdentity(
      state: AuthenticationState.authenticatedVerified,
      userId: 'owner',
      isAnonymous: true,
    );
    for (final AuthenticatedIdentity identity in <AuthenticatedIdentity>[
      unverified,
      anonymous,
    ]) {
      expect(
        policy.canOpenShareSession(
          ownerIdentity: identity,
          privacyState: visible(),
          consent: consent(),
          nowUtc: now,
        ),
        SharingAuthorizationDecision.deny,
      );
    }
  });

  test('mutual explicit consent is required', () {
    expect(
      policy.canOpenShareSession(
        ownerIdentity: verified('owner'),
        privacyState: visible(),
        consent: consent(viewerApproved: false),
        nowUtc: now,
      ),
      SharingAuthorizationDecision.deny,
    );
  });

  test('selected visibility requires owner selection', () {
    expect(
      policy.canViewerReceiveRemoteLocation(
        viewerIdentity: verified('viewer'),
        ownerPrivacyState: visible(),
        consent: consent(selected: false),
        nowUtc: now,
      ),
      SharingAuthorizationDecision.deny,
    );
  });

  test('approved visibility allows mutually authorized viewer without selection', () {
    expect(
      policy.canViewerReceiveRemoteLocation(
        viewerIdentity: verified('viewer'),
        ownerPrivacyState: visible(mode: VisibilityMode.visibleApproved),
        consent: consent(selected: false),
        nowUtc: now,
      ),
      SharingAuthorizationDecision.allow,
    );
  });

  test('expired, revoked and blocked consent fail closed', () {
    final List<SharingConsent> denied = <SharingConsent>[
      consent(expiresAt: now),
      consent(relationship: RelationshipState.revoked),
      consent(relationship: RelationshipState.blocked),
    ];
    for (final SharingConsent item in denied) {
      expect(
        policy.canViewerReceiveRemoteLocation(
          viewerIdentity: verified('viewer'),
          ownerPrivacyState: visible(),
          consent: item,
          nowUtc: now,
        ),
        SharingAuthorizationDecision.deny,
      );
    }
  });

  test('hidden transition invalidates sharing immediately', () {
    final PrivacyState hidden = visible().toHidden();
    expect(hidden.visibilityMode, VisibilityMode.hidden);
    expect(hidden.liveSharingEnabled, false);
    expect(hidden.activeShareSessionId, isNull);
    expect(hidden.privacyEpoch, 5);
    expect(
      policy.canViewerReceiveRemoteLocation(
        viewerIdentity: verified('viewer'),
        ownerPrivacyState: hidden,
        consent: consent(),
        nowUtc: now,
      ),
      SharingAuthorizationDecision.deny,
    );
  });
}
