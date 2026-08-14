export interface SharingGrantSummaryInput {
  readonly relationship: unknown;
  readonly selectedByOwner: unknown;
}

export interface SharingAudienceSummary {
  readonly authorizedViewerCount: number;
  readonly selectedAuthorizedViewerCount: number;
  readonly pendingViewerCount: number;
  readonly blockedViewerCount: number;
}

export function summarizeSharingGrants(
  grants: readonly SharingGrantSummaryInput[],
): SharingAudienceSummary {
  let authorizedViewerCount = 0;
  let selectedAuthorizedViewerCount = 0;
  let pendingViewerCount = 0;
  let blockedViewerCount = 0;

  for (const grant of grants) {
    if (grant.relationship === "AUTHORIZED") {
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
