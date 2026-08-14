import assert from "node:assert/strict";
import { test } from "node:test";

import type {
  ConsentRecord,
  RemoteSharingState,
} from "../src/common/authPrivacyConsent";
import type {
  LocationCandidate,
  ProtocolDecision,
  ShareSessionState,
  StoredLiveLocation,
} from "../src/common/liveLocationProtocol";
import {
  publicationDecision,
  viewerReadDecision,
} from "../src/common/liveLocationProtocol";

const nowMs = 1_800_000_000_000;

function expectDecision(
  actual: ProtocolDecision,
  allowed: boolean,
  reason?: string,
): void {
  assert.equal(actual.allowed, allowed);
  if (!actual.allowed) assert.equal(actual.reason, reason);
}

function sharing(overrides: Partial<RemoteSharingState> = {}): RemoteSharingState {
  return {
    visibility: "VISIBLE_SELECTED",
    liveSharingEnabled: true,
    activeShareSessionId: "session-abcdefghijklmnopqrstuvwxyz",
    privacyEpoch: 7,
    ...overrides,
  };
}

function session(overrides: Partial<ShareSessionState> = {}): ShareSessionState {
  return {
    sessionId: "session-abcdefghijklmnopqrstuvwxyz",
    ownerUserId: "owner",
    privacyEpoch: 7,
    active: true,
    createdAtMs: nowMs - 1_000,
    expiresAtMs: nowMs + 30 * 60_000,
    ...overrides,
  };
}

function candidate(overrides: Partial<LocationCandidate> = {}): LocationCandidate {
  return {
    sessionId: "session-abcdefghijklmnopqrstuvwxyz",
    privacyEpoch: 7,
    latitude: 17.4065,
    longitude: 78.4772,
    accuracyMeters: 15,
    capturedAtMs: nowMs - 1_000,
    ...overrides,
  };
}

function consent(overrides: Partial<ConsentRecord> = {}): ConsentRecord {
  return {
    ownerUserId: "owner",
    viewerUserId: "viewer",
    relationship: "AUTHORIZED",
    ownerApproved: true,
    viewerApproved: true,
    selectedByOwner: true,
    ownerApprovedAtMs: nowMs - 60_000,
    viewerApprovedAtMs: nowMs - 30_000,
    expiresAtMs: null,
    ...overrides,
  };
}

function location(overrides: Partial<StoredLiveLocation> = {}): StoredLiveLocation {
  return {
    ownerUserId: "owner",
    ...candidate(),
    acceptedAtMs: nowMs - 500,
    ...overrides,
  };
}

test("valid current session can publish a fresh coordinate", () => {
  expectDecision(
    publicationDecision("owner", sharing(), session(), candidate(), null, nowMs),
    true,
  );
});

test("publication rejects old session and old privacy epoch", () => {
  expectDecision(
    publicationDecision(
      "owner",
      sharing(),
      session(),
      candidate({ sessionId: "old-session-abcdefghijklmnop" }),
      null,
      nowMs,
    ),
    false,
    "SESSION_MISMATCH",
  );
  expectDecision(
    publicationDecision(
      "owner",
      sharing(),
      session(),
      candidate({ privacyEpoch: 6 }),
      null,
      nowMs,
    ),
    false,
    "PRIVACY_EPOCH_MISMATCH",
  );
});

test("publication rejects impossible coordinates and poor accuracy", () => {
  expectDecision(
    publicationDecision(
      "owner",
      sharing(),
      session(),
      candidate({ latitude: 90.0001 }),
      null,
      nowMs,
    ),
    false,
    "INVALID_COORDINATE",
  );
  expectDecision(
    publicationDecision(
      "owner",
      sharing(),
      session(),
      candidate({ longitude: -180.0001 }),
      null,
      nowMs,
    ),
    false,
    "INVALID_COORDINATE",
  );
  expectDecision(
    publicationDecision(
      "owner",
      sharing(),
      session(),
      candidate({ accuracyMeters: 10_001 }),
      null,
      nowMs,
    ),
    false,
    "INVALID_ACCURACY",
  );
});

