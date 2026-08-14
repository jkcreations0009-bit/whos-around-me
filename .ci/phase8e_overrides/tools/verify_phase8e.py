#!/usr/bin/env python3
from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
checks: list[str] = []
errors: list[str] = []


def req(condition: bool, message: str) -> None:
    (checks if condition else errors).append(message)


policy = (ROOT / 'backend/functions/src/common/identityVerification.ts').read_text()
callable = (ROOT / 'backend/functions/src/callables/identityVerification.ts').read_text()
test = (ROOT / 'backend/functions/test/identityVerification.test.ts').read_text()
index = (ROOT / 'backend/functions/src/index.ts').read_text()
preflight = (ROOT / 'tools/phase8e_deploy_preflight.py').read_text()
deploy_manifest_path = ROOT / 'firebase.deploy.json'
manifest = json.loads(deploy_manifest_path.read_text())
native_overlay = (ROOT / 'tools/apply_native_overlays.py').read_text()

req('isAnonymous' in policy and 'return { allowed: false, method: null }' in policy,
    'anonymous identities are never eligible for verified sharing identity')
req('hasVerifiedPhone' in policy and 'emailVerified' in policy,
    'identity verification accepts only server-observed verified phone/email evidence')
req('enforceAppCheck: true' in callable and 'consumeAppCheckToken: true' in callable,
    'identity-verification callable enforces App Check and replay protection')
req('getAuth()' in callable and 'getUser(auth.uid)' in callable,
    'identity evidence is read from Firebase Admin user state')
req('request.data' not in callable,
    'identity-verification callable accepts no client-supplied verification evidence')
req('setCustomUserClaims' in callable and '...(user.customClaims ?? {})' in callable,
    'identity_verified claim is set only by Admin SDK while preserving existing claims')
req('identity_verified: true' in callable and 'refreshRequired: true' in callable,
    'claim result requires an ID-token refresh before client UX eligibility changes')
req('anonymous identity can never establish verified sharing identity' in test,
    'anonymous identity rejection has automated coverage')
req('unverified email with no verified phone is rejected' in test,
    'insufficient verification evidence has automated coverage')
req('./common/identityVerification' in index and './callables/identityVerification' in index,
    'Phase 8E identity policy/callable are exported')

req(manifest.get('firestore', {}).get('rules') == 'firebase/firestore.rules',
    'deployment manifest targets the assembled Firestore rules')
functions = manifest.get('functions')
req(isinstance(functions, list) and len(functions) == 1
    and functions[0].get('source') == 'backend/functions',
    'deployment manifest targets the assembled backend Functions source')
req('apiKey' not in deploy_manifest_path.read_text()
    and 'private_key' not in deploy_manifest_path.read_text(),
    'deployment manifest contains no Firebase credential material')

req('DEPLOY_WHO_S_AROUND_ME_DEVELOPMENT' in preflight,
    'manual deploy requires an exact explicit development confirmation')
req('FIREBASE_PROJECT_ID_DEV' in preflight and 'demo-' in preflight,
    'deployment preflight requires a non-demo development project id')
req('GOOGLE_APPLICATION_CREDENTIALS' in preflight,
    'deployment preflight requires Application Default Credentials via a credential file')
req('credential_project != project_id' in preflight,
    'service-account project must match the requested development target')
req('private_key' in preflight and 'print("PASS: no credential values printed")' in preflight,
    'credential structure is validated without printing credential values')

req('"development": "com.dC0dez.Whosaroundme.dev"' in native_overlay,
    'Android/native environment contract retains the exact development application id')
req('multi-scheme flavor mapping remains a macOS/Xcode gate' in native_overlay,
    'known iOS development-scheme blocker remains explicit rather than silently normalized')

print('PHASE 8E DEVELOPMENT DEPLOYMENT READINESS VERIFICATION')
for item in checks:
    print('PASS:', item)
for item in errors:
    print('FAIL:', item)
print(f'PASS COUNT: {len(checks)}')
print(f'FAIL COUNT: {len(errors)}')
print('BLOCKED EXTERNAL: actual Firebase project credentials are not present in repository/CI source.')
print('BLOCKED NATIVE: distinct iOS development scheme/bundle mapping is not yet configured.')
sys.exit(1 if errors else 0)
