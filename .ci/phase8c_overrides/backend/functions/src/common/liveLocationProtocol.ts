import {
  ConsentRecord,
  RemoteSharingState,
  mutualConsentActive,
} from "./authPrivacyConsent";

export const MAX_CAPTURE_AGE_MS = 120_000;
export const MAX_FUTURE_SKEW_MS = 30_000;
export const MIN_PUBLISH_INTERVAL_MS = 5_000;
export const MAX_ACCURACY_METERS = 10_000;

export interface ShareSessionState {
  readonly sessionId: string;
  readonly ownerUserId: string;
  readonly privacyEpoch: number;
  readonly active: boolean;
  readonly createdAtMs: number;
  readonly expiresAtMs: number;
}

export interface LocationCandidate {
  readonly sessionId: string;
  readonly privacyEpoch: number;
  readonly latitude: number;
  readonly longitude: number;
  readonly accuracyMeters: number;
  readonly capturedAtMs: number;
}

export interface StoredLiveLocation extends LocationCandidate {
  readonly ownerUserId: string;
  readonly acceptedAtMs: number;
}

export type ProtocolDenyReason =
  | "SHARING_DISABLED"
  | "VISIBILITY_BLOCKED"
  | "SESSION_MISMATCH"
  | "PRIVACY_EPOCH_MISMATCH"
  | "SESSION_INACTIVE"
  | "SESSION_EXPIRED"
  | "INVALID_COORDINATE"
  | "INVALID_ACCURACY"
  | "STALE_CAPTURE"
  | "FUTURE_CAPTURE"
  | "RATE_LIMITED"
  | "CONSENT_INACTIVE"
  | "VIEWER_NOT_SELECTED"
  | "LOCATION_MISMATCH"
  | "LOCATION_STALE";

export type ProtocolDecision =
  | { readonly allowed: true }
  | { readonly allowed: false; readonly reason: ProtocolDenyReason };

function validLatitude(value: number): boolean {
  return Number.isFinite(value) && value >= -90 && value <= 90;
}

function validLongitude(value: number): boolean {
  return Number.isFinite(value) && value >= -180 && value <= 180;
}

function validAccuracy(value: number): boolean {
  return Number.isFinite(value) && value >= 0 && value <= MAX_ACCURACY_METERS;
}

function validEpoch(value: number): boolean {
  return Number.isSafeInteger(value) && value >= 0;
}

function activeVisibility(sharing: RemoteSharingState): boolean {
  return sharing.visibility === "VISIBLE_APPROVED"
    || sharing.visibility === "VISIBLE_SELECTED";
}

function sessionMatches(
  sharing: RemoteSharingState,
  session: ShareSessionState,
  ownerUserId: string,
): ProtocolDecision {
  if (!sharing.liveSharingEnabled) {
    return { allowed: false, reason: "SHARING_DISABLED" };
  }
  if (!activeVisibility(sharing)) {
    return { allowed: false, reason: "VISIBILITY_BLOCKED" };
  }
  if (
    sharing.activeShareSessionId === null
    || sharing.activeShareSessionId !== session.sessionId
    || session.ownerUserId !== ownerUserId
  ) {
    return { allowed: false, reason: "SESSION_MISMATCH" };
  }
  if (!validEpoch(sharing.privacyEpoch)
      || sharing.privacyEpoch !== session.privacyEpoch) {
    return { allowed: false, reason: "PRIVACY_EPOCH_MISMATCH" };
  }
  if (!session.active) {
    return { allowed: false, reason: "SESSION_INACTIVE" };
  }
  return { allowed: true };
}