test("publication rejects stale, future, expired and rapid updates", () => {
  expectDecision(
    publicationDecision(
      "owner",
      sharing(),
      session(),
      candidate({ capturedAtMs: nowMs - 120_001 }),
      null,
      nowMs,
    ),
    false,
    "STALE_CAPTURE",
  );
  expectDecision(
    publicationDecision(
      "owner",
      sharing(),
      session(),
      candidate({ capturedAtMs: nowMs + 30_001 }),
      null,
      nowMs,
    ),
    false,
    "FUTURE_CAPTURE",
  );
  expectDecision(
    publicationDecision(
      "owner",
      sharing(),
      session({ expiresAtMs: nowMs }),
      candidate(),
      null,
      nowMs,
    ),
    false,
    "SESSION_EXPIRED",
  );
  expectDecision(
    publicationDecision(
      "owner",
      sharing(),
      session(),
      candidate(),
      nowMs - 4_999,
      nowMs,
    ),
    false,
    "RATE_LIMITED",
  );
});

test("authorized selected viewer can read fresh session-matched location", () => {
  expectDecision(
    viewerReadDecision(
      "viewer",
      "owner",
      sharing(),
      consent(),
      session(),
      location(),
      nowMs,
    ),
    true,
  );
});

test("revoked or unselected viewer fails closed", () => {
  expectDecision(
    viewerReadDecision(
      "viewer",
      "owner",
      sharing(),
      consent({ relationship: "REVOKED", viewerApproved: false }),
      session(),
      location(),
      nowMs,
    ),
    false,
    "CONSENT_INACTIVE",
  );
  expectDecision(
    viewerReadDecision(
      "viewer",
      "owner",
      sharing(),
      consent({ selectedByOwner: false }),
      session(),
      location(),
      nowMs,
    ),
    false,
    "VIEWER_NOT_SELECTED",
  );
});

test("stale location is never returned even when consent remains valid", () => {
  expectDecision(
    viewerReadDecision(
      "viewer",
      "owner",
      sharing(),
      consent(),
      session(),
      location({ acceptedAtMs: nowMs - 120_001 }),
      nowMs,
    ),
    false,
    "LOCATION_STALE",
  );
});

test("two-user privacy flow: A shares, B sees A, A hides, B gets no location", () => {
  const activeSharing = sharing();
  const activeSession = session();
  const activeLocation = location();

  expectDecision(
    viewerReadDecision(
      "viewer",
      "owner",
      activeSharing,
      consent(),
      activeSession,
      activeLocation,
      nowMs,
    ),
    true,
  );

  const hiddenSharing: RemoteSharingState = {
    visibility: "HIDDEN",
    liveSharingEnabled: false,
    activeShareSessionId: null,
    privacyEpoch: 8,
  };

  const afterHide = viewerReadDecision(
    "viewer",
    "owner",
    hiddenSharing,
    consent(),
    activeSession,
    activeLocation,
    nowMs + 1,
  );
  expectDecision(afterHide, false, "SHARING_DISABLED");

  const inFlightOldUpload = publicationDecision(
    "owner",
    hiddenSharing,
    activeSession,
    candidate(),
    activeLocation.acceptedAtMs,
    nowMs + 1,
  );
  expectDecision(inFlightOldUpload, false, "SHARING_DISABLED");
});

test("block plus fetch and session restart races reject the old location", () => {
  expectDecision(
    viewerReadDecision(
      "viewer",
      "owner",
      sharing(),
      consent({
        relationship: "BLOCKED",
        ownerApproved: false,
        viewerApproved: false,
      }),
      session(),
      location(),
      nowMs,
    ),
    false,
    "CONSENT_INACTIVE",
  );

  const restarted = sharing({
    activeShareSessionId: "session-new-abcdefghijklmnopqrstuvwxyz",
    privacyEpoch: 8,
  });
  expectDecision(
    viewerReadDecision(
      "viewer",
      "owner",
      restarted,
      consent(),
      session(),
      location(),
      nowMs,
    ),
    false,
    "SESSION_MISMATCH",
  );
});
