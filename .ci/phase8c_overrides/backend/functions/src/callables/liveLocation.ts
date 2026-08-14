import { getApps, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import type {
  ConsentRecord,
  RemoteSharingState,
} from "../common/authPrivacyConsent";
import {
  LocationCandidate,
  ShareSessionState,
  StoredLiveLocation,
  publicationDecision,
  viewerReadDecision,
} from "../common/liveLocationProtocol";

if (getApps().length === 0) initializeApp();
const db = getFirestore();

const strictCallableOptions = {
  enforceAppCheck: true,
  consumeAppCheckToken: true,
};

const SHARE_SESSION_TTL_MS = 30 * 60_000;

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

function requireFiniteNumber(value: unknown, field: string): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new HttpsError("invalid-argument", `${field} must be a finite number.`);
  }
  return value;
}

function requireSafeInteger(value: unknown, field: string): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value)) {
    throw new HttpsError("invalid-argument", `${field} must be a safe integer.`);
  }
  return value;
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

function optionalString(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : null;
}

function nonNegativeEpoch(value: unknown): number {
  return typeof value === "number"
      && Number.isSafeInteger(value)
      && value >= 0
    ? value
    : 0;
}

function timestampMillis(value: unknown): number | null {
  if (typeof value === "number" && Number.isSafeInteger(value)) return value;
  if (value === null || typeof value !== "object") return null;
  const maybe = value as { toMillis?: unknown };
  if (typeof maybe.toMillis !== "function") return null;
  const result = (maybe.toMillis as () => number)();
  return Number.isSafeInteger(result) ? result : null;
}

function sharingState(data: Record<string, unknown> | undefined): RemoteSharingState {
  const visibilityRaw = data?.visibility;
  const visibility = visibilityRaw === "VISIBLE_APPROVED"
      || visibilityRaw === "VISIBLE_SELECTED"
      || visibilityRaw === "HIDDEN"
      || visibilityRaw === "PRIVATE_LOCAL"
    ? visibilityRaw
    : "PRIVATE_LOCAL";
  return {
    visibility,
    liveSharingEnabled: data?.liveSharingEnabled === true,
    activeShareSessionId: optionalString(data?.activeShareSessionId),
    privacyEpoch: nonNegativeEpoch(data?.privacyEpoch),
  };
}

function sessionState(
  sessionId: string,
  data: Record<string, unknown> | undefined,
): ShareSessionState | null {
  if (!data) return null;
  const ownerUserId = optionalString(data.ownerUserId);
  const createdAtMs = timestampMillis(data.createdAtMs);
  const expiresAtMs = timestampMillis(data.expiresAtMs);
  const privacyEpoch = nonNegativeEpoch(data.privacyEpoch);
  if (ownerUserId === null || createdAtMs === null || expiresAtMs === null) {
    return null;
  }
  return {
    sessionId,
    ownerUserId,
    privacyEpoch,
    active: data.active === true,
    createdAtMs,
    expiresAtMs,
  };
}

function consentState(
  ownerUserId: string,
  viewerUserId: string,
  data: Record<string, unknown> | undefined,
): ConsentRecord | null {
  if (!data) return null;
  const relationship = data.relationship;
  if (
    relationship !== "NONE"
    && relationship !== "PENDING"
    && relationship !== "AUTHORIZED"
    && relationship !== "REVOKED"
    && relationship !== "BLOCKED"
  ) {
    return null;
  }
  return {
    ownerUserId,
    viewerUserId,
    relationship,
    ownerApproved: data.ownerApproved === true,
    viewerApproved: data.viewerApproved === true,
    selectedByOwner: data.selectedByOwner === true,
    ownerApprovedAtMs: timestampMillis(data.ownerApprovedAt),
    viewerApprovedAtMs: timestampMillis(data.viewerApprovedAt),
    expiresAtMs: timestampMillis(data.expiresAt),
  };
}

function storedLocation(
  ownerUserId: string,
  data: Record<string, unknown> | undefined,
): StoredLiveLocation | null {
  if (!data) return null;
  const sessionId = optionalString(data.sessionId);
  if (sessionId === null) return null;
  const privacyEpoch = nonNegativeEpoch(data.privacyEpoch);
  const latitude = data.latitude;
  const longitude = data.longitude;
  const accuracyMeters = data.accuracyMeters;
  const capturedAtMs = data.capturedAtMs;
  const acceptedAtMs = data.acceptedAtMs;
  if (
    typeof latitude !== "number"
    || typeof longitude !== "number"
    || typeof accuracyMeters !== "number"
    || typeof capturedAtMs !== "number"
    || typeof acceptedAtMs !== "number"
  ) {
    return null;
  }
  return {
    ownerUserId,
    sessionId,
    privacyEpoch,
    latitude,
    longitude,
    accuracyMeters,
    capturedAtMs,
    acceptedAtMs,
  };
}