export function publicationDecision(
  ownerUserId: string,
  sharing: RemoteSharingState,
  session: ShareSessionState,
  candidate: LocationCandidate,
  lastAcceptedAtMs: number | null,
  nowMs: number,
): ProtocolDecision {
  const sessionDecision = sessionMatches(sharing, session, ownerUserId);
  if (!sessionDecision.allowed) return sessionDecision;
  if (session.expiresAtMs <= nowMs) {
    return { allowed: false, reason: "SESSION_EXPIRED" };
  }
  if (
    candidate.sessionId !== session.sessionId
    || candidate.sessionId !== sharing.activeShareSessionId
  ) {
    return { allowed: false, reason: "SESSION_MISMATCH" };
  }
  if (!validEpoch(candidate.privacyEpoch)
      || candidate.privacyEpoch !== sharing.privacyEpoch) {
    return { allowed: false, reason: "PRIVACY_EPOCH_MISMATCH" };
  }
  if (!validLatitude(candidate.latitude) || !validLongitude(candidate.longitude)) {
    return { allowed: false, reason: "INVALID_COORDINATE" };
  }
  if (!validAccuracy(candidate.accuracyMeters)) {
    return { allowed: false, reason: "INVALID_ACCURACY" };
  }
  if (!Number.isSafeInteger(candidate.capturedAtMs)) {
    return { allowed: false, reason: "STALE_CAPTURE" };
  }
  if (candidate.capturedAtMs > nowMs + MAX_FUTURE_SKEW_MS) {
    return { allowed: false, reason: "FUTURE_CAPTURE" };
  }
  if (candidate.capturedAtMs < nowMs - MAX_CAPTURE_AGE_MS) {
    return { allowed: false, reason: "STALE_CAPTURE" };
  }
  if (
    lastAcceptedAtMs !== null
    && nowMs - lastAcceptedAtMs < MIN_PUBLISH_INTERVAL_MS
  ) {
    return { allowed: false, reason: "RATE_LIMITED" };
  }
  return { allowed: true };
}

export function viewerReadDecision(
  viewerUserId: string,
  ownerUserId: string,
  sharing: RemoteSharingState,
  consent: ConsentRecord,
  session: ShareSessionState,
  location: StoredLiveLocation,
  nowMs: number,
): ProtocolDecision {
  const sessionDecision = sessionMatches(sharing, session, ownerUserId);
  if (!sessionDecision.allowed) return sessionDecision;
  if (session.expiresAtMs <= nowMs) {
    return { allowed: false, reason: "SESSION_EXPIRED" };
  }
  if (
    consent.ownerUserId !== ownerUserId
    || consent.viewerUserId !== viewerUserId
    || !mutualConsentActive(consent, nowMs)
  ) {
    return { allowed: false, reason: "CONSENT_INACTIVE" };
  }
  if (sharing.visibility === "VISIBLE_SELECTED" && !consent.selectedByOwner) {
    return { allowed: false, reason: "VIEWER_NOT_SELECTED" };
  }
  if (
    location.ownerUserId !== ownerUserId
    || location.sessionId !== session.sessionId
    || location.sessionId !== sharing.activeShareSessionId
  ) {
    return { allowed: false, reason: "LOCATION_MISMATCH" };
  }
  if (
    !validEpoch(location.privacyEpoch)
    || location.privacyEpoch !== sharing.privacyEpoch
    || location.privacyEpoch !== session.privacyEpoch
  ) {
    return { allowed: false, reason: "PRIVACY_EPOCH_MISMATCH" };
  }
  if (!validLatitude(location.latitude) || !validLongitude(location.longitude)) {
    return { allowed: false, reason: "INVALID_COORDINATE" };
  }
  if (!validAccuracy(location.accuracyMeters)) {
    return { allowed: false, reason: "INVALID_ACCURACY" };
  }
  if (
    location.capturedAtMs > nowMs + MAX_FUTURE_SKEW_MS
    || location.acceptedAtMs > nowMs + MAX_FUTURE_SKEW_MS
  ) {
    return { allowed: false, reason: "FUTURE_CAPTURE" };
  }
  if (
    location.capturedAtMs < nowMs - MAX_CAPTURE_AGE_MS
    || location.acceptedAtMs < nowMs - MAX_CAPTURE_AGE_MS
  ) {
    return { allowed: false, reason: "LOCATION_STALE" };
  }
  return { allowed: true };
}
