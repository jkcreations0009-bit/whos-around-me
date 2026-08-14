import '../models/authenticated_identity.dart';
import '../models/privacy_state.dart';
import '../models/sharing_consent.dart';
import '../models/visibility_mode.dart';

enum SharingAuthorizationDecision { allow, deny }

final class SharingAuthorizationPolicy {
  const SharingAuthorizationPolicy();

  SharingAuthorizationDecision canOpenShareSession({
    required AuthenticatedIdentity ownerIdentity,
    required PrivacyState privacyState,
    required SharingConsent consent,
    required DateTime nowUtc,
  }) {
    if (!ownerIdentity.isEligibleForRemoteSharing) {
      return SharingAuthorizationDecision.deny;
    }
    if (ownerIdentity.userId != consent.ownerUserId) {
      return SharingAuthorizationDecision.deny;
    }
    if (!_isRemotelyVisible(privacyState.visibilityMode)) {
      return SharingAuthorizationDecision.deny;
    }
    if (!privacyState.liveSharingEnabled) {
      return SharingAuthorizationDecision.deny;
    }
    final String? sessionId = privacyState.activeShareSessionId;
    if (sessionId == null || sessionId.trim().length < 16) {
      return SharingAuthorizationDecision.deny;
    }
    if (!consent.isMutuallyConsentedAt(nowUtc)) {
      return SharingAuthorizationDecision.deny;
    }
    if (privacyState.visibilityMode == VisibilityMode.visibleSelected &&
        !consent.selectedByOwner) {
      return SharingAuthorizationDecision.deny;
    }
    return SharingAuthorizationDecision.allow;
  }

  SharingAuthorizationDecision canViewerReceiveRemoteLocation({
    required AuthenticatedIdentity viewerIdentity,
    required PrivacyState ownerPrivacyState,
    required SharingConsent consent,
    required DateTime nowUtc,
  }) {
    if (!viewerIdentity.isEligibleForRemoteSharing) {
      return SharingAuthorizationDecision.deny;
    }
    if (viewerIdentity.userId != consent.viewerUserId) {
      return SharingAuthorizationDecision.deny;
    }
    if (!_isRemotelyVisible(ownerPrivacyState.visibilityMode)) {
      return SharingAuthorizationDecision.deny;
    }
    if (!ownerPrivacyState.liveSharingEnabled) {
      return SharingAuthorizationDecision.deny;
    }
    final String? sessionId = ownerPrivacyState.activeShareSessionId;
    if (sessionId == null || sessionId.trim().length < 16) {
      return SharingAuthorizationDecision.deny;
    }
    if (!consent.isMutuallyConsentedAt(nowUtc)) {
      return SharingAuthorizationDecision.deny;
    }
    if (ownerPrivacyState.visibilityMode == VisibilityMode.visibleSelected &&
        !consent.selectedByOwner) {
      return SharingAuthorizationDecision.deny;
    }
    return SharingAuthorizationDecision.allow;
  }

  bool _isRemotelyVisible(VisibilityMode mode) {
    return mode == VisibilityMode.visibleApproved ||
        mode == VisibilityMode.visibleSelected;
  }
}
