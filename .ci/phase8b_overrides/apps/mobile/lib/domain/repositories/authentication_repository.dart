import '../models/authenticated_identity.dart';

abstract interface class AuthenticationRepository {
  Stream<AuthenticatedIdentity> watchIdentity();
  Future<AuthenticatedIdentity> refreshIdentity();
  Future<void> signOut();
}
