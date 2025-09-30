import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contracts/asset_scanner_contract.dart';
import '../contracts/file_manager_contract.dart';
import '../contracts/similarity_detector_contract.dart';
import '../models/asset_model.dart';
import 'preferences_service.dart';

class CreativeVaultService {
  CreativeVaultService({
    required this.fileManager,
    required this.assetScanner,
    required this.similarityDetector,
    required this.preferencesService,
  });

  final FileManagerContract fileManager;
  final AssetScannerContract assetScanner;
  final SimilarityDetectorContract similarityDetector;
  final PreferencesService preferencesService;

  Future<String?> selectPath() async {
    final lastDirectory = await preferencesService.getLastDirectory();
    final selectedPath = await fileManager.selectDirectory(
      initialDirectory: lastDirectory,
    );

    if (selectedPath != null) {
      await preferencesService.saveLastDirectory(selectedPath);
    }

    return selectedPath;
  }

  Future<List<AssetModel>> scanAssets(String directoryPath) async {
    return await assetScanner.scanDirectory(directoryPath);
  }

  Stream<AssetModel> scanAssetsStream(String directoryPath) {
    return assetScanner.scanDirectoryStream(directoryPath);
  }

  Future<String?> uploadAsset() async {
    final lastDirectory = await preferencesService.getLastDirectory();
    return await fileManager.selectFile(
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'svg', 'json', 'riv'],
      initialDirectory: lastDirectory,
    );
  }

  Future<List<SimilarityResult>> findSimilarAssets(
    String uploadedAssetPath,
    List<AssetModel> existingAssets,
  ) async {
    return await similarityDetector.findSimilarAssets(
      uploadedAssetPath,
      existingAssets,
    );
  }

  Future<bool> checkIfAssetExists(
    String uploadedAssetPath,
    List<AssetModel> existingAssets,
  ) async {
    for (final asset in existingAssets) {
      final isIdentical = await similarityDetector.areAssetsIdentical(
        uploadedAssetPath,
        asset.path,
      );
      if (isIdentical) return true;
    }
    return false;
  }

  Future<String?> getLastSelectedDirectory() async {
    return await preferencesService.getLastDirectory();
  }
}

final creativeVaultServiceProvider = Provider<CreativeVaultService>((ref) {
  throw UnimplementedError(
    'CreativeVaultService provider must be overridden with actual implementations',
  );
});