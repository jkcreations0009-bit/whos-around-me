import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { summarizeSharingGrants } from "../common/sharingDashboard";

if (getApps().length === 0) initializeApp();
const db = getFirestore();

const strictCallableOptions = {
  enforceAppCheck: true,
  consumeAppCheckToken: true,
};

function requireVerifiedIdentity(request: {
  auth?: { uid: string; token: Record<string, unknown> } | null;
  app?: unknown;
}): string {
  const auth = request.auth;
  if (!auth) throw new HttpsError("unauthenticated", "Authentication is required.");
  if (!request.app) {
    throw new HttpsError("failed-precondition", "App Check is required.");
  }
  const firebaseClaim = auth.token.firebase as
    | { sign_in_provider?: string }
    | undefined;
  if (
    auth.token.identity_verified !== true
    || firebaseClaim?.sign_in_provider === "anonymous"
  ) {
    throw new HttpsError(
      "permission-denied",
      "A verified non-anonymous identity is required.",
    );
  }
  return auth.uid;
}

function visibility(value: unknown): string {
  return value === "VISIBLE_APPROVED"
      || value === "VISIBLE_SELECTED"
      || value === "HIDDEN"
      || value === "PRIVATE_LOCAL"
    ? value
    : "PRIVATE_LOCAL";
}

function activeSessionId(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : null;
}

function numberOrNull(value: unknown): number | null {
  return typeof value === "number" && Number.isSafeInteger(value)
    ? value
    : null;
}

function timestampMillis(value: unknown): number | null {
  if (value === null || value === undefined) return null;
  if (typeof value === "number" && Number.isSafeInteger(value)) return value;
  if (typeof value !== "object") return null;
  const maybe = value as { toMillis?: unknown };
  if (typeof maybe.toMillis !== "function") return null;
  const result = (maybe.toMillis as () => number)();
  return Number.isSafeInteger(result) ? result : null;
}

export const getSharingDashboard = onCall(
  strictCallableOptions,
  async (request) => {
    const ownerUserId = requireVerifiedIdentity(request);
    const ownerRef = db.doc(`users/${ownerUserId}`);
    const [ownerSnapshot, grantsSnapshot] = await Promise.all([
      ownerRef.get(),
      ownerRef.collection("sharingGrants").get(),
    ]);

    const owner = ownerSnapshot.data() as Record<string, unknown> | undefined;
    const nowMs = Date.now();
    const audience = summarizeSharingGrants(
      grantsSnapshot.docs.map((grant) => {
        const data = grant.data() as Record<string, unknown>;
        return {
          relationship: data.relationship,
          ownerApproved: data.ownerApproved,
          viewerApproved: data.viewerApproved,
          selectedByOwner: data.selectedByOwner,
          expiresAtMs: timestampMillis(data.expiresAt),
        };
      }),
      nowMs,
    );

    const sessionId = activeSessionId(owner?.activeShareSessionId);
    let sessionExpiresAtMs: number | null = null;
    if (sessionId !== null) {
      const sessionSnapshot = await ownerRef
        .collection("shareSessions")
        .doc(sessionId)
        .get();
      if (sessionSnapshot.data()?.active === true) {
        sessionExpiresAtMs = numberOrNull(sessionSnapshot.data()?.expiresAtMs);
      }
    }

    return {
      visibilityMode: visibility(owner?.visibility),
      liveSharingEnabled: owner?.liveSharingEnabled === true,
      ...audience,
      sessionExpiresAtMs,
    };
  },
);
