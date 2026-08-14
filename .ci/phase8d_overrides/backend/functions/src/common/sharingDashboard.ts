export interface SharingGrantSummaryInput {
  readonly relationship: unknown;
  readonly ownerApproved: unknown;
  readonly viewerApproved: unknown;
  readonly selectedByOwner: unknown;
  readonly expiresAtMs: number | null;
}

export interface SharingAudienceSummary {
  readonly authorizedViewerCount: number;
  readonly selectedAuthorizedViewerCount: number;
  readonly pendingViewerCount: number;
  readonly blockedViewerCount: number;
}

export function isActiveAuthorizedGrant(
  grant: SharingGrantSummaryInput,
  nowMs: number,
): boolean {
  return grant.relationship === "AUTHORIZED"
    && grant.ownerApproved === true
    && grant.viewerApproved === true
    && (grant.expiresAtMs === null || grant.expiresAtMs > nowMs);
}

export function summarizeSharingGrants(
  grants: readonly SharingGrantSummaryInput[],
  nowMs: number,
): SharingAudienceSummary {
  let authorizedViewerCount = 0;
  let selectedAuthorizedViewerCount = 0;
  let pendingViewerCount = 0;
  let blockedViewerCount = 0;

  for (const grant of grants) {
    if (isActiveAuthorizedGrant(grant, nowMs)) {
      authorizedViewerCount += 1;
      if (grant.selectedByOwner === true) selectedAuthorizedViewerCount += 1;
    } else if (grant.relationship === "PENDING") {
      pendingViewerCount += 1;
    } else if (grant.relationship === "BLOCKED") {
      blockedViewerCount += 1;
    }
  }

  return {
    authorizedViewerCount,
    selectedAuthorizedViewerCount,
    pendingViewerCount,
    blockedViewerCount,
  };
}
