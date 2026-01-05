import 'dart:io';
import '../../core/models/asset_model.dart';
import 'coreml_similarity_detector.dart';

/// Core ML-based similarity detector with comprehensive logging
class HybridSimilarityDetector {
  final CoreMLSimilarityDetector _coreMLDetector = CoreMLSimilarityDetector();
  bool _coreMLAvailable = false;

  /// Initialize the Core ML detector
  Future<void> initialize() async {
    print('🚀 Initializing Core ML similarity detector...');

    // Initialize Core ML detector
    _coreMLAvailable = await _coreMLDetector.initialize();

    if (_coreMLAvailable) {
      print('✅ Core ML detector initialized successfully');
    } else {
      print('⚠️ Core ML detector failed to initialize, using fallback');
    }

    print('🔧 Hybrid Detector Status: Core ML available: $_coreMLAvailable');
  }

  /// Find similar assets using Core ML with detailed logging
  Future<List<SimilarityResult>> findSimilarAssets(String targetImagePath, List<AssetModel> assetsToCompare) async {
    print('🔍 Starting similarity search...');
    print('   Target image: ${targetImagePath.split('/').last}');
    print('   Assets to compare: ${assetsToCompare.length}');

    final stopwatch = Stopwatch()..start();

    // Use Core ML if available
    if (_coreMLAvailable) {
      print('🧠 Using Core ML for similarity detection...');
      final results = await _coreMLDetector.findSimilarAssetsCoreML(targetImagePath, assetsToCompare);

      stopwatch.stop();
      print('⏱️ Core ML search completed in ${stopwatch.elapsedMilliseconds}ms');
      print('📊 Found ${results.length} similar assets');

      // Log detailed results
      for (final result in results) {
        final similarityPercent = (result.similarity * 100).toStringAsFixed(1);
        print('   🎯 ${result.asset.name}: $similarityPercent% (${result.matchType})');
      }

      return results;
    } else {
      print('❌ Core ML not available, no similarity detection possible');
      return [];
    }
  }

  /// Calculate similarity between two assets with logging
  Future<double> calculateSimilarity(String assetPath1, String assetPath2) async {
    print('🔍 Calculating similarity between:');
    print('   Asset 1: ${assetPath1.split('/').last}');
    print('   Asset 2: ${assetPath2.split('/').last}');

    if (_coreMLAvailable) {
      final similarity = await _coreMLDetector.calculateCoreMLSimilarity(assetPath1, assetPath2);
      final similarityPercent = (similarity * 100).toStringAsFixed(1);
      print('📊 Similarity: $similarityPercent%');
      return similarity;
    } else {
      print('❌ Core ML not available, returning 0.0');
      return 0.0;
    }
  }

  /// Check if two assets are identical with logging
  Future<bool> areAssetsIdentical(String assetPath1, String assetPath2) async {
    print('🔍 Checking if assets are identical:');
    print('   Asset 1: ${assetPath1.split('/').last}');
    print('   Asset 2: ${assetPath2.split('/').last}');

    try {
      final file1 = File(assetPath1);
      final file2 = File(assetPath2);

      if (!await file1.exists() || !await file2.exists()) {
        print('❌ One or both files do not exist');
        return false;
      }

      final stat1 = await file1.stat();
      final stat2 = await file2.stat();

      // Quick size check
      if (stat1.size != stat2.size) {
        print('📏 Files have different sizes, not identical');
        return false;
      }

      // Calculate perceptual similarity
      final similarity = await calculateSimilarity(assetPath1, assetPath2);

      // Consider identical if >95% similar
      final isIdentical = similarity >= 0.95;
      print(
        '🔍 Identity check result: ${isIdentical ? "IDENTICAL" : "DIFFERENT"} (${(similarity * 100).toStringAsFixed(1)}%)',
      );

      return isIdentical;
    } catch (e) {
      print('❌ Error in identity check: $e');
      return false;
    }
  }

  /// Generate asset hash using Core ML
  Future<String?> generateAssetHash(String assetPath) async {
    print('🔑 Generating hash for: ${assetPath.split('/').last}');

    if (_coreMLAvailable) {
      final vector = await _coreMLDetector.extractFeatureVector(assetPath);
      if (vector != null) {
        // Convert feature vector to hash string
        final hash = vector.map((v) => v.toStringAsFixed(3)).join(',');
        print('✅ Hash generated (${vector.length} dimensions)');
        return hash;
      }
    }

    print('❌ Could not generate hash');
    return null;
  }

  /// Preprocess assets for caching (placeholder)
  Future<void> preprocessAssetsInDirectory(String directoryPath, List<AssetModel> assets) async {
    print('🔄 Preprocessing ${assets.length} assets in directory: ${directoryPath.split('/').last}');
    // Core ML features are extracted on demand, no preprocessing needed
    print('✅ Preprocessing completed (on-demand extraction)');
  }

  /// Clear cache for directory (placeholder)
  Future<void> clearCacheForDirectory(String directoryPath) async {
    print('🗑️ Clearing cache for directory: ${directoryPath.split('/').last}');
    // No persistent cache for Core ML
    print('✅ Cache cleared');
  }

  /// Check if cache needs update (placeholder)
  Future<bool> needsCacheUpdate(String directoryPath, List<AssetModel> currentAssets) async {
    // Core ML features are extracted on demand, no cache updates needed
    return false;
  }

  /// Cleanup deleted files from cache (placeholder)
  Future<void> cleanupDeletedFiles(String directoryPath, List<AssetModel> currentAssets) async {
    print('🧹 Cleaning up deleted files for directory: ${directoryPath.split('/').last}');
    // No persistent cache for Core ML
    print('✅ Cleanup completed');
  }

  /// Dispose of resources
  void dispose() {
    print('🔄 Disposing Core ML detector...');
    _coreMLDetector.dispose();
    print('✅ Disposal completed');
  }
}
