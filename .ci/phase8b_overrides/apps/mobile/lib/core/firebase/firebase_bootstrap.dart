import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';

import '../config/app_environment.dart';

enum FirebaseBootstrapState {
  disabledMissingConfiguration,
  initialized,
}

final class FirebaseRuntimeConfig {
  const FirebaseRuntimeConfig({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
    required this.storageBucket,
  });

  factory FirebaseRuntimeConfig.fromDartDefines() {
    return const FirebaseRuntimeConfig(
      apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
      appId: String.fromEnvironment('FIREBASE_APP_ID'),
      messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
      projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
      storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    );
  }

  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
  final String storageBucket;

  bool get isConfigured {
    return apiKey.trim().isNotEmpty &&
        appId.trim().isNotEmpty &&
        messagingSenderId.trim().isNotEmpty &&
        projectId.trim().isNotEmpty;
  }

  FirebaseOptions toFirebaseOptions(AppEnvironmentConfig environment) {
    if (!isConfigured) {
      throw StateError('Firebase runtime configuration is incomplete.');
    }
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: storageBucket.trim().isEmpty ? null : storageBucket,
      iosBundleId: environment.applicationId,
    );
  }
}

final class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static Future<FirebaseBootstrapState> initialize({
    required AppEnvironmentConfig environment,
    FirebaseRuntimeConfig? runtimeConfig,
  }) async {
    final FirebaseRuntimeConfig config =
        runtimeConfig ?? FirebaseRuntimeConfig.fromDartDefines();
    if (!config.isConfigured) {
      // Fail closed: private/local features remain available, but no Firebase
      // service is initialized and therefore no remote sharing can occur.
      return FirebaseBootstrapState.disabledMissingConfiguration;
    }

    await Firebase.initializeApp(
      options: config.toFirebaseOptions(environment),
    );

    final bool useDebugAttestation =
        environment.environment == AppEnvironment.development ||
            environment.environment == AppEnvironment.test;

    await FirebaseAppCheck.instance.activate(
      providerAndroid: useDebugAttestation
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: useDebugAttestation
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );

    return FirebaseBootstrapState.initialized;
  }
}
