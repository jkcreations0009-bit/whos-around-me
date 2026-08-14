import 'package:flutter/material.dart';

import '../core/config/app_environment.dart';
import '../features/nearby/nearby_local_screen.dart';
import '../features/sharing/sharing_center_screen.dart';

final class WhosAroundMeApp extends StatelessWidget {
  const WhosAroundMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final AppEnvironmentConfig config = AppEnvironmentConfig.fromDartDefine();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: config.displayName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const _HomeShell(),
    );
  }
}

final class _HomeShell extends StatefulWidget {
  const _HomeShell();

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

final class _HomeShellState extends State<_HomeShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _selectedIndex == 0
          ? const NearbyLocalScreen()
          : const SharingCenterScreen(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int value) {
          setState(() => _selectedIndex = value);
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Nearby',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield),
            label: 'Sharing',
          ),
        ],
      ),
    );
  }
}
