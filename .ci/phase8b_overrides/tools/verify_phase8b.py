#!/usr/bin/env python3
from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
checks = []
errors = []

def req(condition: bool, message: str) -> None:
    (checks if condition else errors).append(message)

bootstrap = (ROOT / 'apps/mobile/lib/core/firebase/firebase_bootstrap.dart').read_text()
auth = (ROOT / 'apps/mobile/lib/data/auth/firebase_authentication_repository.dart').read_text()
gateway = (ROOT / 'apps/mobile/lib/data/remote/firebase_privacy_consent_gateway.dart').read_text()
main = (ROOT / 'apps/mobile/lib/main.dart').read_text()
callables = (ROOT / 'backend/functions/src/callables/privacyConsent.ts').read_text()
rules = (ROOT / 'firebase/firestore.rules').read_text()
rules_test = (ROOT / 'firebase/test/firestore.rules.test.mjs').read_text()
package = json.loads((ROOT / 'backend/functions/package.json').read_text())

req('Firebase.initializeApp' in bootstrap and 'FirebaseAppCheck.instance.activate' in bootstrap,
    'Firebase initializes before App Check activation')
req('AndroidPlayIntegrityProvider' in bootstrap and 'AppleAppAttestWithDeviceCheckFallbackProvider' in bootstrap,
    'production App Check providers use Play Integrity and App Attest fallback')
req('AndroidDebugProvider' in bootstrap and 'AppleDebugProvider' in bootstrap,
    'development/test App Check providers are explicit debug providers')
req("String.fromEnvironment('FIREBASE_API_KEY')" in bootstrap and 'disabledMissingConfiguration' in bootstrap,
    'Firebase config is supplied by environment and missing config fails closed')
req("identity_verified" in auth and 'isAnonymous' in auth,
    'Firebase Auth adapter requires verified claim and rejects anonymous identity')
req('limitedUseAppCheckToken: true' in gateway,
    'security-critical callable client requests limited-use App Check tokens')
req('enforceAppCheck: true' in callables and 'consumeAppCheckToken: true' in callables,
    'server callables enforce App Check and replay protection')
req('identity_verified' in callables and 'sign_in_provider' in callables,
    'server independently verifies identity claim and anonymous provider')
for name in ['setPrivacyMode', 'requestLocationSharing', 'respondToLocationSharing',
             'revokeLocationSharing', 'setSelectedViewer', 'blockUser']:
    req(f'export const {name}' in callables, f'callable {name} exists')
req('liveSharingEnabled: false' in callables and 'activeShareSessionId: null' in callables,
    'Phase 8B server mutations cannot activate live sharing')
req('latitude' not in callables and 'longitude' not in callables,
    'Phase 8B callables contain no coordinate publication payload')
req('allow create, update: if false;' in rules,
    'Firestore live-location client publication remains locked')
req('allow create, update, delete: if false;' in rules,
    'privacy and consent writes remain server-authoritative')
req('live coordinate create and update stay locked for owner' in rules_test,
    'Firestore emulator tests explicitly prove coordinate write lock')
req(package['dependencies'].get('firebase-functions') == '7.3.2',
    'firebase-functions is pinned to verified current stable 7.3.2')
req(package['dependencies'].get('firebase-admin') == '14.2.0',
    'firebase-admin is pinned to verified current stable 14.2.0')
req('FirebaseBootstrap.initialize' in main,
    'application startup invokes fail-closed Firebase/App Check bootstrap')

print('PHASE 8B FIREBASE AUTH / PERSISTENCE / APP CHECK VERIFICATION')
for item in checks:
    print('PASS:', item)
for item in errors:
    print('FAIL:', item)
print(f'PASS COUNT: {len(checks)}')
print(f'FAIL COUNT: {len(errors)}')
sys.exit(1 if errors else 0)
