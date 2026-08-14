import { getApps, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

if (getApps().length === 0) initializeApp();
const db = getFirestore();

const callableOptions = {
  enforceAppCheck: true,
  consumeAppCheckToken: true,
};

const visibilityModes = new Set([
  "PRIVATE_LOCAL",
  "VISIBLE_APPROVED",
  "VISIBLE_SELECTED",
  "HIDDEN",
]);

function asRecord(value: unknown): Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "Request body must be an object.");
  }
  return value as Record<string, unknown>;
}

function requireString(
  value: unknown,
  field: string,
  minLength = 1,
  maxLength = 128,
): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} must be a string.`);
  }
  const normalized = value.trim();
  if (normalized.length < minLength || normalized.length > maxLength) {
    throw new HttpsError("invalid-argument", `${field} has an invalid length.`);
  }
  return normalized;
}

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
    auth.token.identity_verified !== true ||
    firebaseClaim?.sign_in_provider === "anonymous"
  ) {
    throw new HttpsError(
      "permission-denied",
      "A verified non-anonymous identity is required.",
    );
  }
  return auth.uid;
}

function privacyEpoch(data: Record<string, unknown> | undefined): number {
  const raw = data?.privacyEpoch;
  return typeof raw === "number" && Number.isInteger(raw) && raw >= 0 ? raw : 0;
}

async function invalidateOwnerPrivacy(ownerUserId: string): Promise<void> {
  const ownerRef = db.doc(`users/${ownerUserId}`);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ownerRef);
    const data = snapshot.data() as Record<string, unknown> | undefined;
    transaction.set(
      ownerRef,
      {
        liveSharingEnabled: false,
        activeShareSessionId: null,
        privacyEpoch: privacyEpoch(data) + 1,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
}

export const setPrivacyMode = onCall(callableOptions, async (request) => {
  const uid = requireVerifiedIdentity(request);
  const data = asRecord(request.data);
  const mode = requireString(data.visibilityMode, "visibilityMode", 1, 32);
  if (!visibilityModes.has(mode)) {
    throw new HttpsError("invalid-argument", "Unsupported visibility mode.");
  }

  const ownerRef = db.doc(`users/${uid}`);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ownerRef);
    const current = snapshot.data() as Record<string, unknown> | undefined;
    const invalidatesSession = mode === "PRIVATE_LOCAL" || mode === "HIDDEN";
    transaction.set(
      ownerRef,
      {
        visibility: mode,
        liveSharingEnabled: false,
        activeShareSessionId: null,
        privacyEpoch: privacyEpoch(current) + (invalidatesSession ? 1 : 0),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
  return { ok: true };
});

export const requestLocationSharing = onCall(
  callableOptions,
  async (request) => {
    const ownerUserId = requireVerifiedIdentity(request);
    const data = asRecord(request.data);
    const viewerUserId = requireString(data.viewerUserId, "viewerUserId");
    if (viewerUserId === ownerUserId) {
      throw new HttpsError("invalid-argument", "Self-sharing is not allowed.");
    }
    const grantRef = db.doc(
      `users/${ownerUserId}/sharingGrants/${viewerUserId}`,
    );
    await db.runTransaction(async (transaction) => {
      const existing = await transaction.get(grantRef);
      if (existing.data()?.relationship === "BLOCKED") {
        throw new HttpsError("permission-denied", "Viewer is blocked.");
      }
      transaction.set(
        grantRef,
        {
          ownerUserId,
          viewerUserId,
          relationship: "PENDING",
          ownerApproved: true,
          viewerApproved: false,
          selectedByOwner: false,
          ownerApprovedAt: FieldValue.serverTimestamp(),
          viewerApprovedAt: null,
          expiresAt: null,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: false },
      );
    });
    return { ok: true };
  },
);

export const respondToLocationSharing = onCall(
  callableOptions,
  async (request) => {
    const viewerUserId = requireVerifiedIdentity(request);
    const data = asRecord(request.data);
    const ownerUserId = requireString(data.ownerUserId, "ownerUserId");
    const approved = data.approved;
    if (typeof approved !== "boolean") {
      throw new HttpsError("invalid-argument", "approved must be boolean.");
    }
    if (ownerUserId === viewerUserId) {
      throw new HttpsError("invalid-argument", "Self-sharing is not allowed.");
    }
    const grantRef = db.doc(
      `users/${ownerUserId}/sharingGrants/${viewerUserId}`,
    );
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(grantRef);
      if (!snapshot.exists) {
        throw new HttpsError("not-found", "Sharing request not found.");
      }
      if (snapshot.data()?.relationship === "BLOCKED") {
        throw new HttpsError("permission-denied", "Sharing is blocked.");
      }
      transaction.update(grantRef, {
        relationship: approved ? "AUTHORIZED" : "REVOKED",
        viewerApproved: approved,
        selectedByOwner: approved ? snapshot.data()?.selectedByOwner === true : false,
        viewerApprovedAt: approved ? FieldValue.serverTimestamp() : null,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    if (!approved) await invalidateOwnerPrivacy(ownerUserId);
    return { ok: true };
  },
);

export const revokeLocationSharing = onCall(
  callableOptions,
  async (request) => {
    const callerUid = requireVerifiedIdentity(request);
    const data = asRecord(request.data);
    const ownerUserId = requireString(data.ownerUserId, "ownerUserId");
    const viewerUserId = requireString(data.viewerUserId, "viewerUserId");
    if (callerUid !== ownerUserId && callerUid !== viewerUserId) {
      throw new HttpsError("permission-denied", "Not a party to this grant.");
    }
    const grantRef = db.doc(
      `users/${ownerUserId}/sharingGrants/${viewerUserId}`,
    );
    await grantRef.set(
      {
        ownerUserId,
        viewerUserId,
        relationship: "REVOKED",
        ownerApproved: false,
        viewerApproved: false,
        selectedByOwner: false,
        expiresAt: null,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    await invalidateOwnerPrivacy(ownerUserId);
    return { ok: true };
  },
);

export const setSelectedViewer = onCall(callableOptions, async (request) => {
  const ownerUserId = requireVerifiedIdentity(request);
  const data = asRecord(request.data);
  const viewerUserId = requireString(data.viewerUserId, "viewerUserId");
  const selected = data.selected;
  if (typeof selected !== "boolean") {
    throw new HttpsError("invalid-argument", "selected must be boolean.");
  }
  const grantRef = db.doc(
    `users/${ownerUserId}/sharingGrants/${viewerUserId}`,
  );
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(grantRef);
    if (!snapshot.exists || snapshot.data()?.relationship !== "AUTHORIZED") {
      throw new HttpsError(
        "failed-precondition",
        "Only an authorized viewer can be selected.",
      );
    }
    transaction.update(grantRef, {
      selectedByOwner: selected,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  if (!selected) await invalidateOwnerPrivacy(ownerUserId);
  return { ok: true };
});

export const blockUser = onCall(callableOptions, async (request) => {
  const ownerUserId = requireVerifiedIdentity(request);
  const data = asRecord(request.data);
  const viewerUserId = requireString(data.viewerUserId, "viewerUserId");
  if (ownerUserId === viewerUserId) {
    throw new HttpsError("invalid-argument", "Self-block is not allowed.");
  }
  const grantRef = db.doc(
    `users/${ownerUserId}/sharingGrants/${viewerUserId}`,
  );
  await grantRef.set(
    {
      ownerUserId,
      viewerUserId,
      relationship: "BLOCKED",
      ownerApproved: false,
      viewerApproved: false,
      selectedByOwner: false,
      expiresAt: null,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  await invalidateOwnerPrivacy(ownerUserId);
  return { ok: true };
});
