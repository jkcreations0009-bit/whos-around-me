import assert from "node:assert/strict";
import { test } from "node:test";

import { summarizeSharingGrants } from "../src/common/sharingDashboard";

test("dashboard counts only active relationship categories", () => {
  const summary = summarizeSharingGrants([
    { relationship: "AUTHORIZED", selectedByOwner: true },
    { relationship: "AUTHORIZED", selectedByOwner: false },
    { relationship: "PENDING", selectedByOwner: false },
    { relationship: "BLOCKED", selectedByOwner: false },
    { relationship: "REVOKED", selectedByOwner: true },
    { relationship: "NONE", selectedByOwner: false },
    { relationship: "UNKNOWN", selectedByOwner: true },
  ]);

  assert.equal(summary.authorizedViewerCount, 2);
  assert.equal(summary.selectedAuthorizedViewerCount, 1);
  assert.equal(summary.pendingViewerCount, 1);
  assert.equal(summary.blockedViewerCount, 1);
});

test("selected count never includes non-authorized relationships", () => {
  const summary = summarizeSharingGrants([
    { relationship: "PENDING", selectedByOwner: true },
    { relationship: "REVOKED", selectedByOwner: true },
    { relationship: "BLOCKED", selectedByOwner: true },
  ]);

  assert.equal(summary.authorizedViewerCount, 0);
  assert.equal(summary.selectedAuthorizedViewerCount, 0);
});
