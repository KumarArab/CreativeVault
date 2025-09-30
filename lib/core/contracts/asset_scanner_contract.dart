import '../models/asset_model.dart';

abstract class AssetScannerContract {
  Future<List<AssetModel>> scanDirectory(String directoryPath);
  Stream<AssetModel> scanDirectoryStream(String directoryPath);
  Future<bool> isAssetSupported(String filePath);
  Future<AssetType> determineAssetType(String filePath);
}