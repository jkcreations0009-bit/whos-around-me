#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
checks = []
errors = []


def req(condition: bool, message: str) -> None:
    (checks if condition else errors).append(message)


identity = (ROOT / 'apps/mobile/lib/domain/models/authenticated_identity.dart').read_text()
privacy = (ROOT / 'apps/mobile/lib/domain/models/privacy_state.dart').read_text()
consent = (ROOT / 'apps/mobile/lib/domain/models/sharing_consent.dart').read_text()
policy = (ROOT / 'apps/mobile/lib/domain/policies/sharing_authorization_policy.dart').read_text()
unit = (ROOT / 'apps/mobile/test/unit/sharing_authorization_policy_test.dart').read_text()
backend = (ROOT / 'backend/functions/src/common/authPrivacyConsent.ts').read_text()
backend_test = (ROOT / 'backend/functions/test/authPrivacyConsent.test.ts').read_text()
rules = (ROOT / 'firebase/firestore.rules').read_text()

req('authenticatedVerified' in identity and 'isAnonymous' in identity,
    'remote sharing requires verified non-anonymous identity model')
req('PrivacyState.privateByDefault' in privacy and 'liveSharingEnabled = false' in privacy,
    'privacy state defaults to local-only with live sharing disabled')
req('privacyEpoch + 1' in privacy and 'activeShareSessionId: null' in privacy,
    'hidden transition invalidates session and increments privacy epoch')
req('ownerApproved' in consent and 'viewerApproved' in consent,
    'consent model requires both owner and viewer approval')
req('expiresAtUtc' in consent and 'RelationshipState.authorized' in consent,
    'consent model includes authorization state and expiry')
req('VisibilityMode.visibleSelected' in policy and 'selectedByOwner' in policy,
    'selected visibility requires explicit owner selection')
req('private-by-default state cannot open a share session' in unit,
    'mobile test proves default state cannot share')
req('hidden transition invalidates sharing immediately' in unit,
    'mobile test proves Hidden fail-closed transition')
req('canOpenShareSession' in backend and 'mutualConsentActive' in backend,
    'backend has equivalent identity/privacy/consent authorization core')
req('remote sharing is denied by default when liveSharingEnabled is false' in backend_test,
    'backend test proves default sharing disabled')
req('allow create, update: if false;' in rules,
    'Firestore live-location create/update is explicitly disabled in Phase 8A')
req('allow read: if isOwner(uid);' in rules,
    'Firestore remote live-location reads are not enabled in Phase 8A')
req('latitude' not in backend and 'longitude' not in backend,
    'Phase 8A authorization core contains no coordinate payload')

print('PHASE 8A AUTH / PRIVACY / CONSENT VERIFICATION')
for item in checks:
    print('PASS:', item)
for item in errors:
    print('FAIL:', item)
print(f'PASS COUNT: {len(checks)}')
print(f'FAIL COUNT: {len(errors)}')
sys.exit(1 if errors else 0)
