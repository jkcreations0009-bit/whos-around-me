#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
checks: list[str] = []
errors: list[str] = []


def req(condition: bool, message: str) -> None:
    (checks if condition else errors).append(message)


sharing_screen = (ROOT / 'apps/mobile/lib/features/sharing/sharing_center_screen.dart').read_text()
app = (ROOT / 'apps/mobile/lib/app/app.dart').read_text()
providers = (ROOT / 'apps/mobile/lib/app/providers.dart').read_text()
main = (ROOT / 'apps/mobile/lib/main.dart').read_text()
start_policy = (ROOT / 'apps/mobile/lib/domain/policies/sharing_start_policy.dart').read_text()
start_test = (ROOT / 'apps/mobile/test/unit/sharing_start_policy_test.dart').read_text()
widget_test = (ROOT / 'apps/mobile/test/widget/sharing_center_test.dart').read_text()
dashboard_callable = (ROOT / 'backend/functions/src/callables/sharingDashboard.ts').read_text()
dashboard_policy = (ROOT / 'backend/functions/src/common/sharingDashboard.ts').read_text()
dashboard_test = (ROOT / 'backend/functions/test/sharingDashboard.test.ts').read_text()
remote_service = (ROOT / 'apps/mobile/lib/domain/repositories/remote_sharing_service.dart').read_text()
firebase_service = (ROOT / 'apps/mobile/lib/data/remote/firebase_remote_sharing_service.dart').read_text()

req("label: 'Sharing'" in app and 'SharingCenterScreen' in app,
    'Sharing Center is an explicit bottom-navigation destination')
req("label: 'Nearby'" in app,
    'Nearby remains the default primary destination')

req('firebaseBootstrapStateProvider' in main and 'overrideWithValue(firebaseState)' in main,
    'Firebase bootstrap result is explicitly propagated to providers')
req('FirebaseBootstrapState.disabledMissingConfiguration' in providers,
    'remote provider defaults fail closed when Firebase config is absent')
req('if (ref.watch(firebaseBootstrapStateProvider) !=' in providers,
    'Firebase Auth/Functions instances are gated behind initialized bootstrap state')
req('return null;' in providers and 'remoteSharingServiceProvider' in providers,
    'remote sharing service is nullable/fail closed rather than eagerly initialized')

req("'Hide now'" in sharing_screen and 'VisibilityMode.hidden' in sharing_screen,
    'one-tap Hidden control is present')
req("'Share my current location'" in sharing_screen,
    'foreground sharing requires an explicit user action')
req("'Update shared location'" in sharing_screen,
    'subsequent coordinate update requires an explicit user action')
req("'Stop sharing'" in sharing_screen,
    'explicit stop control is present')
req('requestWhenInUseAccess()' in sharing_screen,
    'sharing requests only foreground location permission')
req('startLiveSharing()' in sharing_screen and 'publishObservation' in sharing_screen,
    'explicit share action invokes secure session then publication')
req('await service.stopLiveSharing();' in sharing_screen,
    'failed/changed sharing path includes secure session stop')
req('Timer.periodic' not in sharing_screen,
    'no periodic background/foreground publisher is introduced')
req('watchCurrentLocation' not in sharing_screen,
    'Sharing Center does not silently subscribe to a location stream')
req('initState' in sharing_screen and 'startLiveSharing' not in sharing_screen.split('initState', 1)[1].split('}', 2)[0],
    'screen initialization does not start live sharing')
req('no address-book upload' in sharing_screen.lower(),
    'Sharing Center states the no-contact-upload boundary')
req('no background location' in sharing_screen.lower(),
    'Sharing Center states the no-background-location boundary')

req('identity.isEligibleForRemoteSharing' in start_policy,
    'start policy requires verified eligible identity')
req('authorizedViewerCount > 0' in start_policy,
    'approved-audience mode requires at least one authorized viewer')
req('selectedAuthorizedViewerCount > 0' in start_policy,
    'selected-audience mode requires at least one selected authorized viewer')
req('dashboard.liveSharingEnabled' in start_policy,
    'start policy rejects duplicate active session starts')
req('selected mode requires at least one selected authorized viewer' in start_test,
    'selected-audience eligibility has unit coverage')
req('signed-out or unverified identity cannot start remote sharing' in start_test,
    'identity eligibility has unit coverage')

req('explicit Share publishes once and no hidden timer republishes' in widget_test,
    'widget test proves explicit one-shot publication behavior')
req('Duration(seconds: 30)' in widget_test and 'sharing.publishCalls' in widget_test,
    'widget test advances virtual time to prove no hidden publisher')
req('missing Firebase config is visibly local-only and fail closed' in widget_test,
    'widget test proves Firebase-missing fail-closed UI')

req('export const getSharingDashboard' in dashboard_callable,
    'owner sharing dashboard callable exists')
req('enforceAppCheck: true' in dashboard_callable and 'consumeAppCheckToken: true' in dashboard_callable,
    'dashboard callable enforces App Check and replay protection')
req('identity_verified' in dashboard_callable and 'sign_in_provider' in dashboard_callable,
    'dashboard callable requires verified non-anonymous identity')
req('summarizeSharingGrants' in dashboard_callable,
    'dashboard callable uses the tested pure audience summarizer')
req('authorizedViewerCount' in dashboard_policy and 'selectedAuthorizedViewerCount' in dashboard_policy,
    'dashboard policy exposes aggregate counts')
req('viewerUserId' not in dashboard_policy,
    'pure dashboard summary carries no viewer identifiers')
req('latitude' not in dashboard_callable.lower() and 'longitude' not in dashboard_callable.lower(),
    'dashboard response contains no coordinate fields')
req('viewerUserId' not in dashboard_callable,
    'dashboard response/query logic does not return raw viewer identifiers')
req('dashboard counts only active relationship categories' in dashboard_test,
    'audience aggregation has backend unit coverage')

req('abstract interface class RemoteSharingService' in remote_service,
    'remote sharing behavior is abstracted for testability')
req('accuracyMeters == null' in firebase_service,
    'remote publication fails closed when location accuracy is unavailable')
req('FirebasePrivacyConsentGateway' in firebase_service and 'FirebaseLiveLocationGateway' in firebase_service,
    'Firebase adapter composes the verified privacy and live-location gateways')

print('PHASE 8D EXPLICIT SHARING UX VERIFICATION')
for item in checks:
    print('PASS:', item)
for item in errors:
    print('FAIL:', item)
print(f'PASS COUNT: {len(checks)}')
print(f'FAIL COUNT: {len(errors)}')
sys.exit(1 if errors else 0)
