import assert from "node:assert/strict";
import { test } from "node:test";

import { identityVerificationDecision } from "../src/common/identityVerification";

test("anonymous identity can never establish verified sharing identity", () => {
  const decision = identityVerificationDecision({
    isAnonymous: true,
    emailVerified: true,
    hasVerifiedPhone: true,
  });
  assert.equal(decision.allowed, false);
  assert.equal(decision.method, null);
});

test("verified phone is accepted for a non-anonymous identity", () => {
  const decision = identityVerificationDecision({
    isAnonymous: false,
    emailVerified: false,
    hasVerifiedPhone: true,
  });
  assert.equal(decision.allowed, true);
  assert.equal(decision.method, "PHONE");
});

test("verified email is accepted for a non-anonymous identity", () => {
  const decision = identityVerificationDecision({
    isAnonymous: false,
    emailVerified: true,
    hasVerifiedPhone: false,
  });
  assert.equal(decision.allowed, true);
  assert.equal(decision.method, "EMAIL");
});

test("unverified email with no verified phone is rejected", () => {
  const decision = identityVerificationDecision({
    isAnonymous: false,
    emailVerified: false,
    hasVerifiedPhone: false,
  });
  assert.equal(decision.allowed, false);
  assert.equal(decision.method, null);
});
