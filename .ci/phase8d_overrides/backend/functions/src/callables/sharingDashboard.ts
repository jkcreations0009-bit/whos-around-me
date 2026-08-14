import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

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
    let authorizedViewerCount = 0;
    let selectedAuthorizedViewerCount = 0;
    let pendingViewerCount = 0;
    let blockedViewerCount = 0;

    for (const grant of grantsSnapshot.docs) {
      const data = grant.data() as Record<string, unknown>;
      const relationship = data.relationship;
      if (relationship === "AUTHORIZED") {
        authorizedViewerCount += 1;
        if (data.selectedByOwner === true) selectedAuthorizedViewerCount += 1;
      } else if (relationship === "PENDING") {
        pendingViewerCount += 1;
      } else if (relationship === "BLOCKED") {
        blockedViewerCount += 1;
      }
    }

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
      authorizedViewerCount,
      selectedAuthorizedViewerCount,
      pendingViewerCount,
      blockedViewerCount,
      sessionExpiresAtMs,
    };
  },
);
