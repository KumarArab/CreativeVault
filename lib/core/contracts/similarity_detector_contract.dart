import '../models/asset_model.dart';

abstract class SimilarityDetectorContract {
  Future<List<SimilarityResult>> findSimilarAssets(String uploadedAssetPath, List<AssetModel> assetsToCompare);

  Future<bool> areAssetsIdentical(String assetPath1, String assetPath2);

  Future<double> calculateSimilarity(String assetPath1, String assetPath2);

  Future<String?> generateAssetHash(String assetPath);

  // Cache management methods
  Future<void> preprocessAssetsInDirectory(String directoryPath, List<AssetModel> assets);
  Future<void> clearCacheForDirectory(String directoryPath);
  Future<bool> needsCacheUpdate(String directoryPath, List<AssetModel> currentAssets);
  Future<void> cleanupDeletedFiles(String directoryPath, List<AssetModel> currentAssets);
}
