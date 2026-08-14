import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/app_environment.dart';
import 'core/firebase/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppEnvironmentConfig environment =
      AppEnvironmentConfig.fromDartDefine();
  await FirebaseBootstrap.initialize(environment: environment);
  runApp(
    const ProviderScope(
      child: WhosAroundMeApp(),
    ),
  );
}
