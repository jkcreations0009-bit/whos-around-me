import 'package:flutter_test/flutter_test.dart';
import 'package:nearby_contacts/domain/models/authenticated_identity.dart';
import 'package:nearby_contacts/domain/models/sharing_dashboard.dart';
import 'package:nearby_contacts/domain/models/visibility_mode.dart';
import 'package:nearby_contacts/domain/policies/sharing_start_policy.dart';

void main() {
  const SharingStartPolicy policy = SharingStartPolicy();
  const AuthenticatedIdentity verified = AuthenticatedIdentity(
    state: AuthenticationState.authenticatedVerified,
    userId: 'owner',
  );

  SharingDashboard dashboard({
    required VisibilityMode mode,
    int authorized = 0,
    int selected = 0,
    bool active = false,
  }) {
    return SharingDashboard(
      visibilityMode: mode,
      liveSharingEnabled: active,
      authorizedViewerCount: authorized,
      selectedAuthorizedViewerCount: selected,
      pendingViewerCount: 0,
      blockedViewerCount: 0,
    );
  }

  test('signed-out or unverified identity cannot start remote sharing', () {
    expect(
      policy.canStart(
        identity: const AuthenticatedIdentity.signedOut(),
        dashboard: dashboard(
          mode: VisibilityMode.visibleApproved,
          authorized: 1,
        ),
      ),
      isFalse,
    );
    expect(
      policy.canStart(
        identity: const AuthenticatedIdentity(
          state: AuthenticationState.authenticatedUnverified,
          userId: 'owner',
        ),
        dashboard: dashboard(
          mode: VisibilityMode.visibleApproved,
          authorized: 1,
        ),
      ),
      isFalse,
    );
  });

  test('approved mode requires at least one authorized viewer', () {
    expect(
      policy.canStart(
        identity: verified,
        dashboard: dashboard(mode: VisibilityMode.visibleApproved),
      ),
      isFalse,
    );
    expect(
      policy.canStart(
        identity: verified,
        dashboard: dashboard(
          mode: VisibilityMode.visibleApproved,
          authorized: 1,
        ),
      ),
      isTrue,
    );
  });

  test('selected mode requires at least one selected authorized viewer', () {
    expect(
      policy.canStart(
        identity: verified,
        dashboard: dashboard(
          mode: VisibilityMode.visibleSelected,
          authorized: 2,
        ),
      ),
      isFalse,
    );
    expect(
      policy.canStart(
        identity: verified,
        dashboard: dashboard(
          mode: VisibilityMode.visibleSelected,
          authorized: 2,
          selected: 1,
        ),
      ),
      isTrue,
    );
  });

  test('private, hidden, or already-active sharing cannot start again', () {
    for (final VisibilityMode mode in <VisibilityMode>[
      VisibilityMode.privateLocal,
      VisibilityMode.hidden,
    ]) {
      expect(
        policy.canStart(
          identity: verified,
          dashboard: dashboard(mode: mode, authorized: 2, selected: 1),
        ),
        isFalse,
      );
    }
    expect(
      policy.canStart(
        identity: verified,
        dashboard: dashboard(
          mode: VisibilityMode.visibleApproved,
          authorized: 1,
          active: true,
        ),
      ),
      isFalse,
    );
  });
}
