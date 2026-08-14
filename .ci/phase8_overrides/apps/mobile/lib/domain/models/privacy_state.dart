import 'visibility_mode.dart';

final class PrivacyState {
  const PrivacyState({
    required this.visibilityMode,
    required this.privacyEpoch,
    required this.liveSharingEnabled,
    required this.activeShareSessionId,
  });

  const PrivacyState.privateByDefault()
      : visibilityMode = VisibilityMode.privateLocal,
        privacyEpoch = 0,
        liveSharingEnabled = false,
        activeShareSessionId = null;

  final VisibilityMode visibilityMode;
  final int privacyEpoch;
  final bool liveSharingEnabled;
  final String? activeShareSessionId;

  PrivacyState toHidden() {
    if (privacyEpoch < 0) {
      throw StateError('privacyEpoch must be non-negative');
    }
    return PrivacyState(
      visibilityMode: VisibilityMode.hidden,
      privacyEpoch: privacyEpoch + 1,
      liveSharingEnabled: false,
      activeShareSessionId: null,
    );
  }
}
