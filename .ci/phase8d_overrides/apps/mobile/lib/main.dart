import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/config/app_environment.dart';
import 'core/firebase/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppEnvironmentConfig environment =
      AppEnvironmentConfig.fromDartDefine();
  final FirebaseBootstrapState firebaseState =
      await FirebaseBootstrap.initialize(environment: environment);
  runApp(
    ProviderScope(
      overrides: <Override>[
        firebaseBootstrapStateProvider.overrideWithValue(firebaseState),
      ],
      child: const WhosAroundMeApp(),
    ),
  );
}
