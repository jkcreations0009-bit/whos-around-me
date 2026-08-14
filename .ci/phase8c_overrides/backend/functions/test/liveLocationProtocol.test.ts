import assert from "node:assert/strict";
import test from "node:test";

import type {
  ConsentRecord,
  RemoteSharingState,
} from "../src/common/authPrivacyConsent";
import {
  LocationCandidate,
  ShareSessionState,
  StoredLiveLocation,
  publicationDecision,
  viewerReadDecision,
} from "../src/common/liveLocationProtocol";

const nowMs = 1_800_000_000_000;

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
  assert.deepEqual(
    publicationDecision("owner", sharing(), session(), candidate(), null, nowMs),
    { allowed: true },
  );
});

test("publication rejects old session and old privacy epoch", () => {
  assert.equal(
    publicationDecision(
      "owner",
      sharing(),
      session(),
      candidate({ sessionId: "old-session-abcdefghijklmnop" }),
      null,
      nowMs,
    ).allowed,
    false,
  );
  assert.equal(
    publicationDecision(
      "owner",
      sharing(),
      session(),
      candidate({ privacyEpoch: 6 }),
      null,
      nowMs,
    ).allowed,
    false,
  );
});

test("publication rejects impossible coordinates and poor accuracy", () => {
  assert.deepEqual(
    publicationDecision(
      "owner",
      sharing(),
      session(),
      candidate({ latitude: 90.0001 }),
      null,
      nowMs,
    ),
    { allowed: false, reason: "INVALID_COORDINATE" },
  );
  assert.deepEqual(
    publicationDecision(
      "owner",
      sharing(),
      session(),
      candidate({ longitude: -180.0001 }),
      null,
      nowMs,
    ),
    { allowed: false, reason: "INVALID_COORDINATE" },
  );
  assert.deepEqual(
    publicationDecision(
      "owner",
      sharing(),
      session(),
      candidate({ accuracyMeters: 10_001 }),
      null,
      nowMs,
    ),
    { allowed: false, reason: "INVALID_ACCURACY" },
  );
});

test("publication rejects stale, future, expired and rapid updates", () => {
  assert.deepEqual(
    publicationDecision(
      "owner",
      sharing(),
      session(),
      candidate({ capturedAtMs: nowMs - 120_001 }),
      null,
      nowMs,
    ),
    { allowed: false, reason: "STALE_CAPTURE" },
  );
  assert.deepEqual(
    publicationDecision(
      "owner",
      sharing(),
      session(),
      candidate({ capturedAtMs: nowMs + 30_001 }),
      null,
      nowMs,
    ),
    { allowed: false, reason: "FUTURE_CAPTURE" },
  );
  assert.deepEqual(
    publicationDecision(
      "owner",
      sharing(),
      session({ expiresAtMs: nowMs }),
      candidate(),
      null,
      nowMs,
    ),
    { allowed: false, reason: "SESSION_EXPIRED" },
  );
  assert.deepEqual(
    publicationDecision(
      "owner",
      sharing(),
      session(),
      candidate(),
      nowMs - 4_999,
      nowMs,
    ),
    { allowed: false, reason: "RATE_LIMITED" },
  );
});

test("authorized selected viewer can read fresh session-matched location", () => {
  assert.deepEqual(
    viewerReadDecision(
      "viewer",
      "owner",
      sharing(),
      consent(),
      session(),
      location(),
      nowMs,
    ),
    { allowed: true },
  );
});

test("revoked or unselected viewer fails closed", () => {
  assert.deepEqual(
    viewerReadDecision(
      "viewer",
      "owner",
      sharing(),
      consent({ relationship: "REVOKED", viewerApproved: false }),
      session(),
      location(),
      nowMs,
    ),
    { allowed: false, reason: "CONSENT_INACTIVE" },
  );
  assert.deepEqual(
    viewerReadDecision(
      "viewer",
      "owner",
      sharing(),
      consent({ selectedByOwner: false }),
      session(),
      location(),
      nowMs,
    ),
    { allowed: false, reason: "VIEWER_NOT_SELECTED" },
  );
});

test("stale location is never returned even when consent remains valid", () => {
  assert.deepEqual(
    viewerReadDecision(
      "viewer",
      "owner",
      sharing(),
      consent(),
      session(),
      location({ acceptedAtMs: nowMs - 120_001 }),
      nowMs,
    ),
    { allowed: false, reason: "LOCATION_STALE" },
  );
});

test("two-user privacy flow: A shares, B sees A, A hides, B gets no location", () => {
  const activeSharing = sharing();
  const activeSession = session();
  const activeLocation = location();

  assert.deepEqual(
    viewerReadDecision(
      "viewer",
      "owner",
      activeSharing,
      consent(),
      activeSession,
      activeLocation,
      nowMs,
    ),
    { allowed: true },
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
  assert.deepEqual(afterHide, { allowed: false, reason: "SHARING_DISABLED" });

  const inFlightOldUpload = publicationDecision(
    "owner",
    hiddenSharing,
    activeSession,
    candidate(),
    activeLocation.acceptedAtMs,
    nowMs + 1,
  );
  assert.deepEqual(inFlightOldUpload, {
    allowed: false,
    reason: "SHARING_DISABLED",
  });
});

test("block plus fetch and session restart races reject the old location", () => {
  assert.equal(
    viewerReadDecision(
      "viewer",
      "owner",
      sharing(),
      consent({ relationship: "BLOCKED", ownerApproved: false, viewerApproved: false }),
      session(),
      location(),
      nowMs,
    ).allowed,
    false,
  );

  const restarted = sharing({
    activeShareSessionId: "session-new-abcdefghijklmnopqrstuvwxyz",
    privacyEpoch: 8,
  });
  assert.equal(
    viewerReadDecision(
      "viewer",
      "owner",
      restarted,
      consent(),
      session(),
      location(),
      nowMs,
    ).allowed,
    false,
  );
});
