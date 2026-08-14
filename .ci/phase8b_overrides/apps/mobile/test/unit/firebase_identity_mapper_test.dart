import 'package:flutter_test/flutter_test.dart';
import 'package:nearby_contacts/data/auth/firebase_authentication_repository.dart';
import 'package:nearby_contacts/domain/models/authenticated_identity.dart';

void main() {
  const FirebaseIdentityMapper mapper = FirebaseIdentityMapper();

  test('missing uid maps to signed out', () {
    final result = mapper.map(
      userId: '   ',
      isAnonymous: false,
      identityVerifiedClaim: true,
    );
    expect(result.state, AuthenticationState.signedOut);
  });

  test('anonymous user is never remotely verified', () {
    final result = mapper.map(
      userId: 'user-a',
      isAnonymous: true,
      identityVerifiedClaim: true,
    );
    expect(result.state, AuthenticationState.authenticatedUnverified);
    expect(result.isEligibleForRemoteSharing, isFalse);
  });

  test('signed-in user without server verification claim remains unverified', () {
    final result = mapper.map(
      userId: 'user-a',
      isAnonymous: false,
      identityVerifiedClaim: false,
    );
    expect(result.state, AuthenticationState.authenticatedUnverified);
    expect(result.isEligibleForRemoteSharing, isFalse);
  });

  test('non-anonymous user with identity_verified claim becomes verified', () {
    final result = mapper.map(
      userId: 'user-a',
      isAnonymous: false,
      identityVerifiedClaim: true,
    );
    expect(result.state, AuthenticationState.authenticatedVerified);
    expect(result.isEligibleForRemoteSharing, isTrue);
  });
}
