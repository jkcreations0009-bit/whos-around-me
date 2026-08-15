# Who's Around Me

Privacy-first proximity intelligence mobile application.

## Current verified baseline

The repository has progressed through the secure local proximity and consented live-sharing foundation.

- Phase 6B native mobile verification — PASS
- Phase 7 core local proximity — PASS
- Phase 8A authentication/privacy/consent policy — PASS
- Phase 8B Firebase integration/App Check readiness — PASS
- Phase 8C secure live-location protocol — PASS
- Phase 8D explicit live-sharing UX — PASS
- Phase 8E Firebase development deployment readiness — PASS for hosted readiness/emulator/native-build verification
- Phase 8E real Firebase deployment and physical two-device security validation — NOT EXECUTED

## Environment application identifiers

- Development: `com.dC0dez.Whosaroundme.dev`
- Test: `com.dC0dez.Whosaroundme.test`
- Staging: `com.dC0dez.Whosaroundme.staging`
- Production: `com.dC0dez.Whosaroundme`

Android and iOS environment builds are verified for all four identifiers. iOS simulator verification is recorded in GitHub Actions run `31811815218`.

## Next required gate

Configure a real Firebase development project and the protected GitHub `development` environment secrets, then manually run `Phase 8E Firebase Development Deploy`.

The guarded deployment workflow requires:

- `FIREBASE_PROJECT_ID_DEV`
- `FIREBASE_SERVICE_ACCOUNT_JSON_B64`
- manual confirmation: `DEPLOY_WHO_S_AROUND_ME_DEVELOPMENT`

After deployment, validate real Firebase Authentication, `identity_verified`, App Check attestation, and the physical two-device privacy flow:

`A shares → B sees A → A hides → B receives no location information.`

Maps, routes/travel time, background behavior, and 200 m proximity alerts remain gated until that real-environment security validation passes.

See `docs/phase8e/PHASE8E_REPORT.md` and `docs/phase8e/PHASE8E_GATE_MATRIX.csv` for the current evidence boundary.
