import '../models/asset_model.dart';

abstract class SimilarityDetectorContract {
  Future<List<SimilarityResult>> findSimilarAssets(
    String uploadedAssetPath,
    List<AssetModel> assetsToCompare,
  );

  Future<bool> areAssetsIdentical(String assetPath1, String assetPath2);

  Future<double> calculateSimilarity(String assetPath1, String assetPath2);

  Future<String> generateAssetHash(String assetPath);
}