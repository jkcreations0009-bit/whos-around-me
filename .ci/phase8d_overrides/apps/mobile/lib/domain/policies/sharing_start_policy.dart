import '../models/authenticated_identity.dart';
import '../models/sharing_dashboard.dart';
import '../models/visibility_mode.dart';

final class SharingStartPolicy {
  const SharingStartPolicy();

  bool canStart({
    required AuthenticatedIdentity identity,
    required SharingDashboard dashboard,
  }) {
    if (!identity.isEligibleForRemoteSharing) return false;
    if (dashboard.liveSharingEnabled) return false;
    return switch (dashboard.visibilityMode) {
      VisibilityMode.visibleApproved => dashboard.authorizedViewerCount > 0,
      VisibilityMode.visibleSelected =>
        dashboard.selectedAuthorizedViewerCount > 0,
      VisibilityMode.privateLocal || VisibilityMode.hidden => false,
    };
  }
}
