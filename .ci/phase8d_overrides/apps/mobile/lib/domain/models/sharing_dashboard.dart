import 'visibility_mode.dart';

final class SharingDashboard {
  const SharingDashboard({
    required this.visibilityMode,
    required this.liveSharingEnabled,
    required this.authorizedViewerCount,
    required this.selectedAuthorizedViewerCount,
    required this.pendingViewerCount,
    required this.blockedViewerCount,
    this.sessionExpiresAtMs,
  });

  final VisibilityMode visibilityMode;
  final bool liveSharingEnabled;
  final int authorizedViewerCount;
  final int selectedAuthorizedViewerCount;
  final int pendingViewerCount;
  final int blockedViewerCount;
  final int? sessionExpiresAtMs;
}
