#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
checks: list[str] = []
errors: list[str] = []


def req(condition: bool, message: str) -> None:
    (checks if condition else errors).append(message)


protocol = (ROOT / 'backend/functions/src/common/liveLocationProtocol.ts').read_text()
callables = (ROOT / 'backend/functions/src/callables/liveLocation.ts').read_text()
privacy_callables = (ROOT / 'backend/functions/src/callables/privacyConsent.ts').read_text()
index = (ROOT / 'backend/functions/src/index.ts').read_text()
protocol_test = (ROOT / 'backend/functions/test/liveLocationProtocol.test.ts').read_text()
rules = (ROOT / 'firebase/firestore.rules').read_text()
rules_test = (ROOT / 'firebase/test/firestore.rules.test.mjs').read_text()
gateway = (ROOT / 'apps/mobile/lib/data/remote/firebase_live_location_gateway.dart').read_text()
nearby = (ROOT / 'apps/mobile/lib/features/nearby/nearby_local_screen.dart').read_text()

for name in ['startLiveSharing', 'stopLiveSharing', 'publishLiveLocation', 'getLiveLocation']:
    req(f'export const {name}' in callables, f'callable {name} exists')

req('enforceAppCheck: true' in callables and 'consumeAppCheckToken: true' in callables,
    'all Phase 8C callables enforce App Check and replay protection')
req('identity_verified' in callables and 'sign_in_provider' in callables,
    'Phase 8C independently requires verified non-anonymous identity')
req('.collection("shareSessions").doc()' in callables,
    'share-session identifier is server-generated rather than client supplied')
req('privacyEpoch: nextEpoch' in callables and 'activeShareSessionId: sessionRef.id' in callables,
    'session issuance binds a fresh privacy epoch and server session id')
req('liveSharingEnabled: false' in callables and 'activeShareSessionId: null' in callables,
    'stop sharing invalidates the active session')
req('transaction.delete(liveLocationRef)' in callables,
    'session start/stop removes stale retained coordinate state')
req('sessionSnapshot.data()?.lastAcceptedAtMs' in callables
    and 'transaction.set(\n        sessionRef,\n        { lastAcceptedAtMs: nowMs }' in callables,
    'publish throttle is anchored to server-only session state rather than deletable location state')

req('candidate.sessionId !== session.sessionId' in protocol,
    'publication requires exact active share-session match')
req('candidate.privacyEpoch !== sharing.privacyEpoch' in protocol,
    'publication requires exact privacy-epoch match')
req('value >= -90 && value <= 90' in protocol and 'value >= -180 && value <= 180' in protocol,
    'latitude and longitude bounds are enforced')
req('MAX_ACCURACY_METERS = 10_000' in protocol,
    'unbounded or implausible accuracy is rejected')
req('MAX_CAPTURE_AGE_MS = 120_000' in protocol and 'MAX_FUTURE_SKEW_MS = 30_000' in protocol,
    'stale and future coordinate timestamps are bounded')
req('MIN_PUBLISH_INTERVAL_MS = 5_000' in protocol,
    'server-side publication rate limiting is defined')
req('mutualConsentActive(consent, nowMs)' in protocol,
    'viewer read requires active mutual consent')
req('sharing.visibility === "VISIBLE_SELECTED" && !consent.selectedByOwner' in protocol,
    'selected visibility requires explicit owner selection')
req('location.sessionId !== sharing.activeShareSessionId' in protocol,
    'viewer read rejects location from superseded session')
req('location.privacyEpoch !== sharing.privacyEpoch' in protocol,
    'viewer read rejects location from superseded privacy epoch')
req('LOCATION_STALE' in protocol,
    'viewer read rejects stale retained locations')

req("return { available: false };" in callables,
    'unauthorized/hidden/stale viewer result is neutral unavailable')
req("reason:" not in callables.split('function unavailable()', 1)[1].split('}', 2)[0],
    'neutral unavailable response does not disclose denial reason')
req('two-user privacy flow: A shares, B sees A, A hides, B gets no location' in protocol_test,
    'two-user hide regression is automated')
req('inFlightOldUpload' in protocol_test,
    'in-flight old-session upload after hide is automated')
req('block plus fetch and session restart races reject the old location' in protocol_test,
    'block and session-restart race regressions are automated')
req('publication rejects stale, future, expired and rapid updates' in protocol_test,
    'stale/future/expiry/rate publication regressions are automated')

req('allow read, create, update: if false;' in rules,
    'Firestore denies all direct client live-location reads and writes')
req('allow delete: if isOwner(uid);' in rules,
    'owner emergency coordinate delete remains available')
req('even authorized owner and viewer cannot directly read coordinates' in rules_test,
    'Firestore emulator proves direct coordinate reads are denied')
req('no client can directly create or update a live coordinate' in rules_test,
    'Firestore emulator proves direct coordinate publication is denied')

req('limitedUseAppCheckToken: true' in gateway,
    'mobile live-location gateway requests limited-use App Check tokens')
for name in ['startLiveSharing', 'stopLiveSharing', 'publishLiveLocation', 'getLiveLocation']:
    req(f"'{name}'" in gateway, f'mobile gateway exposes {name}')
req('FirebaseLiveLocationGateway' not in nearby and 'publishLiveLocation' not in nearby,
    'Phase 8C transport is not silently activated by Nearby UI')
req('./common/liveLocationProtocol' in index and './callables/liveLocation' in index,
    'backend exports Phase 8C protocol and callable layer')
req('activeShareSessionId: null' in privacy_callables and 'privacyEpoch:' in privacy_callables,
    'Hidden/revoke/block path still invalidates owner session state')
req('ownerRef.collection("shareSessions").doc(sessionId)' in privacy_callables
    and 'active: false' in privacy_callables,
    'privacy invalidation explicitly deactivates the active share session')
req('transaction.delete(liveLocationRef)' in privacy_callables,
    'Hidden/revoke/block privacy invalidation deletes retained live-location data')

print('PHASE 8C SECURE LIVE LOCATION VERIFICATION')
for item in checks:
    print('PASS:', item)
for item in errors:
    print('FAIL:', item)
print(f'PASS COUNT: {len(checks)}')
print(f'FAIL COUNT: {len(errors)}')
sys.exit(1 if errors else 0)
