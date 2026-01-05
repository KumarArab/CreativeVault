import '../../core/contracts/similarity_detector_contract.dart';
import '../../core/models/asset_model.dart';
import 'hybrid_similarity_detector.dart';

/// Core ML-based similarity detector implementation
class SimilarityDetectorImpl implements SimilarityDetectorContract {
  final HybridSimilarityDetector _hybridDetector = HybridSimilarityDetector();
  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    print('🚀 Initializing similarity detector system...');
    await _hybridDetector.initialize();
    _isInitialized = true;
    print('✅ Similarity detector system initialized');
  }

  @override
  Future<List<SimilarityResult>> findSimilarAssets(String targetImagePath, List<AssetModel> assetsToCompare) async {
    if (!_isInitialized) {
      print('⚠️ Similarity detector not initialized, initializing now...');
      await initialize();
    }

    print('🔍 Starting similarity search...');
    return await _hybridDetector.findSimilarAssets(targetImagePath, assetsToCompare);
  }

  @override
  Future<bool> areAssetsIdentical(String assetPath1, String assetPath2) async {
    if (!_isInitialized) {
      print('⚠️ Similarity detector not initialized, initializing now...');
      await initialize();
    }

    return await _hybridDetector.areAssetsIdentical(assetPath1, assetPath2);
  }

  @override
  Future<double> calculateSimilarity(String assetPath1, String assetPath2) async {
    if (!_isInitialized) {
      print('⚠️ Similarity detector not initialized, initializing now...');
      await initialize();
    }

    return await _hybridDetector.calculateSimilarity(assetPath1, assetPath2);
  }

  @override
  Future<String?> generateAssetHash(String assetPath) async {
    if (!_isInitialized) {
      print('⚠️ Similarity detector not initialized, initializing now...');
      await initialize();
    }

    return await _hybridDetector.generateAssetHash(assetPath);
  }

  @override
  Future<void> preprocessAssetsInDirectory(String directoryPath, List<AssetModel> assets) async {
    if (!_isInitialized) {
      print('⚠️ Similarity detector not initialized, initializing now...');
      await initialize();
    }

    await _hybridDetector.preprocessAssetsInDirectory(directoryPath, assets);
  }

  @override
  Future<void> clearCacheForDirectory(String directoryPath) async {
    if (!_isInitialized) {
      print('⚠️ Similarity detector not initialized, initializing now...');
      await initialize();
    }

    await _hybridDetector.clearCacheForDirectory(directoryPath);
  }

  @override
  Future<bool> needsCacheUpdate(String directoryPath, List<AssetModel> currentAssets) async {
    if (!_isInitialized) {
      print('⚠️ Similarity detector not initialized, initializing now...');
      await initialize();
    }

    return await _hybridDetector.needsCacheUpdate(directoryPath, currentAssets);
  }

  @override
  Future<void> cleanupDeletedFiles(String directoryPath, List<AssetModel> currentAssets) async {
    if (!_isInitialized) {
      print('⚠️ Similarity detector not initialized, initializing now...');
      await initialize();
    }

    await _hybridDetector.cleanupDeletedFiles(directoryPath, currentAssets);
  }

  @override
  void dispose() {
    print('🔄 Disposing similarity detector system...');
    _hybridDetector.dispose();
    _isInitialized = false;
    print('✅ Similarity detector system disposed');
  }
}
