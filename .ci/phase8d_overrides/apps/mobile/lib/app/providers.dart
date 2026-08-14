import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/firebase/firebase_bootstrap.dart';
import '../data/auth/firebase_authentication_repository.dart';
import '../data/contacts/platform_contacts_repository.dart';
import '../data/local/nearby_database.dart';
import '../data/local/sqflite_contact_location_repository.dart';
import '../data/location/platform_user_location_repository.dart';
import '../data/remote/firebase_live_location_gateway.dart';
import '../data/remote/firebase_privacy_consent_gateway.dart';
import '../data/remote/firebase_remote_sharing_service.dart';
import '../data/remote/firebase_sharing_dashboard_gateway.dart';
import '../domain/models/authenticated_identity.dart';
import '../domain/repositories/authentication_repository.dart';
import '../domain/repositories/contact_location_repository.dart';
import '../domain/repositories/contacts_repository.dart';
import '../domain/repositories/remote_sharing_service.dart';
import '../domain/repositories/user_location_repository.dart';
import '../platform/contacts/method_channel_contacts_service.dart';
import '../platform/contacts/platform_contacts_service.dart';
import '../platform/location/method_channel_location_service.dart';
import '../platform/location/platform_location_service.dart';

final firebaseBootstrapStateProvider = Provider<FirebaseBootstrapState>(
  (ref) => FirebaseBootstrapState.disabledMissingConfiguration,
);

final platformContactsServiceProvider = Provider<PlatformContactsService>(
  (ref) => MethodChannelContactsService(),
);

final platformLocationServiceProvider = Provider<PlatformLocationService>(
  (ref) => MethodChannelLocationService(),
);

final nearbyDatabaseProvider = Provider<NearbyDatabase>(
  (ref) => NearbyDatabase(),
);

final contactsRepositoryProvider = Provider<ContactsRepository>(
  (ref) => PlatformContactsRepository(
    ref.watch(platformContactsServiceProvider),
  ),
);

final userLocationRepositoryProvider = Provider<UserLocationRepository>(
  (ref) => PlatformUserLocationRepository(
    ref.watch(platformLocationServiceProvider),
  ),
);

final contactLocationRepositoryProvider = Provider<ContactLocationRepository>(
  (ref) => SqfliteContactLocationRepository(
    ref.watch(nearbyDatabaseProvider),
  ),
);

final authenticationRepositoryProvider = Provider<AuthenticationRepository?>(
  (ref) {
    if (ref.watch(firebaseBootstrapStateProvider) !=
        FirebaseBootstrapState.initialized) {
      return null;
    }
    return FirebaseAuthenticationRepository(FirebaseAuth.instance);
  },
);

final authenticatedIdentityProvider = StreamProvider<AuthenticatedIdentity>(
  (ref) {
    final AuthenticationRepository? repository =
        ref.watch(authenticationRepositoryProvider);
    if (repository == null) {
      return Stream<AuthenticatedIdentity>.value(
        const AuthenticatedIdentity.signedOut(),
      );
    }
    return repository.watchIdentity();
  },
);

final remoteSharingServiceProvider = Provider<RemoteSharingService?>(
  (ref) {
    if (ref.watch(firebaseBootstrapStateProvider) !=
        FirebaseBootstrapState.initialized) {
      return null;
    }
    final FirebaseFunctions functions = FirebaseFunctions.instance;
    return FirebaseRemoteSharingService(
      privacy: FirebasePrivacyConsentGateway(functions),
      liveLocation: FirebaseLiveLocationGateway(functions),
      dashboard: FirebaseSharingDashboardGateway(functions),
    );
  },
);
