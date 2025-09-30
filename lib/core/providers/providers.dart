import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contracts/asset_scanner_contract.dart';
import '../contracts/file_manager_contract.dart';
import '../contracts/similarity_detector_contract.dart';
import '../services/creative_vault_service.dart';
import '../services/preferences_service.dart';
import '../../infrastructure/asset_scanner/asset_scanner_impl.dart';
import '../../infrastructure/file_manager/macos_file_manager.dart';
import '../../infrastructure/similarity/similarity_detector_impl.dart';

final fileManagerProvider = Provider<FileManagerContract>((ref) {
  return MacOSFileManager();
});

final assetScannerProvider = Provider<AssetScannerContract>((ref) {
  final fileManager = ref.watch(fileManagerProvider);
  return AssetScannerImpl(fileManager: fileManager);
});

final similarityDetectorProvider = Provider<SimilarityDetectorContract>((ref) {
  return SimilarityDetectorImpl();
});

final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  return PreferencesService();
});

final creativeVaultServiceImplProvider = Provider<CreativeVaultService>((ref) {
  return CreativeVaultService(
    fileManager: ref.watch(fileManagerProvider),
    assetScanner: ref.watch(assetScannerProvider),
    similarityDetector: ref.watch(similarityDetectorProvider),
    preferencesService: ref.watch(preferencesServiceProvider),
  );
});