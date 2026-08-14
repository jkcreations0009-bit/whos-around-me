import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models/authenticated_identity.dart';
import '../../domain/repositories/authentication_repository.dart';

final class FirebaseIdentityMapper {
  const FirebaseIdentityMapper();

  AuthenticatedIdentity map({
    required String? userId,
    required bool isAnonymous,
    required bool identityVerifiedClaim,
  }) {
    final String? normalized = userId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return const AuthenticatedIdentity.signedOut();
    }
    if (isAnonymous || !identityVerifiedClaim) {
      return AuthenticatedIdentity(
        state: AuthenticationState.authenticatedUnverified,
        userId: normalized,
        isAnonymous: isAnonymous,
      );
    }
    return AuthenticatedIdentity(
      state: AuthenticationState.authenticatedVerified,
      userId: normalized,
      isAnonymous: false,
    );
  }
}

final class FirebaseAuthenticationRepository implements AuthenticationRepository {
  FirebaseAuthenticationRepository(
    this._auth, {
    FirebaseIdentityMapper mapper = const FirebaseIdentityMapper(),
  }) : _mapper = mapper;

  final FirebaseAuth _auth;
  final FirebaseIdentityMapper _mapper;

  @override
  Stream<AuthenticatedIdentity> watchIdentity() {
    return _auth.idTokenChanges().asyncMap(_mapUser);
  }

  @override
  Future<AuthenticatedIdentity> refreshIdentity() async {
    final User? user = _auth.currentUser;
    if (user == null) return const AuthenticatedIdentity.signedOut();
    await user.getIdToken(true);
    return _mapUser(user);
  }

  @override
  Future<void> signOut() => _auth.signOut();

  Future<AuthenticatedIdentity> _mapUser(User? user) async {
    if (user == null) return const AuthenticatedIdentity.signedOut();
    final IdTokenResult token = await user.getIdTokenResult();
    final bool verifiedClaim = token.claims?['identity_verified'] == true;

    // This client-side claim is only a UX gate. The callable backend verifies
    // Firebase Auth and the same custom claim again before any privileged write.
    return _mapper.map(
      userId: user.uid,
      isAnonymous: user.isAnonymous,
      identityVerifiedClaim: verifiedClaim,
    );
  }
}
