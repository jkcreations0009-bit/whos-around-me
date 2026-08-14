import assert from "node:assert/strict";
import { test } from "node:test";

import { summarizeSharingGrants } from "../src/common/sharingDashboard";

const nowMs = 1_800_000_000_000;

function grant(
  relationship: string,
  selectedByOwner: boolean,
  overrides: Partial<{
    ownerApproved: boolean;
    viewerApproved: boolean;
    expiresAtMs: number | null;
  }> = {},
) {
  return {
    relationship,
    ownerApproved: true,
    viewerApproved: true,
    selectedByOwner,
    expiresAtMs: null,
    ...overrides,
  };
}

test("dashboard counts only currently eligible authorized audience", () => {
  const summary = summarizeSharingGrants(
    [
      grant("AUTHORIZED", true),
      grant("AUTHORIZED", false),
      grant("PENDING", false),
      grant("BLOCKED", false),
      grant("REVOKED", true),
      grant("AUTHORIZED", true, { viewerApproved: false }),
      grant("AUTHORIZED", true, { ownerApproved: false }),
      grant("AUTHORIZED", true, { expiresAtMs: nowMs }),
      grant("AUTHORIZED", true, { expiresAtMs: nowMs - 1 }),
      grant("AUTHORIZED", true, { expiresAtMs: nowMs + 1 }),
    ],
    nowMs,
  );

  assert.equal(summary.authorizedViewerCount, 3);
  assert.equal(summary.selectedAuthorizedViewerCount, 2);
  assert.equal(summary.pendingViewerCount, 1);
  assert.equal(summary.blockedViewerCount, 1);
});

test("selected count never includes inactive or non-authorized relationships", () => {
  const summary = summarizeSharingGrants(
    [
      grant("PENDING", true),
      grant("REVOKED", true),
      grant("BLOCKED", true),
      grant("AUTHORIZED", true, { viewerApproved: false }),
      grant("AUTHORIZED", true, { expiresAtMs: nowMs }),
    ],
    nowMs,
  );

  assert.equal(summary.authorizedViewerCount, 0);
  assert.equal(summary.selectedAuthorizedViewerCount, 0);
});
