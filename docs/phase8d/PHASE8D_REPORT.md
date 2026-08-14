# Phase 8D — Explicit Live-Sharing UX

## Status

**PASS — HOSTED CI / EMULATOR / NATIVE BUILD VERIFIED**

Verified GitHub Actions run: `31810000204`

Verified branch head: `29d38850493a9719eb2e4006e798ecebae4aae7e`

Merged to `main`: `8356e2e852849e3c869942ecfe5fb09192e4f7cf`

Phase 8D adds an explicit privacy-first Sharing Center on top of the verified Phase 8C live-location protocol. It does not add background tracking, automatic coordinate publication, address-book upload, or direct client access to live-location documents.

## Implemented UX and policy

- `Nearby` remains the default app destination.
- `Sharing` is an explicit second bottom-navigation destination.
- Missing Firebase runtime configuration displays a local-only state and exposes no remote sharing control.
- Signed-out or unverified identities cannot start remote sharing.
- The Sharing Center exposes aggregate audience counts only; no viewer IDs or coordinates are returned by the dashboard callable.
- `VISIBLE_APPROVED` requires at least one currently eligible authorized viewer.
- `VISIBLE_SELECTED` requires at least one currently eligible selected authorized viewer.
- Eligible audience means `AUTHORIZED`, owner-approved, viewer-approved, and not expired.
- The client applies that eligibility rule before enabling Start.
- The server independently rechecks the same audience inside the `startLiveSharing` Firestore transaction so a stale or modified client cannot create a new session after eligibility disappears.
- One-tap `Hide now` is available.
- `Share my current location` obtains one foreground location observation only after explicit user action.
- `Update shared location` requires another explicit user action.
- `Stop sharing` explicitly stops the active session.
- No `Timer.periodic` publisher exists.
- No `watchCurrentLocation` subscription is used by the Sharing Center.
- No Android background-location permission is requested.
- If the initial coordinate publication fails after a session is issued, the client attempts to stop the newly issued session.

## Backend dashboard security

`getSharingDashboard`:

- requires Firebase Authentication;
- requires verified non-anonymous identity;
- requires App Check;
- consumes limited-use App Check tokens for replay protection;
- derives the owner from authenticated identity rather than request input;
- returns privacy mode, live-sharing state, aggregate audience counts, and session expiry only;
- returns no latitude/longitude and no viewer identifiers.

## Phase 8C boundary retained

Phase 8D does not weaken the Phase 8C protocol:

- share sessions remain server generated;
- every session remains bound to `privacyEpoch`;
- publish/read callables remain App-Check protected;
- coordinate freshness/bounds/rate validation remains server-side;
- viewer access remains current-state authorized;
- Hidden/revoke/block invalidate session state and delete retained location data;
- direct Firestore coordinate read/create/update remains denied to clients.

## Automated verification executed

GitHub Actions run `31810000204` completed successfully on all three jobs:

- Phase 8D Policy + Backend + Firestore Emulator — **PASS**.
- TypeScript compile and backend regressions — **PASS**.
- active mutual-consent/expiry audience tests — **PASS**.
- server transaction-level eligible-audience admission gate — **PASS**.
- Firestore Security Rules emulator — **PASS**.
- explicit UX / Phase 8C boundary proof — **PASS**.
- Phase 8D Flutter + Android — **PASS**.
- Flutter analyze/unit/widget tests — **PASS**.
- missing-Firebase local-only widget regression — **PASS**.
- explicit Share one-shot/no-hidden-timer regression — **PASS**.
- original Nearby and 360×640 responsive regressions — **PASS**.
- all four Android environment APK builds — **PASS**.
- exact Android application IDs and no-background-location checks — **PASS**.
- Phase 8D Flutter + macOS/Xcode — **PASS**.
- Swift native bridge parse — **PASS**.
- iOS production simulator build and privacy/bundle-ID checks — **PASS**.

## Evidence boundary — NOT EXECUTED

The following are still **NOT EXECUTED** and must not be inferred from the CI result:

- deployment to an actual Firebase development project;
- real Firebase Authentication-provider sign-in;
- real server issuance of the `identity_verified` claim;
- real Play Integrity attestation;
- real App Attest/DeviceCheck attestation;
- actual deployed Cloud Functions invocation;
- real Firestore production/development rules deployment;
- physical two-user/two-device A-share → B-read → A-hide → B-denied test;
- real permission denial/revocation lifecycle on Android and iOS;
- network loss/recovery during an active share session;
- real GPS accuracy and battery behavior;
- real-device accessibility/user-acceptance testing.

## Release interpretation

Phase 8D is closed for hosted CI/emulator/native-build verification and has been merged. It is **not production ready**. The next required phase is a configured Firebase development environment plus real-device security validation before maps, routes, background behavior, or proximity alerts are added.
