import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/controllers/app_controller.dart';
import 'presentation/models/app_state.dart';
import 'presentation/screens/asset_gallery_screen.dart';
import 'presentation/screens/path_selection_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: CreativeVaultApp(),
    ),
  );
}

class CreativeVaultApp extends StatelessWidget {
  const CreativeVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CreativeVault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: '.SF UI Text',
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appControllerProvider);

    return Scaffold(
      body: _buildCurrentScreen(appState),
    );
  }

  Widget _buildCurrentScreen(AppState appState) {
    switch (appState.status) {
      case AppStatus.initial:
      case AppStatus.pathSelected:
      case AppStatus.scanning:
      case AppStatus.error:
        return const PathSelectionScreen();

      case AppStatus.assetsLoaded:
      case AppStatus.uploadingAsset:
      case AppStatus.findingSimilarAssets:
        return const AssetGalleryScreen();
    }
  }
}
