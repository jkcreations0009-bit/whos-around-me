# Phase 8E — Firebase Development Deployment Readiness

## Status

**READY FOR REAL DEVELOPMENT DEPLOYMENT — HOSTED READINESS / EMULATOR / NATIVE BUILD VERIFIED**

Phase 8E is intentionally split into readiness evidence and real-environment evidence. The repository is now prepared for a guarded Firebase development deployment, but no real Firebase development project has been deployed from this repository yet.

Verified readiness run: `31811388790`

Verified iOS environment run: `31811815218`

Phase 8E readiness merge: `dd3597deded18dc369b2f790d09d9a8ef6236d39`

iOS environment merge: `285d65b83086a5cef8b9b77fc18686216b912034`

## Deployment-readiness implementation

- `establishVerifiedIdentity` is server privileged and protected by Firebase Authentication, App Check, and replay protection.
- Identity verification evidence comes from Firebase Admin user state; a client cannot self-assert a verified flag.
- Existing custom claims are preserved when `identity_verified` is established.
- Client eligibility requires an ID-token refresh after claim issuance.
- The real deployment path is manual-only through `.github/workflows/phase8e-development-deploy.yml`.
- The deployment job is bound to the protected GitHub `development` environment.
- The manual deploy requires the exact confirmation string `DEPLOY_WHO_S_AROUND_ME_DEVELOPMENT`.
- Required protected secrets are `FIREBASE_PROJECT_ID_DEV` and `FIREBASE_SERVICE_ACCOUNT_JSON_B64`.
- The service-account credential is materialized only in runner temporary storage, is never printed, and is removed in an `always()` cleanup step.
- Preflight rejects a missing project, missing credential, malformed credential, demo project, or project/credential mismatch.
- Before real deployment, the workflow reconstructs the verified source, runs Phase 7 through Phase 8E verification, compiles/tests backend code, and executes Firestore Security Rules emulator tests.
- The real deployment scope is limited to Firestore Security Rules and Cloud Functions.

## iOS environment configuration

All four iOS environment schemes/configurations are now generated and build-verified:

- Development: `com.dC0dez.Whosaroundme.dev` — **PASS**
- Test: `com.dC0dez.Whosaroundme.test` — **PASS**
- Staging: `com.dC0dez.Whosaroundme.staging` — **PASS**
- Production: `com.dC0dez.Whosaroundme` — **PASS**

GitHub Actions run `31811815218` also verified:

- fresh Flutter/Xcode project generation;
- native bridge application;
- all four shared Xcode schemes exposed;
- Flutter analyze/tests;
- simulator build for every environment;
- exact built `CFBundleIdentifier` for every environment;
- foreground-only contacts/location privacy configuration;
- no Always/background location permission introduced.

## Automated readiness evidence

GitHub Actions run `31811388790` — **PASS**:

- Phase 7 through Phase 8E reconstruction/verifiers;
- manual/development-only deployment policy;
- TypeScript compile and identity/security regressions;
- Firestore Security Rules emulator;
- synthetic valid deployment credential preflight;
- synthetic credential/project mismatch rejected fail-closed.

GitHub Actions run `31811815218` — **PASS**:

- Xcode environment generation;
- Flutter regressions;
- development/test/staging/production simulator builds;
- exact bundle IDs;
- foreground-only iOS privacy verification.

## Real-environment gates — NOT EXECUTED

The following remain **NOT EXECUTED** and must not be inferred from readiness CI:

- actual Firebase development project deployment;
- real Firebase Auth-provider sign-in;
- real server issuance of `identity_verified`;
- real token refresh and client eligibility transition;
- real Play Integrity attestation;
- real App Attest / DeviceCheck attestation;
- real deployed Cloud Functions invocation;
- real deployed Firestore rules behavior;
- physical two-user/two-device A-share → B-read → A-hide → B-denied test;
- physical revoke/block/session-expiry/privacyEpoch race tests;
- real permission denial/revocation lifecycle;
- network interruption/recovery;
- real GPS accuracy, lifecycle, accessibility, and battery behavior.

## Required next action

Configure a real Firebase development project and the protected GitHub `development` environment secrets:

- `FIREBASE_PROJECT_ID_DEV`
- `FIREBASE_SERVICE_ACCOUNT_JSON_B64`

Then manually dispatch `Phase 8E Firebase Development Deploy` with confirmation `DEPLOY_WHO_S_AROUND_ME_DEVELOPMENT`.

After deployment, complete real Auth/App Check validation and the physical two-device privacy/security E2E before beginning maps, routes, background tracking, or proximity-alert phases.

## Release interpretation

Phase 8E is **deployment-ready but not yet real-environment PASS and not production ready**. Hosted CI/emulator/native build evidence is green; the remaining gates require a real Firebase development project and physical devices.
