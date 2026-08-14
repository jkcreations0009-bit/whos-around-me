enum AuthenticationState {
  signedOut,
  authenticatedUnverified,
  authenticatedVerified,
}

final class AuthenticatedIdentity {
  const AuthenticatedIdentity({
    required this.state,
    this.userId,
    this.isAnonymous = false,
  });

  const AuthenticatedIdentity.signedOut()
      : state = AuthenticationState.signedOut,
        userId = null,
        isAnonymous = false;

  final AuthenticationState state;
  final String? userId;
  final bool isAnonymous;

  bool get isEligibleForRemoteSharing {
    final String? id = userId?.trim();
    return state == AuthenticationState.authenticatedVerified &&
        id != null &&
        id.isNotEmpty &&
        !isAnonymous;
  }
}
