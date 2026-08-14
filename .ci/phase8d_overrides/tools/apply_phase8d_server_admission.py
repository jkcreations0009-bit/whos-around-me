#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIVE = ROOT / 'backend/functions/src/callables/liveLocation.ts'

text = LIVE.read_text()

import_marker = '} from "../common/liveLocationProtocol";\n'
import_line = 'import { summarizeSharingGrants } from "../common/sharingDashboard";\n'
if import_line not in text:
    if import_marker not in text:
        raise SystemExit('Phase 8D patch could not find live-location import marker.')
    text = text.replace(import_marker, import_marker + import_line, 1)

admission_marker = '    const nextEpoch = currentSharing.privacyEpoch + 1;\n'
admission_block = '''    const grantsSnapshot = await transaction.get(
      ownerRef.collection("sharingGrants"),
    );
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
    const eligibleAudienceExists = currentSharing.visibility === "VISIBLE_APPROVED"
      ? audience.authorizedViewerCount > 0
      : audience.selectedAuthorizedViewerCount > 0;
    if (!eligibleAudienceExists) {
      throw new HttpsError(
        "failed-precondition",
        "No currently eligible sharing audience is available.",
      );
    }

'''
if 'eligibleAudienceExists' not in text:
    if admission_marker not in text:
        raise SystemExit('Phase 8D patch could not find share-session admission marker.')
    text = text.replace(admission_marker, admission_block + admission_marker, 1)

LIVE.write_text(text)
print('Applied Phase 8D server-side eligible-audience admission gate.')
