import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/asset_model.dart';
import '../../core/providers/providers.dart';
import '../../core/services/creative_vault_service.dart';
import '../models/app_state.dart';

class AppController extends StateNotifier<AppState> {
  AppController(this._creativeVaultService) : super(const AppState()) {
    _loadLastDirectory();
  }

  final CreativeVaultService _creativeVaultService;
  StreamSubscription<AssetModel>? _scanSubscription;

  Future<void> selectPath() async {
    try {
      state = state.copyWith(status: AppStatus.initial);

      final selectedPath = await _creativeVaultService.selectPath();
      if (selectedPath == null) return;

      state = state.copyWith(
        status: AppStatus.pathSelected,
        selectedPath: selectedPath,
        assets: [],
        scanProgress: 0.0,
      );

      await _scanAssets(selectedPath);
    } catch (e) {
      state = state.copyWith(
        status: AppStatus.error,
        errorMessage: 'Failed to select path: $e',
      );
    }
  }

  Future<void> rescanAssets() async {
    try {
      final currentPath = state.selectedPath;
      if (currentPath == null) return;

      state = state.copyWith(
        status: AppStatus.scanning,
        assets: [],
        scanProgress: 0.0,
      );

      await _scanAssets(currentPath);
    } catch (e) {
      state = state.copyWith(
        status: AppStatus.error,
        errorMessage: 'Failed to rescan assets: $e',
      );
    }
  }

  Future<void> _scanAssets(String directoryPath) async {
    try {
      state = state.copyWith(
        status: AppStatus.scanning,
        scanProgress: 0.0,
      );

      final assets = <AssetModel>[];
      var processedCount = 0;

      _scanSubscription?.cancel();
      _scanSubscription = _creativeVaultService
          .scanAssetsStream(directoryPath)
          .listen(
        (asset) {
          assets.add(asset);
          processedCount++;

          state = state.copyWith(
            assets: List.from(assets),
            scanProgress: processedCount / (processedCount + 1).toDouble(),
          );
        },
        onDone: () {
          state = state.copyWith(
            status: AppStatus.assetsLoaded,
            assets: List.from(assets),
            scanProgress: 1.0,
          );
        },
        onError: (error) {
          state = state.copyWith(
            status: AppStatus.error,
            errorMessage: 'Failed to scan assets: $error',
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        status: AppStatus.error,
        errorMessage: 'Failed to start asset scanning: $e',
      );
    }
  }

  Future<void> uploadAssetAndFindSimilar() async {
    try {
      state = state.copyWith(status: AppStatus.uploadingAsset);

      final uploadedAssetPath = await _creativeVaultService.uploadAsset();
      if (uploadedAssetPath == null) {
        state = state.copyWith(status: AppStatus.assetsLoaded);
        return;
      }

      state = state.copyWith(status: AppStatus.findingSimilarAssets);

      // Find exact matches
      final exactMatches = <AssetModel>[];
      for (final asset in state.assets) {
        final isIdentical = await _creativeVaultService
            .similarityDetector
            .areAssetsIdentical(uploadedAssetPath, asset.path);
        if (isIdentical) {
          exactMatches.add(asset);
        }
      }

      final similarAssets = await _creativeVaultService.findSimilarAssets(
        uploadedAssetPath,
        state.assets,
      );

      final uploadedAsset = AssetModel(
        path: uploadedAssetPath,
        name: uploadedAssetPath.split('/').last.split('.').first,
        type: await _creativeVaultService
            .assetScanner
            .determineAssetType(uploadedAssetPath),
        format: _getAssetFormat(uploadedAssetPath),
        size: 0,
        lastModified: DateTime.now(),
      );

      state = state.copyWith(
        status: AppStatus.assetsLoaded,
        uploadedAsset: uploadedAsset,
        exactMatches: exactMatches,
        similarAssets: similarAssets,
      );
    } catch (e) {
      state = state.copyWith(
        status: AppStatus.error,
        errorMessage: 'Failed to upload and find similar assets: $e',
      );
    }
  }

  void clearUploadedAsset() {
    state = state.copyWith(
      uploadedAsset: null,
      similarAssets: [],
      exactMatches: [],
    );
  }

  void clearError() {
    state = state.copyWith(
      status: state.selectedPath != null ? AppStatus.assetsLoaded : AppStatus.initial,
      errorMessage: null,
    );
  }

  void setFilter(AssetTypeFilter filter) {
    state = state.copyWith(selectedFilter: filter);
  }

  Future<void> _loadLastDirectory() async {
    try {
      final lastDirectory = await _creativeVaultService.getLastSelectedDirectory();
      if (lastDirectory != null) {
        state = state.copyWith(selectedPath: lastDirectory);
      }
    } catch (e) {
      // Ignore errors when loading last directory
    }
  }

  AssetFormat _getAssetFormat(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'png':
        return AssetFormat.png;
      case 'jpg':
      case 'jpeg':
        return AssetFormat.jpg;
      case 'webp':
        return AssetFormat.webp;
      case 'svg':
        return AssetFormat.svg;
      case 'json':
        return AssetFormat.json;
      case 'riv':
        return AssetFormat.riv;
      default:
        return AssetFormat.unknown;
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }
}

final appControllerProvider = StateNotifierProvider<AppController, AppState>((ref) {
  final creativeVaultService = ref.watch(creativeVaultServiceImplProvider);
  return AppController(creativeVaultService);
});