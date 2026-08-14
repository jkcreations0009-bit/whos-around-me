import assert from "node:assert/strict";
import { test } from "node:test";

import {
  canOpenShareSession,
  transitionToHiddenLocked,
} from "../src/common/authPrivacyConsent";

const nowMs = Date.UTC(2026, 7, 14, 12, 0, 0);
const verifiedOwner = {
  state: "AUTHENTICATED_VERIFIED" as const,
  userId: "owner",
  isAnonymous: false,
};
const activeSharing = {
  visibility: "VISIBLE_SELECTED" as const,
  liveSharingEnabled: true,
  activeShareSessionId: "abcdefghijklmnop",
  privacyEpoch: 8,
};
const consent = {
  ownerUserId: "owner",
  viewerUserId: "viewer",
  relationship: "AUTHORIZED" as const,
  ownerApproved: true,
  viewerApproved: true,
  selectedByOwner: true,
  ownerApprovedAtMs: nowMs - 2_000,
  viewerApprovedAtMs: nowMs - 1_000,
  expiresAtMs: null,
};

test("verified owner plus mutual selected consent may open a session", () => {
  assert.equal(canOpenShareSession(verifiedOwner, activeSharing, consent, nowMs), true);
});

test("remote sharing is denied by default when liveSharingEnabled is false", () => {
  assert.equal(
    canOpenShareSession(
      verifiedOwner,
      { ...activeSharing, liveSharingEnabled: false },
      consent,
      nowMs,
    ),
    false,
  );
});

test("unverified and anonymous identities are denied", () => {
  assert.equal(
    canOpenShareSession(
      { ...verifiedOwner, state: "AUTHENTICATED_UNVERIFIED" },
      activeSharing,
      consent,
      nowMs,
    ),
    false,
  );
  assert.equal(
    canOpenShareSession(
      { ...verifiedOwner, isAnonymous: true },
      activeSharing,
      consent,
      nowMs,
    ),
    false,
  );
});

test("mutual consent and selected membership are both enforced", () => {
  assert.equal(
    canOpenShareSession(
      verifiedOwner,
      activeSharing,
      { ...consent, viewerApproved: false },
      nowMs,
    ),
    false,
  );
  assert.equal(
    canOpenShareSession(
      verifiedOwner,
      activeSharing,
      { ...consent, selectedByOwner: false },
      nowMs,
    ),
    false,
  );
});

test("hidden transition disables sharing, clears session, and increments epoch", () => {
  const hidden = transitionToHiddenLocked(activeSharing);
  assert.equal(hidden.visibility, "HIDDEN");
  assert.equal(hidden.liveSharingEnabled, false);
  assert.equal(hidden.activeShareSessionId, null);
  assert.equal(hidden.privacyEpoch, 9);
});