function unavailable(): { available: false } {
  return { available: false };
}

function throwPublicationDenied(reason: string): never {
  if (reason === "RATE_LIMITED") {
    throw new HttpsError("resource-exhausted", "Location update rate exceeded.");
  }
  if (
    reason === "INVALID_COORDINATE"
    || reason === "INVALID_ACCURACY"
    || reason === "STALE_CAPTURE"
    || reason === "FUTURE_CAPTURE"
  ) {
    throw new HttpsError("invalid-argument", "Location payload rejected.");
  }
  throw new HttpsError("failed-precondition", "Live sharing session is not active.");
}

export const startLiveSharing = onCall(strictCallableOptions, async (request) => {
  const ownerUserId = requireVerifiedIdentity(request);
  const ownerRef = db.doc(`users/${ownerUserId}`);
  const sessionRef = ownerRef.collection("shareSessions").doc();
  const liveLocationRef = db.doc(`liveLocations/${ownerUserId}`);
  const nowMs = Date.now();
  const expiresAtMs = nowMs + SHARE_SESSION_TTL_MS;

  const issued = await db.runTransaction(async (transaction) => {
    const ownerSnapshot = await transaction.get(ownerRef);
    const current = ownerSnapshot.data() as Record<string, unknown> | undefined;
    const currentSharing = sharingState(current);
    if (
      currentSharing.visibility !== "VISIBLE_APPROVED"
      && currentSharing.visibility !== "VISIBLE_SELECTED"
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Choose an approved or selected sharing mode before starting live sharing.",
      );
    }

    const nextEpoch = currentSharing.privacyEpoch + 1;
    if (!Number.isSafeInteger(nextEpoch)) {
      throw new HttpsError("failed-precondition", "Privacy epoch exhausted.");
    }

    if (currentSharing.activeShareSessionId !== null) {
      const previousSessionRef = ownerRef
        .collection("shareSessions")
        .doc(currentSharing.activeShareSessionId);
      transaction.set(
        previousSessionRef,
        {
          active: false,
          endedAt: FieldValue.serverTimestamp(),
          endedAtMs: nowMs,
        },
        { merge: true },
      );
    }

    transaction.set(sessionRef, {
      ownerUserId,
      privacyEpoch: nextEpoch,
      active: true,
      createdAt: FieldValue.serverTimestamp(),
      createdAtMs: nowMs,
      expiresAtMs,
    });
    transaction.set(
      ownerRef,
      {
        liveSharingEnabled: true,
        activeShareSessionId: sessionRef.id,
        privacyEpoch: nextEpoch,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    transaction.delete(liveLocationRef);
    return { privacyEpoch: nextEpoch };
  });

  return {
    sessionId: sessionRef.id,
    privacyEpoch: issued.privacyEpoch,
    expiresAtMs,
  };
});

export const stopLiveSharing = onCall(strictCallableOptions, async (request) => {
  const ownerUserId = requireVerifiedIdentity(request);
  const ownerRef = db.doc(`users/${ownerUserId}`);
  const liveLocationRef = db.doc(`liveLocations/${ownerUserId}`);
  const nowMs = Date.now();

  await db.runTransaction(async (transaction) => {
    const ownerSnapshot = await transaction.get(ownerRef);
    const current = sharingState(
      ownerSnapshot.data() as Record<string, unknown> | undefined,
    );
    if (current.activeShareSessionId !== null) {
      transaction.set(
        ownerRef.collection("shareSessions").doc(current.activeShareSessionId),
        {
          active: false,
          endedAt: FieldValue.serverTimestamp(),
          endedAtMs: nowMs,
        },
        { merge: true },
      );
    }
    const nextEpoch = current.privacyEpoch + 1;
    if (!Number.isSafeInteger(nextEpoch)) {
      throw new HttpsError("failed-precondition", "Privacy epoch exhausted.");
    }
    transaction.set(
      ownerRef,
      {
        liveSharingEnabled: false,
        activeShareSessionId: null,
        privacyEpoch: nextEpoch,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    transaction.delete(liveLocationRef);
  });
  return { ok: true };
});

export const publishLiveLocation = onCall(
  strictCallableOptions,
  async (request) => {
    const ownerUserId = requireVerifiedIdentity(request);
    const data = asRecord(request.data);
    const candidate: LocationCandidate = {
      sessionId: requireString(data.sessionId, "sessionId", 16),
      privacyEpoch: requireSafeInteger(data.privacyEpoch, "privacyEpoch"),
      latitude: requireFiniteNumber(data.latitude, "latitude"),
      longitude: requireFiniteNumber(data.longitude, "longitude"),
      accuracyMeters: requireFiniteNumber(data.accuracyMeters, "accuracyMeters"),
      capturedAtMs: requireSafeInteger(data.capturedAtMs, "capturedAtMs"),
    };

    const ownerRef = db.doc(`users/${ownerUserId}`);
    const sessionRef = ownerRef.collection("shareSessions").doc(candidate.sessionId);
    const liveLocationRef = db.doc(`liveLocations/${ownerUserId}`);
    const nowMs = Date.now();

    await db.runTransaction(async (transaction) => {
      const ownerSnapshot = await transaction.get(ownerRef);
      const sessionSnapshot = await transaction.get(sessionRef);
      const locationSnapshot = await transaction.get(liveLocationRef);
      const currentSharing = sharingState(
        ownerSnapshot.data() as Record<string, unknown> | undefined,
      );
      const currentSession = sessionState(
        candidate.sessionId,
        sessionSnapshot.data() as Record<string, unknown> | undefined,
      );
      if (currentSession === null) {
        throw new HttpsError(
          "failed-precondition",
          "Live sharing session is not active.",
        );
      }
      const previousAcceptedAtMs = timestampMillis(locationSnapshot.data()?.acceptedAtMs);
      const decision = publicationDecision(
        ownerUserId,
        currentSharing,
        currentSession,
        candidate,
        previousAcceptedAtMs,
        nowMs,
      );
      if (!decision.allowed) throwPublicationDenied(decision.reason);

      transaction.set(liveLocationRef, {
        ownerUserId,
        sessionId: candidate.sessionId,
        privacyEpoch: candidate.privacyEpoch,
        latitude: candidate.latitude,
        longitude: candidate.longitude,
        accuracyMeters: candidate.accuracyMeters,
        capturedAtMs: candidate.capturedAtMs,
        acceptedAt: FieldValue.serverTimestamp(),
        acceptedAtMs: nowMs,
        expiresAtMs: currentSession.expiresAtMs,
      });
    });

    return { accepted: true, acceptedAtMs: nowMs };
  },
);

export const getLiveLocation = onCall(strictCallableOptions, async (request) => {
  const viewerUserId = requireVerifiedIdentity(request);
  const data = asRecord(request.data);
  const ownerUserId = requireString(data.ownerUserId, "ownerUserId");
  if (ownerUserId === viewerUserId) {
    throw new HttpsError("invalid-argument", "Use local location for the current user.");
  }

  const ownerRef = db.doc(`users/${ownerUserId}`);
  const grantRef = ownerRef.collection("sharingGrants").doc(viewerUserId);
  const liveLocationRef = db.doc(`liveLocations/${ownerUserId}`);
  const nowMs = Date.now();

  return db.runTransaction(async (transaction) => {
    const ownerSnapshot = await transaction.get(ownerRef);
    const currentSharing = sharingState(
      ownerSnapshot.data() as Record<string, unknown> | undefined,
    );
    if (currentSharing.activeShareSessionId === null) return unavailable();

    const sessionRef = ownerRef
      .collection("shareSessions")
      .doc(currentSharing.activeShareSessionId);
    const grantSnapshot = await transaction.get(grantRef);
    const sessionSnapshot = await transaction.get(sessionRef);
    const locationSnapshot = await transaction.get(liveLocationRef);

    const currentConsent = consentState(
      ownerUserId,
      viewerUserId,
      grantSnapshot.data() as Record<string, unknown> | undefined,
    );
    const currentSession = sessionState(
      currentSharing.activeShareSessionId,
      sessionSnapshot.data() as Record<string, unknown> | undefined,
    );
    const currentLocation = storedLocation(
      ownerUserId,
      locationSnapshot.data() as Record<string, unknown> | undefined,
    );
    if (
      currentConsent === null
      || currentSession === null
      || currentLocation === null
    ) {
      return unavailable();
    }

    const decision = viewerReadDecision(
      viewerUserId,
      ownerUserId,
      currentSharing,
      currentConsent,
      currentSession,
      currentLocation,
      nowMs,
    );
    if (!decision.allowed) return unavailable();

    return {
      available: true,
      latitude: currentLocation.latitude,
      longitude: currentLocation.longitude,
      accuracyMeters: currentLocation.accuracyMeters,
      capturedAtMs: currentLocation.capturedAtMs,
    };
  });
});
