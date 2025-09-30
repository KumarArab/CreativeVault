import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import '../../core/contracts/similarity_detector_contract.dart';
import '../../core/models/asset_model.dart';
import 'image_similarity_detector.dart';
import 'vector_similarity_detector.dart';

class SimilarityDetectorImpl implements SimilarityDetectorContract {
  SimilarityDetectorImpl()
    : _imageSimilarityDetector = ImageSimilarityDetector(),
      _vectorSimilarityDetector = VectorSimilarityDetector();

  final ImageSimilarityDetector _imageSimilarityDetector;
  final VectorSimilarityDetector _vectorSimilarityDetector;

  @override
  Future<List<SimilarityResult>> findSimilarAssets(String uploadedAssetPath, List<AssetModel> assetsToCompare) async {
    try {
      print('Finding similar assets for uploaded image: $uploadedAssetPath');
      print('Comparing against ${assetsToCompare.length} assets');

      // Always treat uploaded asset as image and compare visually against ALL assets
      final allResults = await _imageSimilarityDetector.findSimilarAssetsVisually(uploadedAssetPath, assetsToCompare);

      // Filter to only show results > 60% (histogram-based algorithm is more accurate)
      final filteredResults = allResults.where((result) => result.similarity >= 0.60).toList();

      print('Found ${allResults.length} similar assets, ${filteredResults.length} above 60% threshold');

      filteredResults.sort((a, b) => b.similarity.compareTo(a.similarity));
      return filteredResults.take(20).toList();
    } catch (e) {
      print('Error finding similar assets: $e');
      throw SimilarityDetectorException('Failed to find similar assets: $e');
    }
  }

  @override
  Future<bool> areAssetsIdentical(String assetPath1, String assetPath2) async {
    try {
      print('Comparing assets visually: $assetPath1 vs $assetPath2');

      // Always use visual comparison (treat as images)
      final similarity = await _imageSimilarityDetector.calculateVisualSimilarity(assetPath1, assetPath2);
      print('Visual similarity: $similarity');

      // Consider identical if >95% similar
      final result = similarity >= 0.95;
      print('Identity check result: $result');
      return result;
    } catch (e) {
      print('Error in identity check: $e');
      return false;
    }
  }

  @override
  Future<double> calculateSimilarity(String assetPath1, String assetPath2) async {
    try {
      final type1 = await _determineAssetTypeFromPath(assetPath1);
      final type2 = await _determineAssetTypeFromPath(assetPath2);

      if (type1 != type2) return 0.0;

      switch (type1) {
        case AssetType.image:
          return await _imageSimilarityDetector.calculateImageSimilarity(assetPath1, assetPath2);

        case AssetType.svg:
          return await _vectorSimilarityDetector.calculateVectorSimilarity(assetPath1, assetPath2);

        default:
          return await _calculateFallbackSimilarity(assetPath1, assetPath2);
      }
    } catch (e) {
      return 0.0;
    }
  }

  @override
  Future<String> generateAssetHash(String assetPath) async {
    try {
      final file = File(assetPath);
      if (!await file.exists()) {
        throw SimilarityDetectorException('Asset file not found: $assetPath');
      }

      final bytes = await file.readAsBytes();
      return sha256.convert(bytes).toString();
    } catch (e) {
      throw SimilarityDetectorException('Failed to generate asset hash: $e');
    }
  }

  Future<AssetType> _determineAssetTypeFromPath(String assetPath) async {
    final extension = path.extension(assetPath).toLowerCase();
    final extensionWithoutDot = extension.startsWith('.') ? extension.substring(1) : extension;

    switch (extensionWithoutDot) {
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'webp':
        return AssetType.image;

      case 'svg':
        return AssetType.svg;

      case 'json':
        return await _isLottieFile(assetPath) ? AssetType.lottie : AssetType.unknown;

      case 'riv':
        return AssetType.rive;

      default:
        return AssetType.unknown;
    }
  }

  Future<bool> _isLottieFile(String filePath) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString();

      return content.contains('"v":') || content.contains('"version":') || content.contains('bodymovin');
    } catch (e) {
      return false;
    }
  }

  Future<bool> _areFilesIdentical(String filePath1, String filePath2) async {
    try {
      final hash1 = await generateAssetHash(filePath1);
      final hash2 = await generateAssetHash(filePath2);
      return hash1 == hash2;
    } catch (e) {
      return false;
    }
  }

  Future<double> _calculateFallbackSimilarity(String assetPath1, String assetPath2) async {
    try {
      final areIdentical = await _areFilesIdentical(assetPath1, assetPath2);
      if (areIdentical) return 1.0;

      final name1 = path.basenameWithoutExtension(assetPath1);
      final name2 = path.basenameWithoutExtension(assetPath2);
      final nameSimilarity = _calculateNameSimilarity(name1, name2);

      final sizeSimilarity = await _calculateSizeSimilarity(assetPath1, assetPath2);

      return (nameSimilarity * 0.6) + (sizeSimilarity * 0.4);
    } catch (e) {
      return 0.0;
    }
  }

  double _calculateNameSimilarity(String name1, String name2) {
    if (name1 == name2) return 1.0;

    final lowerName1 = name1.toLowerCase();
    final lowerName2 = name2.toLowerCase();

    if (lowerName1 == lowerName2) return 0.95;

    final distance = _levenshteinDistance(lowerName1, lowerName2);
    final maxLength = [name1.length, name2.length].reduce((a, b) => a > b ? a : b);

    if (maxLength == 0) return 0.0;

    return 1.0 - (distance / maxLength);
  }

  Future<double> _calculateSizeSimilarity(String assetPath1, String assetPath2) async {
    try {
      final stat1 = await File(assetPath1).stat();
      final stat2 = await File(assetPath2).stat();

      if (stat1.size == stat2.size) return 1.0;

      final sizeDiff = (stat1.size - stat2.size).abs();
      final maxSize = [stat1.size, stat2.size].reduce((a, b) => a > b ? a : b);

      if (maxSize == 0) return 1.0;

      return 1.0 - (sizeDiff / maxSize);
    } catch (e) {
      return 0.0;
    }
  }

  int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final matrix = List.generate(s1.length + 1, (i) => List.filled(s2.length + 1, 0));

    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[s1.length][s2.length];
  }
}

class SimilarityDetectorException implements Exception {
  const SimilarityDetectorException(this.message);

  final String message;

  @override
  String toString() => 'SimilarityDetectorException: $message';
}
