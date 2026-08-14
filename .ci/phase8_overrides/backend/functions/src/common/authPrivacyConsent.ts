export type AuthenticationState =
  | "SIGNED_OUT"
  | "AUTHENTICATED_UNVERIFIED"
  | "AUTHENTICATED_VERIFIED";

export interface AuthenticatedIdentity {
  readonly state: AuthenticationState;
  readonly userId: string | null;
  readonly isAnonymous: boolean;
}

export type ConsentRelationship =
  | "NONE"
  | "PENDING"
  | "AUTHORIZED"
  | "REVOKED"
  | "BLOCKED";

export type ConsentVisibility =
  | "PRIVATE_LOCAL"
  | "VISIBLE_APPROVED"
  | "VISIBLE_SELECTED"
  | "HIDDEN";

export interface ConsentRecord {
  readonly ownerUserId: string;
  readonly viewerUserId: string;
  readonly relationship: ConsentRelationship;
  readonly ownerApproved: boolean;
  readonly viewerApproved: boolean;
  readonly selectedByOwner: boolean;
  readonly ownerApprovedAtMs: number | null;
  readonly viewerApprovedAtMs: number | null;
  readonly expiresAtMs: number | null;
}

export interface RemoteSharingState {
  readonly visibility: ConsentVisibility;
  readonly liveSharingEnabled: boolean;
  readonly activeShareSessionId: string | null;
  readonly privacyEpoch: number;
}

export function identityEligible(identity: AuthenticatedIdentity): boolean {
  return identity.state === "AUTHENTICATED_VERIFIED"
    && identity.userId !== null
    && identity.userId.trim().length > 0
    && !identity.isAnonymous;
}

export function mutualConsentActive(
  consent: ConsentRecord,
  nowMs: number,
): boolean {
  if (consent.relationship !== "AUTHORIZED") return false;
  if (!consent.ownerApproved || !consent.viewerApproved) return false;
  if (consent.ownerApprovedAtMs === null || consent.viewerApprovedAtMs === null) {
    return false;
  }
  if (consent.expiresAtMs !== null && consent.expiresAtMs <= nowMs) return false;
  return true;
}

export function canOpenShareSession(
  ownerIdentity: AuthenticatedIdentity,
  sharing: RemoteSharingState,
  consent: ConsentRecord,
  nowMs: number,
): boolean {
  if (!identityEligible(ownerIdentity)) return false;
  if (ownerIdentity.userId !== consent.ownerUserId) return false;
  if (sharing.visibility === "HIDDEN" || sharing.visibility === "PRIVATE_LOCAL") {
    return false;
  }
  if (!sharing.liveSharingEnabled) return false;
  if (sharing.activeShareSessionId === null
      || sharing.activeShareSessionId.trim().length < 16) return false;
  if (!mutualConsentActive(consent, nowMs)) return false;
  if (sharing.visibility === "VISIBLE_SELECTED" && !consent.selectedByOwner) {
    return false;
  }
  return true;
}

export function transitionToHiddenLocked(
  sharing: RemoteSharingState,
): RemoteSharingState {
  if (!Number.isSafeInteger(sharing.privacyEpoch) || sharing.privacyEpoch < 0) {
    throw new Error("privacyEpoch must be a non-negative safe integer");
  }
  return {
    visibility: "HIDDEN",
    liveSharingEnabled: false,
    activeShareSessionId: null,
    privacyEpoch: sharing.privacyEpoch + 1,
  };
}
